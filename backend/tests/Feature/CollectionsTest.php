<?php

namespace Tests\Feature;

use App\Models\Customer;
use App\Models\Debt;
use App\Models\Payment;
use App\Models\Store;
use App\Models\User;
use App\Services\ReturnService;
use App\Services\SaleService;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Tests\Support\BuildsShopData;
use Tests\TestCase;

/**
 * US-0702 debt lists, US-0703 payments v1, US-0302 statement and summary, US-0301 AC4 customer
 * deactivation, US-0705 AC2 custom amount.
 */
class CollectionsTest extends TestCase
{
    use BuildsShopData;
    use RefreshDatabase;

    private Store $store;
    private User $owner;

    protected function setUp(): void
    {
        parent::setUp();
        // 21:30 UTC on 22 Oct is 00:30 on 23 Oct in Hebron: "today" must be the local date.
        CarbonImmutable::setTestNow(CarbonImmutable::parse('2026-10-22 21:30:00', 'UTC'));
        $this->store = $this->makeStore('Main', ['timezone' => 'Asia/Hebron']);
        $this->owner = $this->makeUser($this->store);
    }

    protected function tearDown(): void
    {
        CarbonImmutable::setTestNow();
        parent::tearDown();
    }

    /** TC-0702-01/02/04: buckets use the store's local date; paid and cancelled never qualify. */
    public function test_buckets_follow_store_timezone_and_skip_closed_debts(): void
    {
        $customer = $this->makeCustomer($this->store);
        $today = $this->debt($customer, '30.00', '2026-10-23');      // local today (23 Oct)
        $late = $this->debt($customer, '40.00', '2026-10-20');
        $paid = $this->debt($customer, '50.00', '2026-10-19');
        $paid->update(['remaining_amount' => '0.00', 'status' => 'paid']);
        $cancelled = $this->debt($customer, '60.00', '2026-10-18');
        $cancelled->update(['remaining_amount' => '0.00', 'status' => Debt::STATUS_CANCELLED]);

        $this->listDebts('due_today')->assertOk()->assertJsonCount(1, 'data')->assertJsonPath('data.0.id', $today->id);
        $this->listDebts('overdue')->assertOk()->assertJsonCount(1, 'data')->assertJsonPath('data.0.id', $late->id)
            ->assertJsonPath('meta.total_remaining', '40.00')
            ->assertJsonPath('meta.counts.overdue', 1);
        $this->listDebts('open')->assertJsonPath('meta.total_remaining', '70.00');
    }

    /** TC-0702-03: customers by total remaining, highest first. */
    public function test_balances_order_customers_by_total_remaining(): void
    {
        [$small, $big] = [$this->makeCustomer($this->store), $this->makeCustomer($this->store)];
        $this->debt($small, '20.00');
        $this->debt($big, '70.00');
        $this->debt($big, '15.50', '2026-10-01');

        $this->actingAs($this->owner, 'sanctum')->getJson('/api/v1/debts/balances')
            ->assertOk()
            ->assertJsonPath('data.0.customer.id', $big->id)
            ->assertJsonPath('data.0.total_remaining', '85.50')
            ->assertJsonPath('data.0.open_count', 2)
            ->assertJsonPath('data.0.oldest_due', '2026-10-01')
            ->assertJsonPath('data.1.customer.id', $small->id);
    }

    /** TC-0703-01 / US-0705 AC2: attributed payments; a custom amount goes oldest due first. */
    public function test_custom_amount_is_allocated_oldest_due_first_and_attributed(): void
    {
        $customer = $this->makeCustomer($this->store);
        $later = $this->debt($customer, '100.00', '2026-11-01');
        $older = $this->debt($customer, '30.00', '2026-10-10');
        $noDue = $this->debt($customer, '50.00');

        $this->actingAs($this->owner, 'sanctum')
            ->postJson("/api/v1/customers/{$customer->id}/debts/pay-all", ['amount' => '45.00', 'method' => 'cash'], $this->idem())
            ->assertCreated()
            ->assertJsonPath('data.total_paid', '45.00')
            ->assertJsonPath('data.debts_count', 2)
            ->assertJsonPath('data.remaining_after', '135.00');

        $this->assertSame('0.00', $older->fresh()->remaining_amount);
        $this->assertSame('85.00', $later->fresh()->remaining_amount);
        $this->assertSame('50.00', $noDue->fresh()->remaining_amount);

        $payment = Payment::where('debt_id', $older->id)->sole();
        $this->assertSame($this->store->id, $payment->store_id);
        $this->assertSame($customer->id, $payment->customer_id);
        $this->assertSame($this->owner->id, $payment->created_by);

        $this->actingAs($this->owner, 'sanctum')
            ->postJson("/api/v1/customers/{$customer->id}/debts/pay-all", ['amount' => '500.00', 'method' => 'cash'], $this->idem())
            ->assertStatus(422)
            ->assertJsonPath('code', 'PAYMENT_EXCEEDS_REMAINING');
    }

