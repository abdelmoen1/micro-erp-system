<?php

namespace Tests\Feature;

use App\Models\Invoice;
use App\Models\Obligation;
use App\Models\Payment;
use App\Models\ReceivingAccount;
use App\Models\Store;
use App\Models\User;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Support\BuildsShopData;
use Tests\TestCase;

/**
 * 2026-11-28 requests from the shop: running costs («الالتزامات»), Home's net profit (sales past
 * the goods' cost, minus discounts, returns and the day's share of the running costs), and the
 * transfer account a debt repayment arrived on.
 */
class NetProfitObligationsTest extends TestCase
{
    use BuildsShopData;
    use RefreshDatabase;

    private Store $store;
    private User $owner;

    protected function setUp(): void
    {
        parent::setUp();
        // Mid-month and mid-day, so "today" and the month's days are fixed.
        $this->travelTo(CarbonImmutable::parse('2026-11-15 10:00:00', 'UTC'));
        $this->store = $this->makeStore();
        $this->owner = $this->makeUser($this->store);
    }

    private function as(User $user)
    {
        $this->app['auth']->forgetGuards();

        return $this->actingAs($user, 'sanctum');
    }

    private function sell(array $body): Invoice
    {
        $id = $this->as($this->owner)->postJson('/api/v1/sales', $body, $this->idem())->assertCreated()->json('data.id');

        return Invoice::with('items')->findOrFail($id);
    }

    private function profit(): array
    {
        return $this->as($this->owner)->getJson('/api/v1/dashboard?period=today')->assertOk()->json('data.profit');
    }

    // ------------------------------------------------------------ obligations

    public function test_the_owner_keeps_a_list_of_running_costs(): void
    {
        $this->as($this->owner)->postJson('/api/v1/obligations', ['name' => ' إيجار المحل ', 'amount' => '900', 'frequency' => 'monthly'])
            ->assertCreated()
            ->assertJsonPath('data.name', 'إيجار المحل')
            ->assertJsonPath('data.amount', '900.00')
            ->assertJsonPath('data.frequency', 'monthly')
            ->assertJsonPath('data.active', true);

        $id = Obligation::firstOrFail()->id;
        $this->as($this->owner)->patchJson("/api/v1/obligations/{$id}", ['amount' => '1200.50', 'active' => false])
            ->assertOk()->assertJsonPath('data.amount', '1200.50')->assertJsonPath('data.active', false);

        $this->as($this->owner)->getJson('/api/v1/obligations')->assertOk()->assertJsonCount(1, 'data');

        $this->as($this->owner)->deleteJson("/api/v1/obligations/{$id}")->assertOk();
        $this->as($this->owner)->getJson('/api/v1/obligations')->assertOk()->assertJsonCount(0, 'data');
        $this->assertSoftDeleted('obligations', ['id' => $id]);
    }

    public function test_obligations_are_checked_and_stay_with_owners_and_managers(): void
    {
        $this->as($this->owner)->postJson('/api/v1/obligations', ['name' => '', 'amount' => '-5', 'frequency' => 'hourly'])
            ->assertUnprocessable()->assertJsonValidationErrors(['name', 'amount', 'frequency']);

        $employee = $this->makeUser($this->store, 'employee');
        $this->as($employee)->getJson('/api/v1/obligations')->assertForbidden();
        $this->as($employee)->postJson('/api/v1/obligations', ['name' => 'x', 'amount' => '5', 'frequency' => 'daily'])->assertForbidden();

        $this->as($this->makeUser($this->store, 'manager'))->getJson('/api/v1/obligations')->assertOk();

        // Another store's obligation is not there at all.
        $other = Obligation::create(['store_id' => $this->makeStore('Other')->id, 'name' => 'x', 'amount' => '5', 'frequency' => 'daily']);
        $this->as($this->owner)->patchJson("/api/v1/obligations/{$other->id}", ['amount' => '6'])->assertNotFound();
    }

    // ------------------------------------------------------------ net profit

    public function test_net_profit_is_sales_past_cost_minus_discounts_returns_and_the_days_costs(): void
    {
        $oil = $this->makeProduct($this->store, ['selling_price' => '18.00', 'cost_price' => '12.00', 'current_stock' => 20]);
        $cola = $this->makeProduct($this->store, [
            'selling_price' => '3.50', 'cost_price' => '2.50', 'pack_size' => 24, 'pack_price' => '80.00', 'current_stock' => 100,
        ]);
        $noCost = $this->makeProduct($this->store, ['selling_price' => '5.00', 'current_stock' => 10]);

        // 3 × oil (54 − 36 = 18) + 1 carton of cola (80 − 24 × 2.50 = 20), 2.00 discount.
        $sale = $this->sell([
            'items' => [
                ['product_id' => $oil->id, 'quantity' => 3],
                ['product_id' => $cola->id, 'quantity' => 1, 'sale_unit' => 'pack'],
            ],
            'discount_amount' => '2.00',
            'paid_amount' => '132.00',
            'payment_method' => 'cash',
        ]);
        // Its cost is unknown: left out and counted.
        $this->sell(['items' => [['product_id' => $noCost->id, 'quantity' => 1]], 'paid_amount' => '5.00', 'payment_method' => 'cash']);

        // A later delivery at a new cost never rewrites today's profit.
        $oil->update(['cost_price' => '16.00']);

        // One oil comes back to the shelf: its 6.00 of profit is undone.
        $oilLine = $sale->items->firstWhere('product_id', $oil->id);
        $this->as($this->owner)->postJson("/api/v1/sales/{$sale->id}/returns", [
            'items' => [['invoice_item_id' => $oilLine->id, 'quantity' => 1]],
            'reason' => 'غيّر رأيه',
        ], $this->idem())->assertCreated();

        // November has 30 days: 900 / 30 = 30.00 a day, plus 70 a week = 10.00 a day.
        Obligation::create(['store_id' => $this->store->id, 'name' => 'إيجار', 'amount' => '900', 'frequency' => 'monthly']);
        Obligation::create(['store_id' => $this->store->id, 'name' => 'رواتب', 'amount' => '70', 'frequency' => 'weekly']);
        Obligation::create(['store_id' => $this->store->id, 'name' => 'متوقف', 'amount' => '999', 'frequency' => 'daily', 'active' => false]);

        $profit = $this->profit();

        $this->assertSame('38.00', $profit['sales_profit']);
        $this->assertSame('2.00', $profit['discounts']);
        $this->assertSame('6.00', $profit['returns_profit']);
        $this->assertSame('40.00', $profit['obligations']);
        $this->assertSame('-10.00', $profit['net']); // 38 − 2 − 6 − 40
        $this->assertSame(1, $profit['uncosted_lines']);
    }

