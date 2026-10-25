<?php

namespace Tests\Feature;

use App\Models\CatalogProduct;
use App\Models\Product;
use App\Models\StockMovement;
use App\Services\ProductService;
use App\Services\SaleService;
use App\Support\Barcode;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;
use ReflectionMethod;
use Tests\Support\BuildsShopData;
use Tests\TestCase;

/** Shared global catalog: product identity is platform-wide; price, cost and stock stay per store. */
class SharedCatalogTest extends TestCase
{
    use BuildsShopData;
    use RefreshDatabase;

    private const GTIN = '6291041500213';

    private function newProduct(array $overrides = []): array
    {
        return $overrides + [
            'name' => 'Juice 1L',
            'barcode' => self::GTIN,
            'unit' => 'piece',
            'selling_price' => '8.00',
            'cost_price' => '6.00',
            'current_stock' => 10,
        ];
    }

    public function test_barcodes_are_normalized_to_one_spelling(): void
    {
        $this->assertSame('6291041500213', Barcode::normalize(' ٦٢٩١٠٤١٥٠٠٢١٣ '));
        $this->assertSame('0012345678905', Barcode::normalize('012345678905'));    // UPC-A
        $this->assertSame('0012345678905', Barcode::normalize('00012345678905'));  // GTIN-14
        $this->assertSame('ABC-1', Barcode::normalize('abc-1'));
        $this->assertNull(Barcode::normalize('   '));

        $this->assertTrue(Barcode::isGlobal(self::GTIN));
        $this->assertFalse(Barcode::isGlobal('6291041500214'), 'bad check digit');
        $this->assertFalse(Barcode::isGlobal('2000000000008'), 'in-store / variable weight');
        $this->assertFalse(Barcode::isGlobal('111'));
    }

    public function test_unknown_barcode_creates_the_catalog_item_and_links_the_store(): void
    {
        $owner = $this->makeUser($this->makeStore('A'));
        $api = $this->actingAs($owner, 'sanctum');

        $api->getJson('/api/v1/products/catalog-lookup?barcode=' . self::GTIN)
            ->assertOk()->assertJsonPath('data.product', null)->assertJsonPath('data.catalog_product', null);

        $id = $api->postJson('/api/v1/products', $this->newProduct())->assertCreated()->json('product.id');

        $catalog = CatalogProduct::sole();
        $this->assertSame([self::GTIN, 'Juice 1L', 'piece', $owner->store_id], [$catalog->barcode, $catalog->name, $catalog->unit, (int) $catalog->created_by_store_id]);
        $this->assertSame($catalog->id, (int) Product::findOrFail($id)->catalog_product_id);
    }

    public function test_another_store_finds_and_reuses_the_item_with_its_own_price_and_stock(): void
    {
        $first = $this->makeUser($this->makeStore('A'));
        $second = $this->makeUser($this->makeStore('B'));
        $firstId = $this->actingAs($first, 'sanctum')->postJson('/api/v1/products', $this->newProduct())->json('product.id');

        // Immediately visible to another store, with the shared details only.
        $this->actingAs($second, 'sanctum')->getJson('/api/v1/products/catalog-lookup?barcode=' . self::GTIN)
            ->assertOk()
            ->assertJsonPath('data.product', null)
            ->assertJsonPath('data.catalog_product.name', 'Juice 1L')
            ->assertJsonPath('data.catalog_product.unit', 'piece')
            ->assertJsonMissingPath('data.catalog_product.selling_price');

        // Store B only enters its own price, cost and stock; name and unit come from the catalog.
        $response = $this->actingAs($second, 'sanctum')->postJson('/api/v1/products', [
            'barcode' => self::GTIN,
            'selling_price' => '9.50',
            'cost_price' => '7.25',
            'current_stock' => 3,
        ])->assertCreated()
            ->assertJsonPath('product.name', 'Juice 1L')
            ->assertJsonPath('product.selling_price', '9.50')
            ->assertJsonPath('product.current_stock', '3');

        $this->assertSame(1, CatalogProduct::count(), 'no duplicate catalog item');
        $this->assertSame(CatalogProduct::sole()->id, $response->json('product.catalog_product_id'));
        $this->assertSame('3.000', Product::findOrFail($response->json('product.id'))->movements()->sole()->quantity);

        $mine = Product::findOrFail($firstId);
        $this->assertSame(['8.00', '6.00', '10.000'], [$mine->selling_price, $mine->cost_price, $mine->current_stock]);
    }

