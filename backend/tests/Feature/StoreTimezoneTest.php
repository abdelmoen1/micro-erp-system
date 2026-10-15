<?php

namespace Tests\Feature;

use App\Models\Invoice;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Tests\Support\BuildsShopData;
use Tests\TestCase;

/**
 * US-0107 — business dates in the store timezone (regression for DEF-07; D-23 / CR-14).
 */
class StoreTimezoneTest extends TestCase
{
    use BuildsShopData;
    use RefreshDatabase;

    protected function tearDown(): void
    {
        Carbon::setTestNow();
        parent::tearDown();
    }

    private function cashSaleAt(int $storeId, int $customerId, string $utc, string $total): void
    {
        $invoice = Invoice::create([
            'store_id' => $storeId, 'customer_id' => $customerId, 'total_amount' => $total,
            'has_debt' => false, 'payment_method' => 'cash', 'source' => 'sale',
        ]);
        $invoice->forceFill(['created_at' => $utc, 'updated_at' => $utc])->saveQuietly();
    }

    /** TC-0107-01: a late-evening local sale counts for local "today". */
    public function test_late_evening_sale_is_counted_today(): void
    {
        // 2026-10-13 23:45 in Gaza (UTC+3 in October) = 20:45 UTC.
        Carbon::setTestNow(Carbon::parse('2026-10-13 20:50:00', 'UTC'));

        $store = $this->makeStore('Gaza shop', ['timezone' => 'Asia/Gaza']);
        $owner = $this->makeUser($store);
        $customer = $this->makeCustomer($store);

        $this->cashSaleAt($store->id, $customer->id, '2026-10-13 20:30:00', '40.00'); // 23:30 local, today
        $this->cashSaleAt($store->id, $customer->id, '2026-10-12 21:30:00', '99.00'); // 00:30 local on the 13th, today
        $this->cashSaleAt($store->id, $customer->id, '2026-10-12 20:30:00', '7.00');  // 23:30 local on the 12th, yesterday

        $this->actingAs($owner, 'sanctum')->getJson('/api/v1/dashboard?period=today')
            ->assertOk()
            ->assertJsonPath('data.period.timezone', 'Asia/Gaza')
            ->assertJsonPath('data.period.from', '2026-10-12T21:00:00.000000Z')
            ->assertJsonPath('data.invoices.total', 2)
            ->assertJsonPath('data.sales.total', '139.00');
    }

    /** TC-0107-02: week, month and year boundaries follow the store timezone; chart buckets use local dates. */
    public function test_period_boundaries_and_buckets_use_store_timezone(): void
    {
        Carbon::setTestNow(Carbon::parse('2026-10-14 09:00:00', 'UTC')); // Wednesday, 12:00 in Gaza

        $store = $this->makeStore('Gaza shop', ['timezone' => 'Asia/Gaza']);
        $owner = $this->makeUser($store);
        $customer = $this->makeCustomer($store);
        // Monday 00:30 local = Sunday 21:30 UTC: belongs to this week and to Monday's bucket.
        $this->cashSaleAt($store->id, $customer->id, '2026-10-11 21:30:00', '15.00');
        // 30 Sep 23:00 local = 20:00 UTC: September, not this month.
        $this->cashSaleAt($store->id, $customer->id, '2026-09-30 20:00:00', '500.00');

        $week = $this->actingAs($owner, 'sanctum')->getJson('/api/v1/dashboard?period=this_week')->assertOk();
        $week->assertJsonPath('data.period.from', '2026-10-11T21:00:00.000000Z')
            ->assertJsonPath('data.charts.sales.0.date', '2026-10-12')
            ->assertJsonPath('data.charts.sales.0.amount', '15.00')
            ->assertJsonPath('data.sales.total', '15.00');

        $this->actingAs($owner, 'sanctum')->getJson('/api/v1/dashboard?period=this_month')->assertOk()
            ->assertJsonPath('data.period.from', '2026-09-30T21:00:00.000000Z')
            ->assertJsonPath('data.sales.total', '15.00');

        $this->actingAs($owner, 'sanctum')->getJson('/api/v1/dashboard?period=this_year')->assertOk()
            ->assertJsonPath('data.period.from', '2025-12-31T22:00:00.000000Z')
            ->assertJsonPath('data.charts.sales.8.month', '2026-09')
            ->assertJsonPath('data.charts.sales.8.amount', '500.00')
            ->assertJsonPath('data.charts.sales.9.amount', '15.00');
    }

    public function test_new_stores_default_to_gaza_and_owner_can_change_timezone(): void
    {
        $registered = $this->postJson('/api/v1/register', [
            'store_name' => 'Shop', 'owner_name' => 'Owner', 'email' => 'o@example.com',
            'password' => 'password', 'password_confirmation' => 'password',
        ])->assertCreated();
        $this->assertSame('Asia/Gaza', $registered->json('user.store.timezone'));

        $this->withToken($registered->json('token'))
            ->patchJson('/api/v1/my-store', ['timezone' => 'Asia/Hebron'])
            ->assertOk()
            ->assertJsonPath('store.timezone', 'Asia/Hebron');
        $this->withToken($registered->json('token'))
            ->patchJson('/api/v1/my-store', ['timezone' => 'Mars/Olympus'])
            ->assertUnprocessable();
    }
}
