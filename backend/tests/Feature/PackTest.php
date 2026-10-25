<?php

namespace Tests\Feature;

use App\Models\Invoice;
use App\Models\InvoiceItem;
use App\Models\Product;
use App\Models\StockMovement;
use App\Models\Store;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Tests\Support\BuildsShopData;
use Tests\TestCase;

/**
 * Wholesale cartons: stock stays in pieces; a carton line sells whole cartons at the carton price
 * and moves quantity × pack_size pieces. Pieces, kg and every existing line keep their meaning.
 */
class PackTest extends TestCase
{
    use BuildsShopData;
    use RefreshDatabase;

    private Store $store;
    private User $owner;

    protected function setUp(): void
    {
        parent::setUp();
        $this->store = $this->makeStore();
        $this->owner = $this->makeUser($this->store);
    }

    /** Water: 2.50 a bottle, 54.00 a carton of 24 (a wholesale discount), 100 bottles in stock. */
    private function water(array $overrides = []): Product
    {
        return $this->makeProduct($this->store, $overrides + [
            'name' => 'Water 600ml',
            'selling_price' => '2.50',
            'pack_size' => 24,
            'pack_price' => '54.00',
            'current_stock' => 100,
        ]);
    }

    private function sell(array $items, ?string $paid = null)
    {
        $response = $this->actingAs($this->owner, 'sanctum')->postJson('/api/v1/sales', [
            'items' => $items,
            'paid_amount' => $paid ?? '0',
            'payment_method' => 'cash',
        ], $this->idem());
        $this->app['auth']->forgetGuards();

        return $response;
    }

    private function stockOf(Product $product): string
    {
        return $product->fresh()->current_stock;
    }

    // ---------------------------------------------------------------- the product's carton

    public function test_a_carton_is_saved_with_its_size_and_price(): void
    {
        $this->actingAs($this->owner, 'sanctum')->postJson('/api/v1/products', [
            'name' => 'Water 600ml',
            'selling_price' => '2.50',
            'pack_size' => 24,
            'pack_price' => '54.00',
            'current_stock' => 48,
        ])->assertCreated()
            ->assertJsonPath('product.pack_size', 24)
            ->assertJsonPath('product.pack_price', '54.00')
            ->assertJsonPath('product.current_stock', '48');

        // Stock is in pieces whatever the carton: 48 pieces, not 48 cartons.
        $this->assertSame('48.000', Product::sole()->current_stock);
    }

    public function test_ambiguous_or_invalid_cartons_are_refused(): void
    {
        $base = ['name' => 'Water', 'selling_price' => '2.50', 'current_stock' => 0];
        $cases = [
            'weighed product' => [['unit' => 'kg', 'pack_size' => 10, 'pack_price' => '50.00'], 'pack_size', 'الكرتونة للمنتجات المباعة بالقطعة فقط'],
            'one piece per carton' => [['pack_size' => 1, 'pack_price' => '2.50'], 'pack_size', 'الكرتونة تحتوي قطعتين على الأقل.'],
            'fraction of a piece' => [['pack_size' => 2.5, 'pack_price' => '6.00'], 'pack_size', 'عدد القطع في الكرتونة يجب أن يكون عددًا صحيحًا.'],
            'size without price' => [['pack_size' => 24], 'pack_price', 'أدخل سعر الكرتونة كاملة مع عدد قطعها.'],
            'price without size' => [['pack_price' => '54.00'], 'pack_size', 'أدخل عدد القطع في الكرتونة مع سعرها.'],
            'per-piece price in the carton field' => [['pack_size' => 24, 'pack_price' => '2.50'], 'pack_price', 'سعر الكرتونة يجب أن يكون أعلى من سعر القطعة الواحدة'],
        ];

        foreach ($cases as $case => [$fields, $field, $message]) {
            $response = $this->actingAs($this->owner, 'sanctum')->postJson('/api/v1/products', $base + $fields)
                ->assertUnprocessable();
            $this->assertStringContainsString($message, $response->json("errors.{$field}.0"), $case);
        }
        $this->assertSame(0, Product::count());
    }