    public function test_one_store_editing_its_product_never_changes_the_catalog_or_other_stores(): void
    {
        $first = $this->makeUser($this->makeStore('A'));
        $second = $this->makeUser($this->makeStore('B'));
        $third = $this->makeUser($this->makeStore('C'));
        $firstId = $this->actingAs($first, 'sanctum')->postJson('/api/v1/products', $this->newProduct())->json('product.id');
        $secondId = $this->actingAs($second, 'sanctum')->postJson('/api/v1/products', $this->newProduct(['selling_price' => '9.00']))->json('product.id');

        $this->actingAs($second, 'sanctum')->patchJson("/api/v1/products/{$secondId}", ['name' => 'Renamed by B', 'selling_price' => '1.00', 'unit' => 'kg'])
            ->assertOk()->assertJsonPath('data.name', 'Renamed by B');

        $this->assertSame(['Juice 1L', 'piece', '8.00'], [Product::findOrFail($firstId)->name, Product::findOrFail($firstId)->unit, Product::findOrFail($firstId)->selling_price]);
        $this->assertSame(['Juice 1L', 'piece'], [CatalogProduct::sole()->name, CatalogProduct::sole()->unit]);
        $this->actingAs($third, 'sanctum')->getJson('/api/v1/products/catalog-lookup?barcode=' . self::GTIN)
            ->assertJsonPath('data.catalog_product.name', 'Juice 1L');

        // Another store's product stays unreachable through the catalog.
        $this->actingAs($second, 'sanctum')->patchJson("/api/v1/products/{$firstId}", ['name' => 'X'])->assertNotFound();
    }

    public function test_a_product_already_in_the_store_is_rejected_without_touching_stock(): void
    {
        $owner = $this->makeUser($this->makeStore());
        $api = $this->actingAs($owner, 'sanctum');
        $id = $api->postJson('/api/v1/products', $this->newProduct(['barcode' => '0012345678905']))->json('product.id');

        $api->getJson('/api/v1/products/catalog-lookup?barcode=012345678905')
            ->assertOk()->assertJsonPath('data.product.id', $id)->assertJsonPath('data.product.current_stock', '10');

        // Same item, other spellings (UPC-A, GTIN-14): no second link, no extra stock.
        foreach (['0012345678905', '012345678905', '00012345678905'] as $spelling) {
            $api->postJson('/api/v1/products', $this->newProduct(['barcode' => $spelling, 'current_stock' => 5]))
                ->assertUnprocessable()->assertJsonValidationErrors('barcode');
        }

        $this->assertSame(1, Product::count());
        $this->assertSame('10.000', Product::findOrFail($id)->current_stock);
        $this->assertSame(1, StockMovement::count());
    }

    /** Two simultaneous saves pass validation; the database index stops the second one. */
    public function test_simultaneous_saves_cannot_link_twice_or_double_stock(): void
    {
        $owner = $this->makeUser($this->makeStore());
        $service = app(ProductService::class);
        $data = ['name' => 'Juice', 'barcode' => self::GTIN, 'unit' => 'piece', 'selling_price' => '8.00', 'current_stock' => 4];

        $service->create($owner, $data);
        try {
            $service->create($owner, $data);
            $this->fail('The second save should be rejected.');
        } catch (ValidationException $e) {
            $this->assertArrayHasKey('barcode', $e->errors());
        }

        $this->assertSame(1, Product::count());
        $this->assertSame('4.000', Product::sole()->current_stock);
        $this->assertSame(1, StockMovement::count());

        // Catalog barcodes are unique in the database, whichever store inserts first.
        $this->expectException(UniqueConstraintViolationException::class);
        DB::table('catalog_products')->insert(['barcode' => self::GTIN, 'name' => 'Copy', 'unit' => 'piece']);
    }

