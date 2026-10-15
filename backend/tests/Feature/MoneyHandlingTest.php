<?php

namespace Tests\Feature;

use App\Models\Payment;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\Support\BuildsShopData;
use Tests\TestCase;

/**
 * US-0102 — exact money handling (regression for DEF-03).
 */
class MoneyHandlingTest extends TestCase
{
    use BuildsShopData;
    use RefreshDatabase;

    /** TC-0102-01: three decimals are rejected and nothing is written. */
    public function test_more_than_two_decimals_is_rejected(): void
    {
        $store = $this->makeStore();
        $owner = $this->makeUser($store);
        $customer = $this->makeCustomer($store);
        $debt = $this->makeCreditInvoice($store, $customer)->debt;
        $api = $this->actingAs($owner, 'sanctum');

        $api->postJson('/api/v1/payments', ['debt_id' => $debt->id, 'amount' => 59.999, 'method' => 'cash'], $this->idem())
            ->assertUnprocessable()
            ->assertJsonPath('code', 'VALIDATION_FAILED')
            ->assertJsonValidationErrors('amount');
        $api->postJson('/api/v1/debts', ['customer_id' => $customer->id, 'amount' => '10.001'], $this->idem())
            ->assertUnprocessable();
        $api->postJson('/api/v1/invoices', [
            'customer_id' => $customer->id, 'has_debt' => true,
            'items' => [['item_name' => 'x', 'quantity' => 1, 'unit_price' => '1.999']],
        ], $this->idem())->assertUnprocessable();

        $this->assertSame(0, Payment::count());
        $this->assertDatabaseHas('debts', ['id' => $debt->id, 'remaining_amount' => '100.00']);
    }

    /** TC-0102-02: money is a 2-decimal string and responses carry meta.currency = ILS. */
    public function test_money_is_serialized_as_strings_with_currency(): void
    {
        $store = $this->makeStore();
        $owner = $this->makeUser($store);
        $customer = $this->makeCustomer($store);
        $api = $this->actingAs($owner, 'sanctum');

        $invoice = $api->postJson('/api/v1/invoices', [
            'customer_id' => $customer->id, 'has_debt' => true,
            'items' => [['item_name' => 'Rice', 'quantity' => 3, 'unit_price' => '4.10']],
        ], $this->idem())->assertCreated();

        $invoice->assertJsonPath('data.total_amount', '12.30')
            ->assertJsonPath('data.items.0.unit_price', '4.10')
            ->assertJsonPath('data.items.0.total', '12.30')
            ->assertJsonPath('data.debt.remaining_amount', '12.30')
            ->assertJsonPath('meta.currency', 'ILS');

        $api->getJson('/api/v1/debts')->assertOk()
            ->assertJsonPath('data.0.amount', '12.30')
            ->assertJsonPath('meta.currency', 'ILS')
            ->assertJsonStructure(['meta' => ['current_page', 'total', 'currency']]);

        $api->getJson('/api/v1/dashboard')->assertOk()
            ->assertJsonPath('data.debts.total_remaining', '12.30')
            ->assertJsonPath('meta.currency', 'ILS');
    }

    /** TC-0102-03: 0.10 + 0.20 settles a 0.30 debt exactly. */
    public function test_small_payments_settle_exactly(): void
    {
        $store = $this->makeStore();
        $owner = $this->makeUser($store);
        $debt = $this->makeCreditInvoice($store, $this->makeCustomer($store), '0.30')->debt;
        $api = $this->actingAs($owner, 'sanctum');

        $api->postJson('/api/v1/payments', ['debt_id' => $debt->id, 'amount' => '0.10', 'method' => 'cash'], $this->idem())
            ->assertCreated();
        $api->postJson('/api/v1/payments', ['debt_id' => $debt->id, 'amount' => 0.2, 'method' => 'cash'], $this->idem())
            ->assertCreated()
            ->assertJsonPath('data.amount', '0.20');

        $debt->refresh();
        $this->assertSame('0.00', $debt->remaining_amount);
        $this->assertSame('paid', $debt->status);

        $api->postJson('/api/v1/payments', ['debt_id' => $debt->id, 'amount' => '0.01', 'method' => 'cash'], $this->idem())
            ->assertUnprocessable()
            ->assertJsonPath('code', 'DEBT_ALREADY_PAID');
    }

    /** TC-0102-04: stored values equal the inputs exactly (strict on MySQL/MariaDB). */
    public function test_stored_values_equal_inputs_exactly(): void
    {
        $store = $this->makeStore();
        $owner = $this->makeUser($store);
        $debt = $this->makeCreditInvoice($store, $this->makeCustomer($store), '1000.00')->debt;
        $api = $this->actingAs($owner, 'sanctum');

        foreach (['0.10', '0.20', '333.33', '99.99'] as $amount) {
            $api->postJson('/api/v1/payments', ['debt_id' => $debt->id, 'amount' => $amount, 'method' => 'cash'], $this->idem())
                ->assertCreated();
        }

        $stored = DB::table('payments')->orderBy('id')->pluck('amount')->map(fn($v) => (string) $v)->all();
        $remaining = (string) DB::table('debts')->where('id', $debt->id)->value('remaining_amount');

        if (in_array(DB::connection()->getDriverName(), ['mysql', 'mariadb'], true)) {
            $this->assertSame(['0.10', '0.20', '333.33', '99.99'], $stored);
            $this->assertSame('566.38', $remaining);
        } else {
            // sqlite stores decimals as REAL; the API layer still returns exact strings.
            $this->assertEqualsWithDelta(566.38, (float) $remaining, 0.000001);
        }

        $this->assertSame('566.38', $debt->fresh()->remaining_amount);
    }
}