    public function test_an_edit_cannot_leave_an_ambiguous_carton_behind(): void
    {
        $water = $this->water();
        $api = $this->actingAs($this->owner, 'sanctum');

        // The piece price alone rising above the carton price makes the carton wrong.
        $api->patchJson("/api/v1/products/{$water->id}", ['selling_price' => '60.00'])
            ->assertUnprocessable()->assertJsonValidationErrors('pack_price');
        // A weighed product cannot keep a carton.
        $api->patchJson("/api/v1/products/{$water->id}", ['unit' => 'kg'])
            ->assertUnprocessable()->assertJsonValidationErrors('pack_size');
        $this->assertSame([24, '54.00', 'piece'], [$water->fresh()->pack_size, $water->fresh()->pack_price, $water->fresh()->unit]);

        // Removing the carton (both fields) is allowed, and then it may become weighed.
        $api->patchJson("/api/v1/products/{$water->id}", ['pack_size' => null, 'pack_price' => null])->assertOk()
            ->assertJsonPath('data.pack_size', null);
        $api->patchJson("/api/v1/products/{$water->id}", ['unit' => 'kg'])->assertOk();
    }

    // ---------------------------------------------------------------- selling

    public function test_a_carton_sells_at_the_carton_price_and_takes_its_pieces_from_stock(): void
    {
        $water = $this->water();

        $response = $this->sell([
            ['product_id' => $water->id, 'quantity' => 2, 'sale_unit' => 'pack'],
            ['product_id' => $water->id, 'quantity' => 3],
        ], paid: '115.50')->assertCreated()
            ->assertJsonPath('data.total_amount', '115.50')
            ->assertJsonPath('data.items.0.sale_unit', 'pack')
            ->assertJsonPath('data.items.0.pack_size', 24)
            ->assertJsonPath('data.items.0.quantity', '2')
            ->assertJsonPath('data.items.0.base_quantity', '48')
            ->assertJsonPath('data.items.0.unit_price', '54.00')
            ->assertJsonPath('data.items.0.line_total', '108.00')
            ->assertJsonPath('data.items.1.sale_unit', 'piece')
            ->assertJsonPath('data.items.1.pack_size', null)
            ->assertJsonPath('data.items.1.base_quantity', '3')
            ->assertJsonPath('data.items.1.unit_price', '2.50')
            ->assertJsonPath('data.items.1.line_total', '7.50');

        // 100 − 2 × 24 − 3 = 49 pieces; two movements, both in pieces.
        $this->assertSame('49.000', $this->stockOf($water));
        $this->assertSame(['-48.000', '-3.000'], StockMovement::where('type', 'sale')->orderBy('id')->pluck('quantity')->all());
        $this->assertSame([], $response->json('warnings'));
    }

    public function test_pieces_and_kilograms_sell_as_before(): void
    {
        $tea = $this->makeProduct($this->store, ['selling_price' => '6.50', 'current_stock' => 10]);
        $nuts = $this->makeProduct($this->store, ['unit' => 'kg', 'selling_price' => '60.00', 'current_stock' => '5.000']);

        $this->sell([
            ['product_id' => $tea->id, 'quantity' => 2],
            ['product_id' => $nuts->id, 'quantity' => '0.750'],
        ], paid: '58.00')->assertCreated()
            ->assertJsonPath('data.items.0.sale_unit', 'piece')
            ->assertJsonPath('data.items.1.sale_unit', 'kg')
            ->assertJsonPath('data.items.1.base_quantity', '0.750')
            ->assertJsonPath('data.items.1.line_total', '45.00');

        $this->assertSame(['8.000', '4.250'], [$this->stockOf($tea), $this->stockOf($nuts)]);
        $this->assertNull(InvoiceItem::where('product_id', $tea->id)->sole()->pack_size);
    }

    public function test_carton_mistakes_are_refused_and_nothing_is_written(): void
    {
        $water = $this->water();
        $tea = $this->makeProduct($this->store, ['selling_price' => '6.50']);

        $this->sell([['product_id' => $water->id, 'quantity' => '1.5', 'sale_unit' => 'pack']])
            ->assertUnprocessable()->assertJsonPath('errors', ['items.0.quantity' => ['الكرتونة تُباع كاملة؛ أدخل عددًا صحيحًا من الكراتين.']]);
        $this->sell([['product_id' => $tea->id, 'quantity' => 1, 'sale_unit' => 'pack']])
            ->assertUnprocessable()->assertJsonValidationErrors('items.0.sale_unit');
        $this->sell([['product_id' => $water->id, 'quantity' => 1, 'sale_unit' => 'box']])
            ->assertUnprocessable()->assertJsonValidationErrors('items.0.sale_unit');
        // Pieces and cartons are two lines; the same unit twice is one line with a bigger quantity.
        $this->sell([
            ['product_id' => $water->id, 'quantity' => 1, 'sale_unit' => 'pack'],
            ['product_id' => $water->id, 'quantity' => 1, 'sale_unit' => 'pack'],
        ])->assertUnprocessable()->assertJsonValidationErrors('items.1.product_id');

        $this->assertSame(0, Invoice::count());
        $this->assertSame('100.000', $this->stockOf($water));
    }

