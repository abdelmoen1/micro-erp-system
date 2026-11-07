<?php

namespace Tests\Feature;

use App\Models\AuditLog;
use App\Models\Invoice;
use App\Models\Product;
use App\Models\Store;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Support\BuildsShopData;
use Tests\TestCase;

/**
 * 2026-11-07 requests from the shop: a price changed at the till for one sale, the value of the goods
 * in the store room, and the platform admin's list of suppliers with their wholesale prices.
 */
class PriceEditStockValueSuppliersTest extends TestCase
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

    private function sell(array $body, ?User $actor = null)
    {
        $response = $this->actingAs($actor ?? $this->owner, 'sanctum')->postJson('/api/v1/sales', $body, $this->idem());
        $this->app['auth']->forgetGuards();

        return $response;
    }

    // ------------------------------------------------------------ price set at the till

    public function test_a_line_price_set_at_the_till_is_charged_and_the_product_keeps_its_price(): void
    {
        $oil = $this->makeProduct($this->store, ['selling_price' => '18.00', 'current_stock' => 10]);
        $rice = $this->makeProduct($this->store, ['selling_price' => '42.00', 'current_stock' => 10]);

        $response = $this->sell([
            'items' => [
                ['product_id' => $oil->id, 'quantity' => 2, 'unit_price' => '17.00'],
                ['product_id' => $rice->id, 'quantity' => 1, 'unit_price' => '45.50'],
            ],
            'paid_amount' => '79.50',
            'payment_method' => 'cash',
        ], $this->makeUser($this->store, 'employee'))->assertCreated();

        $response->assertJsonPath('data.total_amount', '79.50')
            ->assertJsonPath('data.items.0.unit_price', '17.00')
            ->assertJsonPath('data.items.0.line_total', '34.00')
            ->assertJsonPath('data.items.1.unit_price', '45.50')
            ->assertJsonPath('flags', []);

        $this->assertSame('18.00', (string) $oil->fresh()->selling_price);
        $this->assertSame('42.00', (string) $rice->fresh()->selling_price);
        $audit = AuditLog::where('action', 'sale.created')->firstOrFail();
        $this->assertSame([
            ['product_id' => $oil->id, 'sale_unit' => null, 'list_price' => '18.00', 'charged' => '17.00'],
            ['product_id' => $rice->id, 'sale_unit' => null, 'list_price' => '42.00', 'charged' => '45.50'],
        ], $audit->metadata['price_edits']);
    }

    public function test_the_invoice_discount_still_comes_off_the_edited_lines(): void
    {
        $oil = $this->makeProduct($this->store, ['selling_price' => '18.00']);

        $this->sell([
            'items' => [['product_id' => $oil->id, 'quantity' => 3, 'unit_price' => '17.00']],
            'discount_amount' => '1.00',
            'paid_amount' => '50.00',
            'payment_method' => 'cash',
        ])->assertCreated()->assertJsonPath('data.total_amount', '50.00');

        $this->assertSame('1.00', (string) Invoice::firstOrFail()->discount_amount);
    }

    public function test_a_carton_line_takes_its_price_per_carton(): void
    {
        $cola = $this->makeProduct($this->store, ['selling_price' => '3.50', 'pack_size' => 24, 'pack_price' => '80.00', 'current_stock' => 100]);

        $this->sell([
            'items' => [['product_id' => $cola->id, 'quantity' => 2, 'sale_unit' => 'pack', 'unit_price' => '75.00']],
            'paid_amount' => '150.00',
            'payment_method' => 'cash',
        ])->assertCreated()->assertJsonPath('data.total_amount', '150.00');

        $this->assertSame('52.000', (string) $cola->fresh()->current_stock);
        $this->assertSame('80.00', (string) $cola->fresh()->pack_price);
    }

    public function test_the_same_price_as_the_product_is_not_an_edit(): void
    {
        $oil = $this->makeProduct($this->store, ['selling_price' => '18.00']);

        $this->sell([
            'items' => [['product_id' => $oil->id, 'quantity' => 1, 'unit_price' => '18']],
            'paid_amount' => '18.00',
            'payment_method' => 'cash',
        ])->assertCreated();

        $this->assertArrayNotHasKey('price_edits', AuditLog::where('action', 'sale.created')->firstOrFail()->metadata);
    }

    public function test_a_zero_or_bad_price_is_refused(): void
    {
        $oil = $this->makeProduct($this->store, ['selling_price' => '18.00']);

        foreach (['0', '-1', '1.234', 'abc'] as $price) {
            $this->sell([
                'items' => [['product_id' => $oil->id, 'quantity' => 1, 'unit_price' => $price]],
                'paid_amount' => '0',
                'payment_method' => 'cash',
            ])->assertUnprocessable()->assertJsonValidationErrors('items.0.unit_price');
        }

        $this->assertSame(0, Invoice::count());
    }

    // ------------------------------------------------------------ stock value

    public function test_the_stock_value_counts_the_goods_on_the_shelf_at_cost_and_at_selling_price(): void
    {
        $this->makeProduct($this->store, ['current_stock' => 10, 'cost_price' => '2.50', 'selling_price' => '3.50']);
        $this->makeProduct($this->store, ['unit' => 'kg', 'current_stock' => '2.500', 'cost_price' => '28.00', 'selling_price' => '40.00']);
        $this->makeProduct($this->store, ['current_stock' => 4, 'cost_price' => null, 'selling_price' => '5.00']);
        $this->makeProduct($this->store, ['current_stock' => -3, 'cost_price' => '9.00', 'selling_price' => '12.00']);
        $this->makeProduct($this->store, ['current_stock' => 0, 'cost_price' => '9.00', 'selling_price' => '12.00']);
        $this->makeProduct($this->makeStore('Other'), ['current_stock' => 100, 'cost_price' => '9.00']);

        $this->actingAs($this->owner, 'sanctum')->getJson('/api/v1/products/stock-value')
            ->assertOk()
            ->assertExactJson(['data' => [
                'cost_value' => '95.00',
                'selling_value' => '155.00',
                'products_count' => 3,
                'missing_cost_count' => 1,
            ], 'meta' => ['currency' => 'ILS']]);
    }

    public function test_the_stock_value_drops_when_goods_are_sold(): void
    {
        $tea = $this->makeProduct($this->store, ['current_stock' => 10, 'cost_price' => '4.00', 'selling_price' => '6.00']);
        $this->actingAs($this->owner, 'sanctum')->getJson('/api/v1/products/stock-value')->assertJsonPath('data.cost_value', '40.00');

        $this->sell(['items' => [['product_id' => $tea->id, 'quantity' => 3]], 'paid_amount' => '18.00', 'payment_method' => 'cash'])->assertCreated();

        $this->actingAs($this->owner, 'sanctum')->getJson('/api/v1/products/stock-value')->assertJsonPath('data.cost_value', '28.00');
    }

    public function test_employees_cannot_see_the_stock_value(): void
    {
        $this->actingAs($this->makeUser($this->store, 'employee'), 'sanctum')->getJson('/api/v1/products/stock-value')->assertForbidden();
    }

    // ------------------------------------------------------------ platform admin suppliers

    private function makeAdmin(): User
    {
        $admin = $this->makeUser($this->makeStore('Hisbah HQ'), 'owner');
        $admin->forceFill(['is_platform_admin' => true])->save();

        return $admin;
    }

    private function deliver(User $owner, string $supplier, array $lines, string $paid = '0')
    {
        $response = $this->actingAs($owner, 'sanctum')->postJson('/api/v1/purchases', [
            'supplier_name' => $supplier,
            'paid_amount' => $paid,
            'method' => 'cash',
            'lines' => $lines,
        ], $this->idem())->assertCreated();
        $this->app['auth']->forgetGuards();

        return $response;
    }

    public function test_the_admin_sees_every_stores_suppliers_and_their_wholesale_prices(): void
    {
        $cola = ['name' => 'كولا علبة', 'barcode' => '6251234567890', 'unit' => 'piece', 'cartons' => 2, 'pack_size' => 24, 'buy_price' => '60.00', 'selling_price' => '3.50'];
        $this->deliver($this->owner, 'شركة الأمل', [$cola, ['name' => 'لوز نيء', 'unit' => 'kg', 'quantity' => '10', 'buy_price' => '28.00', 'selling_price' => '40.00']], '100.00');
        $this->deliver($this->owner, 'شركة الأمل', [['cartons' => 1, 'buy_price' => '66.00'] + $cola]);
        $otherOwner = $this->makeUser($this->makeStore('بقالة النور'));
        $this->deliver($otherOwner, 'مورد الشمال', [['name' => 'سكر', 'unit' => 'kg', 'quantity' => '50', 'buy_price' => '4.80', 'selling_price' => '6.00']]);

        $admin = $this->makeAdmin();
        $list = $this->actingAs($admin, 'sanctum')->getJson('/api/v1/admin/suppliers')->assertOk();
        $list->assertJsonPath('meta.total', 2);
        $amal = collect($list->json('data'))->firstWhere('name', 'شركة الأمل');
        $this->assertSame($this->store->id, $amal['store']['id']);
        $this->assertSame(2, $amal['products_count']);
        $this->assertSame('466.00', $amal['purchased']);
        $this->assertSame('366.00', $amal['balance']);

        $this->actingAs($admin, 'sanctum')->getJson('/api/v1/admin/suppliers?search=سكر')
            ->assertJsonPath('meta.total', 1)->assertJsonPath('data.0.name', 'مورد الشمال');
        $this->actingAs($admin, 'sanctum')->getJson('/api/v1/admin/suppliers?store=النور')
            ->assertJsonPath('meta.total', 1)->assertJsonPath('data.0.store.name', 'بقالة النور');

        $show = $this->actingAs($admin, 'sanctum')->getJson('/api/v1/admin/suppliers/' . $amal['id'])->assertOk();
        $products = collect($show->json('data.products'))->keyBy('name');
        $this->assertSame('66.00', $products['كولا علبة']['buy_price']);
        $this->assertSame(24, $products['كولا علبة']['pack_size']);
        $this->assertSame('2.75', $products['كولا علبة']['piece_price']);
        $this->assertSame('60.00', $products['كولا علبة']['previous_buy_price']);
        $this->assertSame('72', $products['كولا علبة']['quantity']);
        $this->assertSame(2, $products['كولا علبة']['deliveries']);
        $this->assertSame('28.00', $products['لوز نيء']['buy_price']);
        $this->assertNull($products['لوز نيء']['piece_price']);
        $this->assertNull($products['لوز نيء']['previous_buy_price']);
    }

    public function test_store_accounts_cannot_open_the_admin_suppliers(): void
    {
        $this->deliver($this->owner, 'شركة الأمل', [['name' => 'سكر', 'unit' => 'kg', 'quantity' => '5', 'buy_price' => '4.80', 'selling_price' => '6.00']]);

        $this->actingAs($this->owner, 'sanctum')->getJson('/api/v1/admin/suppliers')->assertForbidden();
        $this->actingAs($this->owner, 'sanctum')->getJson('/api/v1/admin/suppliers/1')->assertForbidden();
        $this->actingAs($this->makeAdmin(), 'sanctum')->getJson('/api/v1/admin/suppliers/999')->assertNotFound();
    }
}
