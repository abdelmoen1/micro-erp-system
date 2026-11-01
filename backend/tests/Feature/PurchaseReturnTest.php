<?php

namespace Tests\Feature;

use App\Models\AuditLog;
use App\Models\Product;
use App\Models\PurchaseInvoice;
use App\Models\Store;
use App\Models\Supplier;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Support\BuildsShopData;
use Tests\TestCase;

/** Goods back to the supplier: the balance first, then a refund; the purchases and returns registers. */
class PurchaseReturnTest extends TestCase
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

    /** 4 cartons of 24 at 60.00 = 240.00, 96 pieces; 10 kg at 28.00 = 280.00. Total 520.00. */
    private function delivery(string $paid = '0'): PurchaseInvoice
    {
        $this->actingAs($this->owner, 'sanctum')->postJson('/api/v1/purchases', [
            'supplier_name' => 'شركة الأمل',
            'paid_amount' => $paid,
            'method' => 'cash',
            'lines' => [
                ['name' => 'كولا علبة', 'barcode' => '6251234567890', 'unit' => 'piece', 'cartons' => 4, 'pack_size' => 24, 'buy_price' => '60.00', 'selling_price' => '3.50'],
                ['name' => 'لوز نيء', 'unit' => 'kg', 'quantity' => '10', 'buy_price' => '28.00', 'selling_price' => '40.00'],
            ],
        ], $this->idem())->assertCreated();

        return PurchaseInvoice::with('items')->latest('id')->firstOrFail();
    }

    private function sendBack(PurchaseInvoice $invoice, array $lines, string $reason = 'بضاعة تالفة', ?User $user = null)
    {
        return $this->actingAs($user ?? $this->owner, 'sanctum')->postJson("/api/v1/purchases/{$invoice->id}/returns", [
            'items' => $lines,
            'reason' => $reason,
        ], $this->idem());
    }

    public function test_a_return_lowers_the_balance_and_the_stock_and_is_audited(): void
    {
        $invoice = $this->delivery();
        $cola = $invoice->items[0];

        $this->sendBack($invoice, [['purchase_item_id' => $cola->id, 'quantity' => 24]])
            ->assertCreated()
            ->assertJsonPath('data.total_amount', '60.00')
            ->assertJsonPath('data.balance_reduction', '60.00')
            ->assertJsonPath('data.refund_amount', '0.00')
            ->assertJsonPath('data.items.0.item_name', 'كولا علبة')
            ->assertJsonPath('data.items.0.quantity', '24')
            ->assertJsonPath('balance', '460.00');

        $this->assertSame('72.000', Product::where('name', 'كولا علبة')->sole()->current_stock);
        $this->assertSame('460.00', Supplier::sole()->balance());
        $this->assertDatabaseHas('stock_movements', ['product_id' => $cola->product_id, 'type' => 'purchase_return', 'quantity' => -24, 'reference_type' => 'purchase_return']);
        $this->assertSame(1, AuditLog::where('action', 'purchase.returned')->count());
    }

    public function test_past_the_balance_the_rest_is_a_refund_from_the_supplier(): void
    {
        $invoice = $this->delivery('500.00');

        $this->sendBack($invoice, [['purchase_item_id' => $invoice->items[0]->id, 'quantity' => 48]])
            ->assertCreated()
            ->assertJsonPath('data.balance_reduction', '20.00')
            ->assertJsonPath('data.refund_amount', '100.00')
            ->assertJsonPath('balance', '0.00');

        $this->actingAs($this->owner, 'sanctum')->getJson('/api/v1/suppliers')->assertJsonPath('data.0.balance', '0.00');
    }

    public function test_goods_already_off_the_shelf_move_no_stock(): void
    {
        $invoice = $this->delivery();
        $item = $invoice->items[0];

        $this->sendBack($invoice, [['purchase_item_id' => $item->id, 'quantity' => 2, 'from_stock' => false]])
            ->assertCreated()
            ->assertJsonPath('data.items.0.from_stock', false);

        $this->assertSame('96.000', Product::find($item->product_id)->current_stock);
        $this->assertDatabaseMissing('stock_movements', ['type' => 'purchase_return']);
    }

    public function test_a_return_cannot_take_more_than_was_bought_or_what_is_on_the_shelf(): void
    {
        $invoice = $this->delivery();
        $item = $invoice->items[0];

        $this->sendBack($invoice, [['purchase_item_id' => $item->id, 'quantity' => 97]])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('items.0.quantity');

        $this->sendBack($invoice, [['purchase_item_id' => $item->id, 'quantity' => 90]])->assertCreated();
        $this->sendBack($invoice, [['purchase_item_id' => $item->id, 'quantity' => 7]])->assertUnprocessable();

        // Sold off the shelf: the goods are gone, and the books must not go below zero.
        Product::find($item->product_id)->update(['current_stock' => '1.000']);
        $this->sendBack($invoice, [['purchase_item_id' => $item->id, 'quantity' => 5]])
            ->assertStatus(422)
            ->assertJsonPath('code', 'INSUFFICIENT_STOCK');

        $this->assertDatabaseCount('purchase_returns', 1);
    }

    public function test_partial_returns_of_a_line_add_up_to_its_total_to_the_agora(): void
    {
        $this->actingAs($this->owner, 'sanctum')->postJson('/api/v1/purchases', [
            'supplier_name' => 'شركة الأمل',
            'lines' => [['name' => 'عصير', 'barcode' => '6251234567807', 'unit' => 'piece', 'cartons' => 1, 'pack_size' => 7, 'buy_price' => '10.00', 'selling_price' => '2.00']],
        ], $this->idem())->assertCreated();
        $invoice = PurchaseInvoice::with('items')->sole();
        $item = $invoice->items[0];

        $first = $this->sendBack($invoice, [['purchase_item_id' => $item->id, 'quantity' => 3]])->assertCreated()->json('data.total_amount');
        $second = $this->sendBack($invoice, [['purchase_item_id' => $item->id, 'quantity' => 4]])->assertCreated()->json('data.total_amount');

        $this->assertSame('4.29', $first);
        $this->assertSame('5.71', $second);
        $this->assertSame('0.00', Supplier::sole()->balance());
    }

    public function test_the_registers_list_purchases_and_both_kinds_of_returns(): void
    {
        $invoice = $this->delivery();
        $this->sendBack($invoice, [['purchase_item_id' => $invoice->items[0]->id, 'quantity' => 24]])->assertCreated();

        $api = $this->actingAs($this->owner, 'sanctum');
        $api->getJson('/api/v1/purchases')
            ->assertOk()
            ->assertJsonPath('data.0.total', '520.00')
            ->assertJsonPath('data.0.returned_amount', '60.00')
            ->assertJsonPath('data.0.lines_count', 2)
            ->assertJsonPath('data.0.supplier.name', 'شركة الأمل');
        $api->getJson("/api/v1/purchases/{$invoice->id}")
            ->assertOk()
            ->assertJsonPath('data.items.0.quantity', '96')
            ->assertJsonPath('data.items.0.returned_quantity', '24')
            ->assertJsonPath('data.returns.0.reason', 'بضاعة تالفة');
        $api->getJson('/api/v1/returns/purchases')->assertOk()->assertJsonPath('data.0.supplier.name', 'شركة الأمل');
        $api->getJson('/api/v1/suppliers/' . $invoice->supplier_id)->assertOk()->assertJsonPath('data.returns.0.total_amount', '60.00');

        $tomorrow = now()->addDays(2)->toDateString();
        $api->getJson("/api/v1/purchases?from={$tomorrow}")->assertOk()->assertJsonCount(0, 'data');
    }

    public function test_the_dashboard_counts_returns_and_hides_costs_from_employees(): void
    {
        $invoice = $this->delivery('100.00');
        $this->sendBack($invoice, [['purchase_item_id' => $invoice->items[0]->id, 'quantity' => 24]])->assertCreated();

        $this->actingAs($this->owner, 'sanctum')->getJson('/api/v1/dashboard?period=today')
            ->assertOk()
            ->assertJsonPath('data.purchases.total', '520.00')
            ->assertJsonPath('data.purchases.returns_total', '60.00')
            ->assertJsonPath('data.purchases.owed_to_suppliers', '360.00');

        $employee = $this->makeUser($this->store, 'employee');
        $this->actingAs($employee, 'sanctum')->getJson('/api/v1/dashboard?period=today')
            ->assertOk()
            ->assertJsonPath('data.purchases', null);
    }

    public function test_employees_and_other_stores_are_kept_out(): void
    {
        $invoice = $this->delivery();
        $employee = $this->makeUser($this->store, 'employee');

        $this->sendBack($invoice, [['purchase_item_id' => $invoice->items[0]->id, 'quantity' => 1]], user: $employee)->assertForbidden();
        $this->actingAs($employee, 'sanctum')->getJson('/api/v1/purchases')->assertForbidden();
        $this->actingAs($employee, 'sanctum')->getJson('/api/v1/returns/purchases')->assertForbidden();

        $stranger = $this->makeUser($this->makeStore());
        $this->sendBack($invoice, [['purchase_item_id' => $invoice->items[0]->id, 'quantity' => 1]], user: $stranger)->assertNotFound();
        $this->actingAs($stranger, 'sanctum')->getJson("/api/v1/purchases/{$invoice->id}")->assertNotFound();
        $this->actingAs($stranger, 'sanctum')->getJson('/api/v1/purchases')->assertJsonCount(0, 'data');
    }

    public function test_a_retry_with_the_same_key_counts_once(): void
    {
        $invoice = $this->delivery();
        $key = $this->idem();
        $body = ['items' => [['purchase_item_id' => $invoice->items[0]->id, 'quantity' => 24]], 'reason' => 'خلاف على الكمية'];

        $this->actingAs($this->owner, 'sanctum')->postJson("/api/v1/purchases/{$invoice->id}/returns", $body, $key)->assertCreated();
        $this->actingAs($this->owner, 'sanctum')->postJson("/api/v1/purchases/{$invoice->id}/returns", $body, $key)->assertCreated();

        $this->assertDatabaseCount('purchase_returns', 1);
        $this->assertSame('72.000', Product::where('name', 'كولا علبة')->sole()->current_stock);
    }
}