    /** TC-0703-02/03 (DEF-10): a group payment reverses only with its group; reverser recorded. */
    public function test_group_payment_needs_group_reversal(): void
    {
        $customer = $this->makeCustomer($this->store);
        $a = $this->debt($customer, '10.00');
        $b = $this->debt($customer, '20.00');
        $group = $this->actingAs($this->owner, 'sanctum')
            ->postJson("/api/v1/customers/{$customer->id}/debts/pay-all", ['method' => 'cash'], $this->idem())
            ->json('data.payment_group_id');
        $payment = Payment::where('debt_id', $a->id)->sole();

        $this->actingAs($this->owner, 'sanctum')
            ->postJson("/api/v1/payments/{$payment->id}/reverse", ['reason' => 'x'], $this->idem())
            ->assertStatus(422)
            ->assertJsonPath('code', 'REVERSE_GROUP_REQUIRED')
            ->assertJsonPath('details.payment_group_id', $group);

        $this->actingAs($this->owner, 'sanctum')
            ->postJson("/api/v1/payment-groups/{$group}/reverse", ['reason' => 'Wrong customer'], $this->idem())
            ->assertOk()
            ->assertJsonPath('data.total_reversed', '30.00');

        $this->assertSame('20.00', $b->fresh()->remaining_amount);
        $this->assertSame($this->owner->id, $payment->fresh()->reversed_by);
    }

    /** TC-0703-04: history filtered by customer and invoice. */
    public function test_payment_history_filters_by_customer_and_invoice(): void
    {
        [$mine, $other] = [$this->makeCustomer($this->store), $this->makeCustomer($this->store)];
        $debt = $this->debt($mine, '40.00');
        $this->debt($other, '40.00');
        $this->pay($debt, '15.00');
        $this->pay(Debt::where('customer_id', $other->id)->sole(), '5.00');

        $this->actingAs($this->owner, 'sanctum')->getJson("/api/v1/payments?customer_id={$mine->id}")
            ->assertOk()->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.customer.id', $mine->id)
            ->assertJsonPath('data.0.applied_to.0.invoice_id', $debt->invoice_id)
            ->assertJsonPath('data.0.created_by', $this->owner->name);

        $this->actingAs($this->owner, 'sanctum')->getJson("/api/v1/payments?invoice_id={$debt->invoice_id}")
            ->assertOk()->assertJsonCount(1, 'data')->assertJsonPath('data.0.total_amount', '15.00');
    }

    /** TC-0302-01/02/04: chronological statement with running balance; summary = statement. */
    public function test_statement_running_balance_matches_summary(): void
    {
        $customer = $this->makeCustomer($this->store);
        $sales = app(SaleService::class);
        $nuts = $this->makeProduct($this->store, ['selling_price' => '20.00']);

        $tick = fn() => CarbonImmutable::setTestNow(CarbonImmutable::now()->addMinutes(5));

        $credit = $sales->create($this->owner, ['customer_id' => $customer->id, 'items' => [['product_id' => $nuts->id, 'quantity' => 5]], 'paid_amount' => '0'])['invoice'];
        $tick();
        $voided = $sales->create($this->owner, ['customer_id' => $customer->id, 'items' => [['product_id' => $nuts->id, 'quantity' => 1]], 'paid_amount' => '0'])['invoice'];
        $sales->void($this->owner, $voided, 'Mistake');
        $tick();
        $payment = $this->pay($credit->debt()->first(), '30.00');
        $tick();
        $this->actingAs($this->owner, 'sanctum')->postJson("/api/v1/payments/{$payment->id}/reverse", ['reason' => 'Twice'], $this->idem())->assertOk();
        $tick();
        $this->pay($credit->debt()->first(), '25.00');
        $tick();
        app(ReturnService::class)->create($this->owner, $credit, [['invoice_item_id' => $credit->items[0]->id, 'quantity' => 1]], 'Damaged');

        $statement = $this->actingAs($this->owner, 'sanctum')->getJson("/api/v1/customers/{$customer->id}/statement")->assertOk();
        $this->assertSame(
            ['sale', 'sale', 'payment', 'payment_reversal', 'payment', 'return'],
            array_column($statement->json('data.events'), 'type'),
        );
        $this->assertSame(['100.00', '100.00', '70.00', '100.00', '75.00', '55.00'], array_column($statement->json('data.events'), 'balance'));
        $this->assertTrue($statement->json('data.events.1.voided'));
        $this->assertSame('0.00', $statement->json('data.events.1.debit'));

        $this->actingAs($this->owner, 'sanctum')->getJson("/api/v1/customers/{$customer->id}/summary")
            ->assertOk()
            ->assertJsonPath('data.total_debt', '100.00')
            ->assertJsonPath('data.paid', '25.00')
            ->assertJsonPath('data.returned', '20.00')
            ->assertJsonPath('data.remaining', '55.00');
        $this->assertSame('55.00', $credit->debt()->first()->remaining_amount);
    }

