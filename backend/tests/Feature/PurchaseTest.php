<?php

namespace Tests\Feature;

use App\Models\Product;
use App\Models\Store;
use App\Models\Supplier;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Support\BuildsShopData;
use Tests\TestCase;

/** «تسجيل بضاعة»: a supplier invoice adds stock, and what is left stays on the supplier's account. */
class PurchaseTest extends TestCase
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

    private function delivery(array $overrides = []): array
    {
        return $overrides + [
            'supplier_name' => 'شركة الأمل',
            'paid_amount' => '400.00',
            'method' => 'cash',
            'lines' => [
                ['name' => 'كولا علبة', 'barcode' => '6251234567890', 'unit' => 'piece', 'cartons' => 4, 'pack_size' => 24, 'buy_price' => '60.00', 'selling_price' => '3.50'],
                ['name' => 'حليب 1 لتر', 'unit' => 'piece', 'cartons' => 3, 'pack_size' => 12, 'buy_price' => '66.00', 'selling_price' => '6.50'],
                ['name' => 'لوز نيء', 'unit' => 'kg', 'quantity' => '10', 'buy_price' => '28.00', 'selling_price' => '40.00'],
            ],
        ];
    }

    private function deliver(array $body, ?User $user = null)
    {
        return $this->actingAs($user ?? $this->owner, 'sanctum')->postJson('/api/v1/purchases', $body, $this->idem());
    }

    public function test_the_total_comes_from_the_lines_and_stock_and_cost_follow(): void
    {
        $this->deliver($this->delivery())
            ->assertCreated()
            ->assertJsonPath('data.total', '718.00')
            ->assertJsonPath('data.paid', '400.00')
            ->assertJsonPath('data.remaining', '318.00')
            ->assertJsonPath('data.lines', 3);

        $cola = Product::where('name', 'كولا علبة')->firstOrFail();
        $this->assertSame('96.000', $cola->current_stock);
        $this->assertSame('2.50', $cola->cost_price);
        $this->assertSame(24, $cola->pack_size);
        $this->assertSame('84.00', $cola->pack_price);
        $this->assertSame('purchase', $cola->movements()->latest('id')->first()->type);

        $almond = Product::where('name', 'لوز نيء')->firstOrFail();
        $this->assertSame('10.000', $almond->current_stock);
        $this->assertSame('28.00', $almond->cost_price);
        $this->assertNull($almond->pack_size);
        $this->assertNull($almond->barcode);
    }

    public function test_the_total_ignores_anything_the_client_sends(): void
    {
        $this->deliver($this->delivery(['total' => '1.00']))->assertCreated()->assertJsonPath('data.total', '718.00');
    }

    public function test_an_existing_product_gets_the_stock_and_new_prices_found_by_barcode(): void
    {
        $this->deliver($this->delivery())->assertCreated();

        $this->deliver([
            'supplier_name' => 'شركة الأمل',
            'lines' => [['barcode' => '6251234567890', 'cartons' => 1, 'pack_size' => 24, 'buy_price' => '72.00']],
        ])->assertCreated()->assertJsonPath('data.remaining', '72.00');

        $cola = Product::where('barcode', '6251234567890')->firstOrFail();
        $this->assertSame('120.000', $cola->current_stock);
        $this->assertSame('3.00', $cola->cost_price);
        $this->assertSame('3.50', $cola->selling_price);
        $this->assertSame(1, Supplier::count());
    }

    public function test_paying_more_than_the_total_changes_nothing(): void
    {
        $this->deliver($this->delivery(['paid_amount' => '718.01']))->assertUnprocessable()->assertJsonValidationErrors('paid_amount');

        $this->assertSame(0, Product::count());
        $this->assertSame(0, Supplier::count());
    }

    public function test_a_new_line_needs_its_name_and_quantities(): void
    {
        $this->deliver([
            'supplier_name' => 'شركة الأمل',
            'lines' => [
                ['unit' => 'piece', 'buy_price' => '10.00'],
                ['name' => 'لوز', 'unit' => 'kg', 'buy_price' => '10.00', 'selling_price' => '12.00'],
            ],
        ])->assertUnprocessable()->assertJsonValidationErrors([
            'lines.0.name',
            'lines.0.selling_price',
            'lines.0.cartons',
            'lines.0.pack_size',
            'lines.1.quantity',
        ]);
    }

    public function test_the_supplier_is_required(): void
    {
        $body = $this->delivery();
        unset($body['supplier_name']);

        $this->deliver($body)->assertUnprocessable()->assertJsonValidationErrors('supplier_name');
    }

    public function test_the_account_shows_the_balance_and_a_payment_lowers_it(): void
    {
        $this->deliver($this->delivery())->assertCreated();
        $supplier = Supplier::firstOrFail();
        $owner = $this->actingAs($this->owner, 'sanctum');

        $owner->getJson('/api/v1/suppliers')->assertOk()->assertJsonPath('data.0.balance', '318.00');
        $owner->getJson("/api/v1/suppliers/{$supplier->id}")
            ->assertOk()
            ->assertJsonPath('data.balance', '318.00')
            ->assertJsonCount(2, 'data.entries');

        $owner->postJson("/api/v1/suppliers/{$supplier->id}/payments", ['amount' => '118.00', 'method' => 'palpay'], $this->idem())
            ->assertCreated()
            ->assertJsonPath('data.balance', '200.00');

        $owner->postJson("/api/v1/suppliers/{$supplier->id}/payments", ['amount' => '200.01', 'method' => 'cash'], $this->idem())
            ->assertUnprocessable()
            ->assertJsonValidationErrors('amount');
    }

    public function test_a_retry_with_the_same_key_counts_once(): void
    {
        $key = $this->idem();
        $this->actingAs($this->owner, 'sanctum')->postJson('/api/v1/purchases', $this->delivery(), $key)->assertCreated();
        $this->actingAs($this->owner, 'sanctum')->postJson('/api/v1/purchases', $this->delivery(), $key)->assertCreated();

        $this->assertSame('96.000', Product::where('name', 'كولا علبة')->firstOrFail()->current_stock);
    }

    public function test_employees_and_other_stores_cannot_reach_it(): void
    {
        $this->deliver($this->delivery())->assertCreated();
        $supplier = Supplier::firstOrFail();

        $employee = $this->makeUser($this->store, 'employee');
        $this->deliver($this->delivery(), $employee)->assertForbidden();
        $this->actingAs($employee, 'sanctum')->getJson('/api/v1/suppliers')->assertForbidden();

        $other = $this->makeUser($this->makeStore('Other'));
        $this->actingAs($other, 'sanctum')->getJson("/api/v1/suppliers/{$supplier->id}")->assertNotFound();
        $this->actingAs($other, 'sanctum')->getJson('/api/v1/suppliers')->assertOk()->assertJsonCount(0, 'data');
    }

    public function test_the_platform_admin_issues_a_code_that_works_for_sign_up(): void
    {
        config(['services.sms.driver' => 'log']);
        $admin = $this->makeUser($this->store, 'owner', ['is_platform_admin' => true]);

        $code = $this->actingAs($admin, 'sanctum')
            ->postJson('/api/v1/admin/otp-codes', ['phone' => '0599123456', 'purpose' => 'register'])
            ->assertCreated()
            ->json('data.code');

        $this->assertMatchesRegularExpression('/^\d{6}$/', $code);

        app(\App\Services\OtpService::class)->verify('0599123456', 'register', $code);
        $this->assertSame(1, \App\Models\PhoneOtp::whereNotNull('consumed_at')->count());

        $this->actingAs($this->owner, 'sanctum')
            ->postJson('/api/v1/admin/otp-codes', ['phone' => '0599123456', 'purpose' => 'register'])
            ->assertForbidden();
    }
}