    public function test_a_damaged_return_loses_the_whole_refund_and_a_voided_sale_earns_nothing(): void
    {
        $tea = $this->makeProduct($this->store, ['selling_price' => '6.50', 'cost_price' => '4.00', 'current_stock' => 20]);

        $kept = $this->sell(['items' => [['product_id' => $tea->id, 'quantity' => 2]], 'paid_amount' => '13.00', 'payment_method' => 'cash']);
        $voided = $this->sell(['items' => [['product_id' => $tea->id, 'quantity' => 5]], 'paid_amount' => '32.50', 'payment_method' => 'cash']);
        $this->as($this->owner)->postJson("/api/v1/sales/{$voided->id}/void", ['reason' => 'خطأ'], $this->idem())->assertOk();

        $this->as($this->owner)->postJson("/api/v1/sales/{$kept->id}/returns", [
            'items' => [['invoice_item_id' => $kept->items[0]->id, 'quantity' => 1, 'damaged' => true]],
            'reason' => 'علبة مفتوحة',
        ], $this->idem())->assertCreated();

        $profit = $this->profit();
        $this->assertSame('5.00', $profit['sales_profit']); // 13 − 8
        $this->assertSame('6.50', $profit['returns_profit']);
        $this->assertSame('-1.50', $profit['net']);
    }

    public function test_staff_phones_get_no_profit_figure(): void
    {
        $this->assertNull($this->as($this->makeUser($this->store, 'employee'))->getJson('/api/v1/dashboard?period=today')->assertOk()->json('data.profit'));
    }

    public function test_a_month_charges_only_the_days_that_have_passed(): void
    {
        Obligation::create(['store_id' => $this->store->id, 'name' => 'كهرباء', 'amount' => '300', 'frequency' => 'monthly']);

        $month = $this->as($this->owner)->getJson('/api/v1/dashboard?period=this_month')->assertOk()->json('data.profit');

        $this->assertSame('150.00', $month['obligations']); // 15 of November's 30 days
    }

    // ------------------------------------------------------------ repayment account

    public function test_a_transfer_repayment_keeps_the_account_it_arrived_on(): void
    {
        $customer = $this->makeCustomer($this->store);
        $this->makeCreditInvoice($this->store, $customer, '100.00');
        $account = ReceivingAccount::create([
            'store_id' => $this->store->id, 'provider' => 'palpay', 'account_name' => 'حساب المحل', 'account_identifier' => '0599000000',
        ]);

        $this->as($this->owner)->postJson("/api/v1/customers/{$customer->id}/debts/pay-all", [
            'method' => 'palpay', 'amount' => '40.00', 'receiving_account_id' => $account->id,
        ], $this->idem())->assertCreated();

        $payment = Payment::firstOrFail();
        $this->assertSame($account->id, $payment->receiving_account_id);
        $this->assertSame('حساب المحل', $payment->account_snapshot_name);
        $this->assertSame('0599000000', $payment->account_snapshot_identifier);
    }

    public function test_the_account_must_be_active_and_of_the_same_method(): void
    {
        $customer = $this->makeCustomer($this->store);
        $this->makeCreditInvoice($this->store, $customer, '100.00');
        $jawwal = ReceivingAccount::create([
            'store_id' => $this->store->id, 'provider' => 'jawwal_pay', 'account_name' => 'جوال', 'account_identifier' => '1',
        ]);

        $this->as($this->owner)->postJson("/api/v1/customers/{$customer->id}/debts/pay-all", [
            'method' => 'palpay', 'receiving_account_id' => $jawwal->id,
        ], $this->idem())->assertUnprocessable()->assertJsonValidationErrors(['receiving_account_id']);
        $this->assertDatabaseCount('payments', 0);

        // Cash never names an account; an old app that sends none still works.
        $this->as($this->owner)->postJson("/api/v1/customers/{$customer->id}/debts/pay-all", [
            'method' => 'cash', 'amount' => '10.00', 'receiving_account_id' => $jawwal->id,
        ], $this->idem())->assertCreated();
        $this->as($this->owner)->postJson("/api/v1/customers/{$customer->id}/debts/pay-all", [
            'method' => 'palpay', 'amount' => '10.00',
        ], $this->idem())->assertCreated();
        $this->assertSame(0, Payment::whereNotNull('receiving_account_id')->count());
    }
}