    public function test_store_only_codes_are_not_shared(): void
    {
        $first = $this->makeUser($this->makeStore('A'));
        $second = $this->makeUser($this->makeStore('B'));

        foreach (['111', '2000000000008'] as $code) {
            $this->actingAs($first, 'sanctum')->postJson('/api/v1/products', $this->newProduct(['barcode' => $code]))
                ->assertCreated()->assertJsonPath('product.catalog_product_id', null);
            $this->actingAs($second, 'sanctum')->getJson("/api/v1/products/catalog-lookup?barcode={$code}")
                ->assertOk()->assertJsonPath('data.catalog_product', null);
        }

        $this->assertSame(0, CatalogProduct::count());
    }

    public function test_changing_the_barcode_relinks_the_product(): void
    {
        $owner = $this->makeUser($this->makeStore());
        $api = $this->actingAs($owner, 'sanctum');
        $id = $api->postJson('/api/v1/products', $this->newProduct())->json('product.id');

        $api->patchJson("/api/v1/products/{$id}", ['barcode' => '4006381333931'])->assertOk();
        $this->assertSame(CatalogProduct::where('barcode', '4006381333931')->sole()->id, (int) Product::findOrFail($id)->catalog_product_id);

        $api->patchJson("/api/v1/products/{$id}", ['barcode' => null])->assertOk()->assertJsonPath('data.catalog_product_id', null);
        $this->assertSame(2, CatalogProduct::count(), 'catalog items stay for other stores');
    }

    /** The migration links existing data without merging or deleting anything. */
    public function test_migration_backfills_existing_products(): void
    {
        $storeA = $this->makeStore('A');
        $storeB = $this->makeStore('B');
        $older = $this->makeProduct($storeA, ['name' => 'Juice A', 'barcode' => self::GTIN, 'selling_price' => '8.00']);
        $newer = $this->makeProduct($storeB, ['name' => 'عصير', 'barcode' => self::GTIN, 'selling_price' => '9.00', 'unit' => 'kg']);
        $upc = $this->makeProduct($storeA, ['barcode' => '012345678905']);
        $variant = $this->makeProduct($storeB, ['barcode' => '00012345678905']);
        $collision = $this->makeProduct($storeB, ['barcode' => '012345678905']);
        $internal = $this->makeProduct($storeA, ['barcode' => '111']);

        // makeProduct writes rows like before the catalog existed (unlinked, raw barcodes).
        $this->assertSame(0, CatalogProduct::count());
        $migration = require database_path('migrations/2026_10_24_000001_create_catalog_products_table.php');
        (new ReflectionMethod($migration, 'backfill'))->invoke($migration);

        $juice = CatalogProduct::where('barcode', self::GTIN)->sole();
        $this->assertSame(['Juice A', 'piece'], [$juice->name, $juice->unit], 'oldest product wins');
        $this->assertSame([$juice->id, $juice->id], [(int) $older->fresh()->catalog_product_id, (int) $newer->fresh()->catalog_product_id]);
        $this->assertSame(['عصير', 'kg', '9.00', '10.000'], [$newer->fresh()->name, $newer->fresh()->unit, $newer->fresh()->selling_price, $newer->fresh()->current_stock]);

        $upcItem = CatalogProduct::where('barcode', '0012345678905')->sole();
        $this->assertSame(['0012345678905', $upcItem->id], [$upc->fresh()->barcode, (int) $upc->fresh()->catalog_product_id]);
        $this->assertSame(['0012345678905', $upcItem->id], [$variant->fresh()->barcode, (int) $variant->fresh()->catalog_product_id]);
        // Store B already holds this item as `variant`: the second spelling stays as it was, unlinked.
        $this->assertSame(['012345678905', null], [$collision->fresh()->barcode, $collision->fresh()->catalog_product_id]);
        $this->assertNull($internal->fresh()->catalog_product_id);

        $this->assertSame(6, Product::count());
        $this->assertSame(2, CatalogProduct::count());
    }

