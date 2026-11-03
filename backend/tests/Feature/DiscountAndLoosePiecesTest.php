<?php

namespace Tests\Feature;

use App\Models\Debt;
use App\Models\Invoice;
use App\Models\Product;
use App\Models\Store;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Support\BuildsShopData;
use Tests\TestCase;

/** A discount at the till (101 → 100) and the loose pieces of an opened carton in a delivery. */
class DiscountAndLoosePiecesTest extends TestCase
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

    private function sell(array $body)
    {
        $response = $this->actingAs($this->owner, 'sanctum')->postJson('/api/v1/sales', $body, $this->idem());
        $this->app['auth']->forgetGuards();

        return $response;
    }

    /** 2 × 50.50 = 101.00 */
    private function lines(): array
    {
        $rice = $this->makeProduct($this->store, ['selling_price' => '50.50', 'current_stock' => 10]);

        return [['product_id' => $rice->id, 'quantity' => 2]];
    }

    public function test_a_discount_lowers_what_the_customer_pays_and_is_on_the_invoice(): void
    {
        $this->sell(['items' => $this->lines(), 'discount_amount' => '1', 'paid_amount' => '100.00', 'payment_method' => 'cash'])
            ->assertCreated()
            ->assertJsonPath('data.subtotal_amount', '101.00')
            ->assertJsonPath('data.discount_amount', '1.00')
            ->assertJsonPath('data.total_amount', '100.00')
            ->assertJsonPath('data.debt_amount', '0.00')
            ->assertJsonPath('data.has_debt', false);

        $this->assertSame('1.00', Invoice::sole()->discount_amount);
    }

    public function test_without_a_discount_nothing_changes(): void
    {
        $this->sell(['items' => $this->lines(), 'paid_amount' => '101.00', 'payment_method' => 'cash'])
            ->assertCreated()
            ->assertJsonPath('data.discount_amount', '0.00')
            ->assertJsonPath('data.subtotal_amount', '101.00')
            ->assertJsonPath('data.total_amount', '101.00');
    }

    public function test_the_paid_amount_is_checked_against_the_total_after_the_discount(): void
    {
        $this->sell(['items' => $this->lines(), 'discount_amount' => '1.00', 'paid_amount' => '101.00', 'payment_method' => 'cash'])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('paid_amount');
        $this->assertSame(0, Invoice::count());
    }

    public function test_a_discount_cannot_take_the_whole_sale_or_be_negative(): void
    {
        $this->sell(['items' => $this->lines(), 'discount_amount' => '101.00', 'paid_amount' => '0', 'payment_method' => 'cash'])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('discount_amount');
        $this->sell(['items' => $this->lines(), 'discount_amount' => '-1', 'paid_amount' => '101.00', 'payment_method' => 'cash'])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('discount_amount');
        $this->assertSame(0, Invoice::count());
    }

    public function test_on_credit_the_debt_is_the_total_after_the_discount(): void
    {
        $customer = $this->makeCustomer($this->store);
        $this->sell(['customer_id' => $customer->id, 'items' => $this->lines(), 'discount_amount' => '1.00', 'paid_amount' => '40.00', 'payment_method' => 'cash'])
            ->assertCreated()
            ->assertJsonPath('data.debt_amount', '60.00');

        $this->assertSame('60.00', Debt::sole()->amount);
    }

    public function test_returns_of_a_discounted_sale_give_back_what_was_charged(): void
    {
        $sale = $this->sell(['items' => $this->lines(), 'discount_amount' => '1.00', 'paid_amount' => '100.00', 'payment_method' => 'cash'])->json('data');
        $line = $sale['items'][0]['id'];

        $return = fn() => $this->actingAs($this->owner, 'sanctum')->postJson("/api/v1/sales/{$sale['id']}/returns", [
            'items' => [['invoice_item_id' => $line, 'quantity' => 1]],
            'reason' => 'تالف',
        ], $this->idem());

        // 50.50 less half of the 1.00 discount, then the rest of the 100.00 charged.
        $return()->assertCreated()->assertJsonPath('data.total_amount', '50.00')->assertJsonPath('data.refund_amount', '50.00');
        $return()->assertCreated()->assertJsonPath('data.total_amount', '50.00')->assertJsonPath('invoice.returned_amount', '100.00');
    }

    public function test_offline_sales_keep_their_discount(): void
    {
        $this->actingAs($this->owner, 'sanctum')->postJson('/api/v1/sync/batch', [
            'device_id' => 'phone-1',
            'items' => [[
                'client_transaction_id' => (string) \Illuminate\Support\Str::uuid(),
                'seq' => 1,
                'type' => 'sale',
                'occurred_at' => now()->subMinute()->toIso8601String(),
                'payload' => ['items' => $this->lines(), 'discount_amount' => '1.00', 'paid_amount' => '100.00', 'payment_method' => 'cash'],
            ]],
        ])->assertOk();

        $this->assertSame('100.00', Invoice::sole()->total_amount);
        $this->assertSame('1.00', Invoice::sole()->discount_amount);
    }

    private function deliver(array $line)
    {
        return $this->actingAs($this->owner, 'sanctum')->postJson('/api/v1/purchases', [
            'supplier_name' => 'شركة الأمل',
            'lines' => [$line + ['name' => 'كولا علبة', 'barcode' => '6251234567890', 'unit' => 'piece', 'pack_size' => 24, 'buy_price' => '60.00', 'selling_price' => '3.50']],
        ], $this->idem());
    }

    public function test_loose_pieces_of_an_opened_carton_join_the_stock_and_the_total(): void
    {
        // 2 cartons + 5 pieces = 53 pieces at 60.00 / 24 = 132.50.
        $this->deliver(['cartons' => 2, 'loose_pieces' => 5])
            ->assertCreated()
            ->assertJsonPath('data.total', '132.50');

        $cola = Product::where('name', 'كولا علبة')->firstOrFail();
        $this->assertSame('53.000', $cola->current_stock);
        $this->assertSame('2.50', $cola->cost_price);

        $invoice = $this->actingAs($this->owner, 'sanctum')->getJson('/api/v1/purchases/' . \App\Models\PurchaseInvoice::sole()->id);
        $invoice->assertJsonPath('data.items.0.cartons', 2)->assertJsonPath('data.items.0.loose_pieces', 5);
    }

    public function test_a_delivery_may_be_only_loose_pieces_but_not_nothing(): void
    {
        $this->deliver(['cartons' => 0, 'loose_pieces' => 6])->assertCreated()->assertJsonPath('data.total', '15.00');
        $this->deliver(['cartons' => 0, 'loose_pieces' => 0])->assertUnprocessable()->assertJsonValidationErrors('lines.0.cartons');
    }
}
