<?php

namespace Tests\Feature;

use App\Models\Customer;
use App\Models\Store;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Support\BuildsShopData;
use Tests\TestCase;

/**
 * Legacy debts from the mobile app (POST /debts): an old balance the shop had before Hisbah. It is
 * an obligation only: no sale in the totals, no stock movement, no payment or cash.
 */
class LegacyDebtTest extends TestCase
{
    use BuildsShopData;
    use RefreshDatabase;

    private Store $store;
    private User $owner;
    private Customer $customer;

    protected function setUp(): void
    {
        parent::setUp();
        $this->store = $this->makeStore();
        $this->owner = $this->makeUser($this->store);
        $this->customer = $this->makeCustomer($this->store);
    }

    private function postDebt(array $payload, ?User $as = null, ?string $key = null)
    {
        return $this->actingAs($as ?? $this->owner, 'sanctum')
            ->postJson('/api/v1/debts', ['customer_id' => $this->customer->id, ...$payload], $this->idem($key));
    }

    public function test_creates_a_legacy_debt_with_origin_date_and_note(): void
    {
        $origin = now()->subMonths(3)->toDateString();

        $this->postDebt(['amount' => '250.50', 'originated_on' => $origin, 'note' => 'دفتر الديون القديم'])
            ->assertCreated()
            ->assertJsonPath('data.source', 'opening_debt')
            ->assertJsonPath('data.notes', 'دفتر الديون القديم')
            ->assertJsonPath('data.debt.remaining_amount', '250.50');

        $this->assertDatabaseHas('debts', [
            'customer_id' => $this->customer->id,
            'remaining_amount' => '250.50',
            'originated_on' => $origin,
            'status' => 'unpaid',
        ]);

        $this->getJson("/api/v1/debts?customer_id={$this->customer->id}")
            ->assertOk()
            ->assertJsonPath('data.0.originated_on', $origin)
            ->assertJsonPath('data.0.note', 'دفتر الديون القديم')
            ->assertJsonPath('data.0.source', 'opening_debt');
    }

    public function test_balance_includes_the_legacy_debt_and_payments_reduce_it(): void
    {
        $this->makeCreditInvoice($this->store, $this->customer, '40.00');
        $this->postDebt(['amount' => '100.00'])->assertCreated();

        $this->getJson("/api/v1/customers/{$this->customer->id}/summary")
            ->assertOk()->assertJsonPath('data.remaining', '140.00');

        // A partial payment on the existing flow is applied oldest first, across both debts.
        $this->actingAs($this->owner, 'sanctum')
            ->postJson("/api/v1/customers/{$this->customer->id}/debts/pay-all", ['amount' => '60.00', 'method' => 'cash'], $this->idem())
            ->assertCreated();

        $this->getJson("/api/v1/customers/{$this->customer->id}/summary")
            ->assertOk()->assertJsonPath('data.remaining', '80.00');
        $this->assertEquals(60, \App\Models\Payment::sum('amount'));
    }

    public function test_no_sale_stock_movement_or_payment_is_created(): void
    {
        $product = $this->makeProduct($this->store);
        $movements = \App\Models\StockMovement::count();

        $this->postDebt(['amount' => '75.00'])->assertCreated();

        $this->assertSame($movements, \App\Models\StockMovement::count());
        $this->assertSame(0, \App\Models\Payment::count());
        $this->assertDatabaseMissing('invoices', ['source' => 'sale']);
        $this->assertDatabaseHas('invoices', ['source' => 'opening_debt', 'paid_amount' => 0, 'payment_method' => null]);
        $this->assertDatabaseMissing('invoice_items', ['product_id' => $product->id]);

        $this->getJson('/api/v1/dashboard?period=today')
            ->assertOk()
            ->assertJsonPath('data.summary.total_sales', '0.00')
            ->assertJsonPath('data.summary.collected_at_sale', '0.00')
            ->assertJsonPath('data.summary.total_remaining_debt', '75.00');

        $this->getJson('/api/v1/sales?source=sale')->assertOk()->assertJsonCount(0, 'data');
    }

    public function test_rejects_zero_negative_and_malformed_amounts(): void
    {
        foreach (['0', '-5', 'abc', '1.234', ''] as $amount) {
            $this->postDebt(['amount' => $amount])->assertUnprocessable()->assertJsonValidationErrors('amount');
        }
        $this->postDebt(['amount' => '10', 'originated_on' => now()->addDay()->toDateString()])
            ->assertUnprocessable()->assertJsonValidationErrors('originated_on');
        $this->postDebt(['amount' => '10', 'note' => str_repeat('x', 256)])
            ->assertUnprocessable()->assertJsonValidationErrors('note');
        $this->assertSame(0, \App\Models\Debt::count());
    }

    public function test_rejects_missing_other_store_and_unauthorised_requests(): void
    {
        $this->actingAs($this->owner, 'sanctum')
            ->postJson('/api/v1/debts', ['amount' => '10'], $this->idem())
            ->assertUnprocessable()->assertJsonValidationErrors('customer_id');

        $other = $this->makeCustomer($this->makeStore('Other'));
        $this->postDebt(['customer_id' => $other->id, 'amount' => '10'])
            ->assertUnprocessable()->assertJsonValidationErrors('customer_id');

        $employee = $this->makeUser($this->store, 'employee');
        $this->postDebt(['amount' => '10'], $employee)->assertForbidden();

        $this->app['auth']->forgetGuards();
        $this->postJson('/api/v1/debts', ['customer_id' => $this->customer->id, 'amount' => '10'], $this->idem())
            ->assertUnauthorized();
        $this->assertSame(0, \App\Models\Debt::count());
    }

    public function test_a_retried_submission_records_the_debt_once(): void
    {
        $key = (string) \Illuminate\Support\Str::uuid();
        $first = $this->postDebt(['amount' => '30.00'], key: $key)->assertCreated();
        $again = $this->postDebt(['amount' => '30.00'], key: $key)->assertCreated();

        $this->assertSame($first->json('data.id'), $again->json('data.id'));
        $this->assertSame(1, \App\Models\Debt::count());
    }

    public function test_older_clients_without_the_new_fields_still_work(): void
    {
        $this->postDebt(['amount' => '12.00', 'due_date' => now()->subDay()->toDateString()])->assertCreated();

        $debt = \App\Models\Debt::sole();
        $this->assertNull($debt->originated_on);
        $this->getJson("/api/v1/debts/{$debt->id}")->assertOk()->assertJsonPath('data.originated_on', null);
    }
}