    /**
     * The real race: this store's lookup finds no catalog item, and before its insert another store
     * commits the same barcode. The insert is ignored and the product links to the winner's item.
     */
    public function test_losing_the_first_insert_race_links_to_the_winners_item(): void
    {
        $winner = $this->makeStore('Winner');
        $owner = $this->makeUser($this->makeStore('Loser'));
        $raced = false;
        DB::listen(function ($query) use (&$raced, $winner) {
            if (!$raced && str_starts_with(strtolower($query->sql), 'select') && str_contains($query->sql, 'catalog_products')) {
                $raced = true;
                DB::table('catalog_products')->insert(['barcode' => self::GTIN, 'name' => 'Juice (winner)', 'unit' => 'piece', 'created_by_store_id' => $winner->id]);
            }
        });

        $product = app(ProductService::class)->create($owner, $this->newProduct());

        $this->assertTrue($raced, 'The competing insert ran between the lookup and the insert.');
        $item = CatalogProduct::sole();
        $this->assertSame(['Juice (winner)', $winner->id], [$item->name, (int) $item->created_by_store_id], 'The winner\'s item is kept, not overwritten.');
        $this->assertSame($item->id, (int) $product->catalog_product_id);
        $this->assertSame(['Juice 1L', '8.00', '10.000'], [$product->name, $product->selling_price, $product->current_stock], 'The store keeps its own name, price and stock.');
    }

    public function test_platform_admin_compares_a_catalog_items_prices_and_stock_across_stores(): void
    {
        $admin = $this->makeUser($this->makeStore('Hisbah HQ'));
        $admin->forceFill(['is_platform_admin' => true])->save();
        $stores = ['Gaza' => ['8.00', 10], 'Rafah' => ['9.50', 3], 'Khan Younis' => ['7.25', 0], 'Closed' => ['5.00', 4]];
        $ids = [];
        foreach ($stores as $name => [$price, $stock]) {
            $owner = $this->makeUser($this->makeStore($name, ['area' => $name]));
            $ids[$name] = $this->actingAs($owner, 'sanctum')
                ->postJson('/api/v1/products', $this->newProduct(['selling_price' => $price, 'current_stock' => $stock]))
                ->assertCreated()->json('product.id');
        }
        Product::findOrFail($ids['Closed'])->update(['status' => Product::STATUS_INACTIVE]);
        $water = $this->makeUser($this->makeStore('Water shop'));
        $this->actingAs($water, 'sanctum')->postJson('/api/v1/products', $this->newProduct(['name' => 'Water', 'barcode' => '0012345678905', 'selling_price' => '2.00']))->assertCreated();
        $item = CatalogProduct::where('barcode', self::GTIN)->sole();

        // The list: one row per barcode, most widely carried first, price range over active rows only.
        $this->actingAs($admin, 'sanctum')->getJson('/api/v1/admin/catalog-products')
            ->assertOk()
            ->assertJsonCount(2, 'data')
            ->assertJsonPath('data.0.id', $item->id)
            ->assertJsonPath('data.0.stores_count', 4)
            ->assertJsonPath('data.0.active_stores_count', 3)
            ->assertJsonPath('data.0.price_min', '7.25')
            ->assertJsonPath('data.0.price_max', '9.50')
            ->assertJsonPath('data.1.name', 'Water');
        // Search by name or by any spelling of the barcode.
        $this->actingAs($admin, 'sanctum')->getJson('/api/v1/admin/catalog-products?search=012345678905')
            ->assertJsonCount(1, 'data')->assertJsonPath('data.0.name', 'Water');

        // One item: every store's own row, cheapest first, and the comparison.
        $response = $this->actingAs($admin, 'sanctum')->getJson("/api/v1/admin/catalog-products/{$item->id}")
            ->assertOk()
            ->assertJsonPath('data.stores_count', 4)
            ->assertJsonPath('data.comparison.active_stores_count', 3)
            ->assertJsonPath('data.comparison.price_min', '7.25')
            ->assertJsonPath('data.comparison.price_max', '9.50')
            ->assertJsonPath('data.comparison.price_spread', '2.25');
        $offers = collect($response->json('data.offers'));
        $this->assertSame(['5.00', '7.25', '8.00', '9.50'], $offers->pluck('selling_price')->all());
        $this->assertSame(['4', '0', '10', '3'], $offers->pluck('current_stock')->all(), 'Each store\'s stock, never summed.');
        $this->assertSame(['Closed', 'Khan Younis', 'Gaza', 'Rafah'], $offers->pluck('store.area')->all());

        // Store accounts cannot reach either view.
        $this->actingAs($water, 'sanctum')->getJson('/api/v1/admin/catalog-products')->assertForbidden();
        $this->actingAs($water, 'sanctum')->getJson("/api/v1/admin/catalog-products/{$item->id}")->assertForbidden();
    }