    public function test_the_stock_limit_counts_the_pieces_inside_the_cartons(): void
    {
        $water = $this->water(['current_stock' => 30]);

        // 2 cartons = 48 pieces from 30: the sale goes through (D-27) and is flagged at −18 pieces.
        $this->sell([['product_id' => $water->id, 'quantity' => 2, 'sale_unit' => 'pack']], paid: '108.00')
            ->assertCreated()
            ->assertJsonPath('warnings.0.code', 'NEGATIVE_STOCK')
            ->assertJsonPath('warnings.0.balance_after', '-18');
        $this->assertSame('-18.000', $this->stockOf($water));
    }

    // ---------------------------------------------------------------- returns, void, history

    public function test_a_carton_comes_back_whole_at_its_price_and_puts_its_pieces_back(): void
    {
        $water = $this->water();
        $sale = $this->sell([['product_id' => $water->id, 'quantity' => 3, 'sale_unit' => 'pack']], paid: '162.00')->assertCreated();
        $itemId = $sale->json('data.items.0.id');
        $saleId = $sale->json('data.id');
        $return = fn($quantity) => tap($this->actingAs($this->owner, 'sanctum')->postJson("/api/v1/sales/{$saleId}/returns", [
            'items' => [['invoice_item_id' => $itemId, 'quantity' => $quantity]],
            'reason' => 'Damaged',
        ], $this->idem()), fn() => $this->app['auth']->forgetGuards());

        $return('0.5')->assertUnprocessable()->assertJsonPath('errors', ['items.0.quantity' => ['هذا الصنف بيع بالكرتونة؛ أرجع كراتين كاملة.']]);
        $this->assertSame('28.000', $this->stockOf($water));

        $return(1)->assertCreated()
            ->assertJsonPath('data.total_amount', '54.00')
            ->assertJsonPath('data.refund_amount', '54.00')
            ->assertJsonPath('invoice.items.0.returned_quantity', '1');
        $this->assertSame('52.000', $this->stockOf($water), '28 + one carton of 24');

        // Only 2 cartons are left to return.
        $return(3)->assertUnprocessable();
        $this->assertDatabaseHas('stock_movements', ['product_id' => $water->id, 'type' => 'sale_return', 'quantity' => 24]);
    }

    public function test_a_sold_line_keeps_its_carton_size_after_the_product_changes(): void
    {
        $water = $this->water();
        $sale = $this->sell([['product_id' => $water->id, 'quantity' => 1, 'sale_unit' => 'pack']], paid: '54.00')->assertCreated();

        // The shop now buys cartons of 12 at a new price.
        $this->actingAs($this->owner, 'sanctum')->patchJson("/api/v1/products/{$water->id}", ['pack_size' => 12, 'pack_price' => '28.00'])->assertOk();
        $this->app['auth']->forgetGuards();

        $this->actingAs($this->owner, 'sanctum')->getJson("/api/v1/sales/{$sale->json('data.id')}")
            ->assertJsonPath('data.items.0.pack_size', 24)
            ->assertJsonPath('data.items.0.unit_price', '54.00')
            ->assertJsonPath('data.items.0.base_quantity', '24');
        $this->actingAs($this->owner, 'sanctum')->postJson("/api/v1/sales/{$sale->json('data.id')}/returns", [
            'items' => [['invoice_item_id' => $sale->json('data.items.0.id'), 'quantity' => 1]],
            'reason' => 'Wrong item',
        ], $this->idem())->assertCreated()->assertJsonPath('data.refund_amount', '54.00');

        $this->assertSame('100.000', $this->stockOf($water), 'the 24 pieces sold come back, not 12');
    }

    public function test_voiding_a_carton_sale_restores_every_piece(): void
    {
        $water = $this->water();
        $sale = $this->sell([
            ['product_id' => $water->id, 'quantity' => 2, 'sale_unit' => 'pack'],
            ['product_id' => $water->id, 'quantity' => 5],
        ], paid: '120.50')->assertCreated();
        $this->assertSame('47.000', $this->stockOf($water));

        $this->actingAs($this->owner, 'sanctum')->postJson("/api/v1/sales/{$sale->json('data.id')}/void", ['reason' => 'Mistake'], $this->idem())
            ->assertOk();
        $this->assertSame('100.000', $this->stockOf($water));
    }

