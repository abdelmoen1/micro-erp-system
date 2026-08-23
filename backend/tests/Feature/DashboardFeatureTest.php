<?php

namespace Tests\Feature;

use App\Models\Customer;
use App\Models\Debt;
use App\Models\Invoice;
use App\Models\Payment;
use App\Models\Store;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class DashboardFeatureTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        Carbon::setTestNow(Carbon::parse('2026-08-23 12:00:00', 'UTC'));
    }

    protected function tearDown(): void
    {
        Carbon::setTestNow();
        parent::tearDown();
    }

    private function store(string $name): Store
    {
        return Store::create(['name' => $name]);
    }

    private function user(Store $store, string $role = 'owner'): User
    {
        return User::factory()->create([
            'store_id' => $store->id,
            'role' => $role,
            'password' => Hash::make('password'),
        ]);
    }

    private function customer(Store $store, string $phone): Customer
    {
        return Customer::create([
            'store_id' => $store->id,
            'name' => 'Customer ' . $phone,
            'phone' => $phone,
        ]);
    }

    private function invoice(
        Store $store,
        Customer $customer,
        float $total,
        bool $hasDebt,
        string $source = 'sale',
        string $createdAt = '2026-08-23 10:00:00',
    ): Invoice {
        $invoice = Invoice::create([
            'store_id' => $store->id,
            'customer_id' => $customer->id,
            'total_amount' => $total,
            'has_debt' => $hasDebt,
            'payment_method' => $hasDebt ? null : 'cash',
            'source' => $source,
            'created_at' => $createdAt,
            'updated_at' => $createdAt,
        ]);
        $invoice->forceFill([
            'created_at' => $createdAt,
            'updated_at' => $createdAt,
        ])->saveQuietly();

        $invoice->items()->create([
            'item_name' => 'Item',
            'quantity' => 1,
            'unit_price' => $total,
            'total' => $total,
        ]);

        if ($hasDebt) {
            Debt::create([
                'store_id' => $store->id,
                'invoice_id' => $invoice->id,
                'amount' => $total,
                'remaining_amount' => $total,
                'status' => 'unpaid',
            ]);
        }

        return $invoice->fresh('debt');
    }

    public function test_dashboard_requires_authentication_and_rejects_store_id(): void
    {
        $this->getJson('/api/dashboard')->assertUnauthorized();

        $store = $this->store('Main');
        $user = $this->user($store);

        $this->actingAs($user, 'sanctum')
            ->getJson('/api/dashboard?store_id=999')
            ->assertUnprocessable()
            ->assertJsonValidationErrors('store_id');
    }

    public function test_dashboard_is_available_to_all_roles_and_without_store_is_forbidden(): void
    {
        $store = $this->store('Main');

        foreach (['owner', 'manager', 'employee'] as $role) {
            $this->actingAs($this->user($store, $role), 'sanctum')
                ->getJson('/api/dashboard')
                ->assertOk();
        }

        $userWithoutStore = User::factory()->make(['store_id' => null]);
        $this->actingAs($userWithoutStore, 'sanctum')
            ->getJson('/api/dashboard')
            ->assertForbidden();
    }

    public function test_dashboard_calculates_metrics_with_store_isolation_and_reversed_payments(): void
    {
        $storeA = $this->store('A');
        $storeB = $this->store('B');
        $userA = $this->user($storeA);
        $customerA = $this->customer($storeA, '0590000001');
        $customerB = $this->customer($storeB, '0590000002');

        $cash = $this->invoice($storeA, $customerA, 100, false);
        $debtInvoice = $this->invoice($storeA, $customerA, 200, true);
        $openingDebt = $this->invoice($storeA, $customerA, 300, true, 'opening_debt');
        $outsidePeriod = $this->invoice($storeA, $customerA, 999, false, 'sale', '2026-07-31 10:00:00');
        $foreign = $this->invoice($storeB, $customerB, 500, false);

        $payment = $debtInvoice->debt->payments()->create([
            'amount' => 50,
            'method' => 'cash',
            'paid_at' => '2026-08-23 09:00:00',
            'created_at' => '2026-08-01 09:00:00',
            'updated_at' => '2026-08-01 09:00:00',
        ]);
        $debtInvoice->debt->update(['remaining_amount' => 150, 'status' => 'partially_paid']);
        $reversed = $debtInvoice->debt->payments()->create([
            'amount' => 25,
            'method' => 'cash',
            'paid_at' => '2026-08-23 08:00:00',
            'is_reversed' => true,
        ]);
        $foreign->debt?->payments()->create(['amount' => 700, 'paid_at' => '2026-08-23 07:00:00']);
        $this->assertNotNull($cash);
        $this->assertNotNull($openingDebt);
        $this->assertNotNull($outsidePeriod);
        $this->assertNotNull($payment);
        $this->assertNotNull($reversed);

        $response = $this->actingAs($userA, 'sanctum')->getJson('/api/dashboard?period=this_month');

        $response->assertOk()
            ->assertJsonPath('data.invoices.total', 3)
            ->assertJsonPath('data.invoices.cash', 1)
            ->assertJsonPath('data.invoices.debt', 2)
            ->assertJsonPath('data.invoices.total_value', 600)
            ->assertJsonPath('data.sales.total', 300)
            ->assertJsonPath('data.sales.cash', 100)
            ->assertJsonPath('data.sales.credit', 200)
            ->assertJsonPath('data.payments.total_collected', 50)
            ->assertJsonPath('data.payments.count', 1)
            ->assertJsonPath('data.debts.total_debt', 500)
            ->assertJsonPath('data.debts.total_remaining', 450)
            ->assertJsonPath('data.debts.partially_paid_count', 1)
            ->assertJsonPath('data.debts.unpaid_count', 1)
            ->assertJsonPath('data.customers.total', 1)
            ->assertJsonPath('data.customers.with_outstanding_debts', 1)
            ->assertJsonMissing(['id' => $foreign->id]);
    }

    public function test_dashboard_periods_charts_zero_buckets_and_recent_activity(): void
    {
        $store = $this->store('Main');
        $user = $this->user($store, 'employee');
        $customer = $this->customer($store, '0590000003');
        $this->invoice($store, $customer, 100, false, 'sale', '2026-08-20 10:00:00');
        $debtInvoice = $this->invoice($store, $customer, 200, true, 'sale', '2026-08-22 10:00:00');
        $payment = $debtInvoice->debt->payments()->create([
            'amount' => 75,
            'method' => 'cash',
            'paid_at' => '2026-08-20 09:00:00',
        ]);

        $daily = $this->actingAs($user, 'sanctum')->getJson('/api/dashboard?period=this_week');
        $daily->assertOk()
            ->assertJsonPath('data.period.key', 'this_week')
            ->assertJsonPath('data.charts.sales.0.amount', 0)
            ->assertJsonPath('data.charts.sales.3.amount', 100)
            ->assertJsonPath('data.charts.payments.3.amount', 75)
            ->assertJsonPath('data.recent_invoices.0.id', $debtInvoice->id)
            ->assertJsonPath('data.recent_invoices.0.customer.id', $customer->id)
            ->assertJsonPath('data.recent_payments.0.id', $payment->id)
            ->assertJsonPath('data.recent_payments.0.status', 'active');

        $year = $this->actingAs($user, 'sanctum')->getJson('/api/dashboard?period=this_year');
        $year->assertOk()
            ->assertJsonPath('data.charts.sales.7.month', '2026-08')
            ->assertJsonPath('data.charts.sales.7.amount', 300)
            ->assertJsonPath('data.charts.payments.7.month', '2026-08')
            ->assertJsonPath('data.charts.payments.7.amount', 75);

        $this->actingAs($user, 'sanctum')
            ->getJson('/api/dashboard?period=invalid')
            ->assertUnprocessable()
            ->assertJsonValidationErrors('period');
    }
}