    /** Linking a second store to an item moves nothing: sales, returns and movements stay on each store's row. */
    public function test_existing_history_stays_with_each_stores_own_product(): void
    {
        $storeA = $this->makeStore('A');
        $ownerA = $this->makeUser($storeA);
        $juiceA = $this->makeProduct($storeA, ['name' => 'Juice A', 'barcode' => self::GTIN, 'selling_price' => '8.00', 'current_stock' => 10]);
        $sale = app(SaleService::class)->create($ownerA, ['items' => [['product_id' => $juiceA->id, 'quantity' => 3]], 'paid_amount' => '24.00', 'payment_method' => 'cash'])['invoice'];
        $this->actingAs($ownerA, 'sanctum')
            ->postJson("/api/v1/sales/{$sale->id}/returns", ['items' => [['invoice_item_id' => $sale->items[0]->id, 'quantity' => 1]], 'reason' => 'Damaged'], $this->idem())
            ->assertCreated();
        $this->app['auth']->forgetGuards();

        // The pre-catalog row is linked by the backfill; then store B adds the same barcode.
        $migration = require database_path('migrations/2026_10_24_000001_create_catalog_products_table.php');
        (new ReflectionMethod($migration, 'backfill'))->invoke($migration);
        $ownerB = $this->makeUser($this->makeStore('B'));
        $juiceB = $this->actingAs($ownerB, 'sanctum')->postJson('/api/v1/products', ['barcode' => self::GTIN, 'selling_price' => '9.00', 'current_stock' => 5])
            ->assertCreated()->json('product.id');

        $item = CatalogProduct::sole();
        $this->assertSame([$item->id, $item->id], [(int) $juiceA->fresh()->catalog_product_id, (int) Product::findOrFail($juiceB)->catalog_product_id]);
        $this->assertSame([$juiceA->id], $sale->items()->pluck('product_id')->all(), 'Invoice lines still point at store A\'s own row.');
        $this->assertSame(['opening', 'sale', 'sale_return'], StockMovement::where('product_id', $juiceA->id)->orderBy('id')->pluck('type')->all());
        $this->assertSame('8.000', $juiceA->fresh()->current_stock);
        $this->assertSame(['opening'], StockMovement::where('product_id', $juiceB)->pluck('type')->all());
        $this->assertSame('5.000', Product::findOrFail($juiceB)->current_stock);
        $this->assertSame($juiceA->id, (int) DB::table('sale_return_items')->value('product_id'));
    }
}