    public function test_lines_sold_before_cartons_existed_keep_their_meaning(): void
    {
        // A line written before this change: no pack_size column value.
        $tea = $this->makeProduct($this->store, ['selling_price' => '6.50', 'current_stock' => 10]);
        $invoice = Invoice::create(['store_id' => $this->store->id, 'total_amount' => '13.00', 'paid_amount' => '13.00', 'payment_method' => 'cash', 'has_debt' => false, 'source' => 'sale']);
        DB::table('invoice_items')->insert([
            'invoice_id' => $invoice->id, 'product_id' => $tea->id, 'item_name' => 'Tea', 'unit' => 'piece',
            'quantity' => 2, 'returned_quantity' => 0, 'unit_price' => '6.50', 'total' => '13.00',
            'created_at' => now(), 'updated_at' => now(),
        ]);

        // Cartons added to the product later do not touch that line.
        $tea->update(['pack_size' => 10, 'pack_price' => '60.00']);
        $this->actingAs($this->owner, 'sanctum')->getJson("/api/v1/sales/{$invoice->id}")
            ->assertJsonPath('data.items.0.sale_unit', 'piece')
            ->assertJsonPath('data.items.0.pack_size', null)
            ->assertJsonPath('data.items.0.quantity', '2')
            ->assertJsonPath('data.items.0.base_quantity', '2');
        $this->actingAs($this->owner, 'sanctum')->postJson("/api/v1/sales/{$invoice->id}/returns", [
            'items' => [['invoice_item_id' => InvoiceItem::sole()->id, 'quantity' => 1]],
            'reason' => 'Damaged',
        ], $this->idem())->assertCreated()->assertJsonPath('data.refund_amount', '6.50');

        $this->assertSame('11.000', $this->stockOf($tea), 'one piece back, not one carton');
    }

    // ---------------------------------------------------------------- receiving and import

    public function test_goods_received_by_the_carton_add_their_pieces(): void
    {
        $water = $this->water(['current_stock' => 4]);
        $tea = $this->makeProduct($this->store);
        $api = $this->actingAs($this->owner, 'sanctum');

        $api->postJson('/api/v1/stock-adjustments', ['product_id' => $water->id, 'quantity' => 3, 'unit' => 'pack', 'reason' => 'Delivery'], $this->idem())
            ->assertCreated()
            ->assertJsonPath('movement.quantity', '72')
            ->assertJsonPath('product.current_stock', '76');
        $api->postJson('/api/v1/stock-adjustments', ['product_id' => $water->id, 'quantity' => '0.5', 'unit' => 'pack', 'reason' => 'Delivery'], $this->idem())
            ->assertUnprocessable()->assertJsonValidationErrors('quantity');
        $api->postJson('/api/v1/stock-adjustments', ['product_id' => $tea->id, 'quantity' => 1, 'unit' => 'pack', 'reason' => 'Delivery'], $this->idem())
            ->assertUnprocessable()->assertJsonValidationErrors('unit');

        $this->assertDatabaseHas('audit_logs', ['action' => 'stock.adjusted']);
        $this->assertSame('76.000', $this->stockOf($water));
    }

    public function test_the_csv_import_reads_optional_carton_columns_with_the_same_rules(): void
    {
        $import = function (string $csv) {
            $file = UploadedFile::fake()->createWithContent('products.csv', $csv);
            $response = $this->actingAs($this->owner, 'sanctum')->post('/api/v1/products/import', ['file' => $file], ['Accept' => 'application/json']);
            $this->app['auth']->forgetGuards();

            return $response;
        };

        $import("name,unit,selling_price,pack_size,pack_price,current_stock\nWater,piece,2.50,24,2.00,10\nRice,kg,5.00,25,120.00,50\n")
            ->assertUnprocessable()
            ->assertJsonPath('details.errors.0.column', 'pack_price')
            ->assertJsonPath('details.errors.1.column', 'pack_size');
        $this->assertSame(0, Product::count());

        // Older files without the columns still import; a valid carton is kept.
        $import("name,unit,selling_price,pack_size,pack_price,current_stock\nWater,piece,2.50,24,54.00,48\nTea,piece,6.50,,,10\n")->assertCreated();
        $this->assertSame([24, '54.00'], [Product::where('name', 'Water')->sole()->pack_size, Product::where('name', 'Water')->sole()->pack_price]);
        $this->assertNull(Product::where('name', 'Tea')->sole()->pack_size);
    }
}
