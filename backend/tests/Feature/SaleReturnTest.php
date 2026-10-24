<?php

namespace Tests\Feature;

use App\Models\AuditLog;
use App\Models\Debt;
use App\Models\Invoice;
use App\Models\Store;
use App\Models\User;
use App\Services\SaleService;
use Tests\Support\BuildsShopData;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/** US-0601 sale returns (D-05 debt first, then cash refund) — TC-0601-01 … 07. */
class SaleReturnTest extends TestCase
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

    /** TC-0601-01: cash sale, one unit back: stock +1, refund = unit price, audited. */
    public function test_cash_sale_return_refunds_and_restores_stock(): void
    {
        $tea = $this->makeProduct($this->store, ['selling_price' => '6.50', 'current_stock' => 10]);
        $sale = $this->sale(['items' => [['product_id' => $tea->id, 'quantity' => 3]], 'paid_amount' => '19.50', 'payment_method' => 'cash']);

        $this->returnLines($sale, [[$sale->items[0]->id, 1]])
            ->assertCreated()
            ->assertJsonPath('data.total_amount', '6.50')
            ->assertJsonPath('data.debt_reduction', '0.00')
            ->assertJsonPath('data.refund_amount', '6.50')
            ->assertJsonPath('invoice.items.0.returned_quantity', '1')
            ->assertJsonPath('invoice.returned_amount', '6.50');

        $this->assertSame('8.000', $tea->fresh()->current_stock);
        $this->assertDatabaseHas('stock_movements', ['product_id' => $tea->id, 'type' => 'sale_return', 'quantity' => 1]);
        $this->assertSame(1, AuditLog::where('action', 'sale.returned')->count());
    }

    /** TC-0601-02: unpaid credit sale: return credit grows by the value, nothing refunded. */
    public function test_credit_sale_return_reduces_the_debt(): void
    {
        $customer = $this->makeCustomer($this->store);
        $nuts = $this->makeProduct($this->store, ['selling_price' => '60.00', 'unit' => 'kg', 'current_stock' => 5]);
        $sale = $this->sale(['customer_id' => $customer->id, 'items' => [['product_id' => $nuts->id, 'quantity' => '0.750']], 'paid_amount' => '0']);

        $this->returnLines($sale, [[$sale->items[0]->id, '0.250']])
            ->assertCreated()
            ->assertJsonPath('data.debt_reduction', '15.00')
            ->assertJsonPath('data.refund_amount', '0.00');

        $debt = Debt::where('invoice_id', $sale->id)->sole();
        $this->assertSame('15.00', $debt->return_credit);
        $this->assertSame('30.00', $debt->remaining_amount);
        $this->assertSame('4.500', $nuts->fresh()->current_stock);
    }

    /** TC-0601-03: remaining 5.00, return worth 15.00: debt −5.00 (paid), refund 10.00. */
    public function test_partial_sale_return_pays_off_debt_then_refunds_the_excess(): void
    {
        $customer = $this->makeCustomer($this->store);
        $oil = $this->makeProduct($this->store, ['selling_price' => '15.00']);
        $sale = $this->sale(['customer_id' => $customer->id, 'items' => [['product_id' => $oil->id, 'quantity' => 2]], 'paid_amount' => '25.00', 'payment_method' => 'cash']);

        $this->returnLines($sale, [[$sale->items[0]->id, 1]])
            ->assertCreated()
            ->assertJsonPath('data.debt_reduction', '5.00')
            ->assertJsonPath('data.refund_amount', '10.00');

        $debt = Debt::where('invoice_id', $sale->id)->sole();
        $this->assertSame('0.00', $debt->remaining_amount);
        $this->assertSame('paid', $debt->status);
    }

    /** TC-0601-04: more than sold − returned is 422 and nothing is written. */
    public function test_over_return_is_rejected_without_writes(): void
    {
        $tea = $this->makeProduct($this->store);
        $sale = $this->sale(['items' => [['product_id' => $tea->id, 'quantity' => 2]], 'paid_amount' => '20.00', 'payment_method' => 'cash']);
        $this->returnLines($sale, [[$sale->items[0]->id, 1]])->assertCreated();

        $this->returnLines($sale, [[$sale->items[0]->id, 2]])
            ->assertStatus(422)
            ->assertJsonPath('code', 'VALIDATION_FAILED')
            ->assertJsonValidationErrors('items.0.quantity');

        $this->assertSame('9.000', $tea->fresh()->current_stock);
        $this->assertDatabaseCount('sale_returns', 1);
    }

    /** TC-0601-05: a voided sale cannot be returned. */
    public function test_voided_sale_cannot_be_returned(): void
    {
        $customer = $this->makeCustomer($this->store);
        $sale = $this->sale(['customer_id' => $customer->id, 'items' => [['product_id' => $this->makeProduct($this->store)->id, 'quantity' => 1]], 'paid_amount' => '0']);
        app(SaleService::class)->void($this->owner, $sale, 'Mistake');

        $this->returnLines($sale, [[$sale->items[0]->id, 1]])
            ->assertStatus(422)
            ->assertJsonPath('code', 'INVOICE_VOIDED');
    }

    /** TC-0601-06: employees cannot return; another store's sale is a 404. */
    public function test_employee_is_forbidden_and_other_store_is_hidden(): void
    {
        $sale = $this->sale(['items' => [['product_id' => $this->makeProduct($this->store)->id, 'quantity' => 1]], 'paid_amount' => '10.00', 'payment_method' => 'cash']);
        $employee = $this->makeUser($this->store, 'employee');

        $this->returnLines($sale, [[$sale->items[0]->id, 1]], $employee)->assertForbidden();

        $other = $this->makeUser($this->makeStore('Other'));
        $this->returnLines($sale, [[$sale->items[0]->id, 1]], $other)->assertNotFound();
    }

    /** US-0503 interaction: once something is returned the sale cannot be voided. */
    public function test_returned_sale_cannot_be_voided_and_detail_lists_returns(): void
    {
        $sale = $this->sale(['items' => [['product_id' => $this->makeProduct($this->store)->id, 'quantity' => 2]], 'paid_amount' => '20.00', 'payment_method' => 'cash']);
        $this->returnLines($sale, [[$sale->items[0]->id, 1]])->assertCreated();

        $this->actingAs($this->owner, 'sanctum')->getJson("/api/v1/sales/{$sale->id}")
            ->assertOk()
            ->assertJsonCount(1, 'data.returns')
            ->assertJsonPath('data.returns.0.reason', 'Damaged')
            ->assertJsonPath('data.returns.0.items.0.quantity', '1');

        $this->actingAs($this->owner, 'sanctum')
            ->postJson("/api/v1/sales/{$sale->id}/void", ['reason' => 'x'], $this->idem())
            ->assertStatus(409)
            ->assertJsonPath('code', 'INVOICE_HAS_RETURNS');
    }

    private function sale(array $body): Invoice
    {
        return app(SaleService::class)->create($this->owner, $body)['invoice'];
    }

    private function returnLines(Invoice $sale, array $lines, ?User $actor = null)
    {
        $response = $this->actingAs($actor ?? $this->owner, 'sanctum')->postJson("/api/v1/sales/{$sale->id}/returns", [
            'items' => array_map(fn($l) => ['invoice_item_id' => $l[0], 'quantity' => $l[1]], $lines),
            'reason' => 'Damaged',
        ], $this->idem());
        $this->app['auth']->forgetGuards();

        return $response;
    }
}