    /** TC-0302-03: another store's customer is a 404. */
    public function test_statement_is_store_isolated(): void
    {
        $foreign = $this->makeCustomer($this->makeStore('Other'));

        $this->actingAs($this->owner, 'sanctum')->getJson("/api/v1/customers/{$foreign->id}/statement")->assertNotFound();
        $this->actingAs($this->owner, 'sanctum')->getJson("/api/v1/customers/{$foreign->id}/summary")->assertNotFound();
    }

    /** TC-0301-03: deactivated customers leave the picker and new sales, but stay payable. */
    public function test_inactive_customer_is_hidden_from_sales_but_payable(): void
    {
        $customer = $this->makeCustomer($this->store);
        $debt = $this->debt($customer, '30.00');
        $employee = $this->makeUser($this->store, 'employee');

        $this->actingAs($employee, 'sanctum')->postJson("/api/v1/customers/{$customer->id}/deactivate")->assertForbidden();
        $this->app['auth']->forgetGuards();
        $this->actingAs($this->owner, 'sanctum')->postJson("/api/v1/customers/{$customer->id}/deactivate")
            ->assertOk()->assertJsonPath('data.status', Customer::STATUS_INACTIVE);
        $this->assertDatabaseHas('audit_logs', ['action' => 'customer.deactivated', 'entity_id' => (string) $customer->id]);

        $this->actingAs($this->owner, 'sanctum')->getJson('/api/v1/customers')->assertJsonCount(0, 'data');
        $this->actingAs($this->owner, 'sanctum')->getJson('/api/v1/customers?status=all')
            ->assertJsonCount(1, 'data')->assertJsonPath('data.0.balance', '30.00');

        $this->actingAs($this->owner, 'sanctum')->postJson('/api/v1/sales', [
            'customer_id' => $customer->id,
            'items' => [['product_id' => $this->makeProduct($this->store)->id, 'quantity' => 1]],
            'paid_amount' => '0',
        ], $this->idem())->assertStatus(422)->assertJsonValidationErrors('customer_id');

        $this->pay($debt, '10.00');
        $this->assertSame('20.00', $debt->fresh()->remaining_amount);

        $this->actingAs($this->owner, 'sanctum')->postJson("/api/v1/customers/{$customer->id}/reactivate")
            ->assertOk()->assertJsonPath('data.status', Customer::STATUS_ACTIVE);
    }

    private function debt(Customer $customer, string $amount, ?string $due = null): Debt
    {
        $debt = $this->makeCreditInvoice($this->store, $customer, $amount)->debt;
        $debt->update(['due_date' => $due]);

        return $debt->fresh();
    }

    private function pay(Debt $debt, string $amount): Payment
    {
        $id = $this->actingAs($this->owner, 'sanctum')
            ->postJson('/api/v1/payments', ['debt_id' => $debt->id, 'amount' => $amount, 'method' => 'cash'], $this->idem())
            ->assertCreated()
            ->json('data.id');
        $this->app['auth']->forgetGuards();

        return Payment::findOrFail($id);
    }

    private function listDebts(string $bucket)
    {
        return $this->actingAs($this->owner, 'sanctum')->getJson("/api/v1/debts?bucket={$bucket}");
    }
}
