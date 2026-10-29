<?php

namespace Tests\Feature;

use App\Models\Store;
use App\Models\User;
use App\Services\SaleService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Support\BuildsShopData;
use Tests\TestCase;

/**
 * API details the S2 screens read: M-05 customer search with balances, the M-06 seller, and the
 * W-05 dashboard split (collected at the till vs. new debt) with hourly buckets for today.
 */
class PosSupportTest extends TestCase
{
    use BuildsShopData;
    use RefreshDatabase;

    private Store $store;
    private User $owner;

    protected function setUp(): void
    {
        parent::setUp();
        $this->store = $this->makeStore();
        $this->owner = $this->makeUser($this->store, 'owner', ['name' => 'Ali Ahmad']);
    }

    public function test_customer_search_by_name_or_phone_returns_balances(): void
    {
        $abu = $this->makeCustomer($this->store, '0599123456');
        $abu->update(['name' => 'Abu Mohammad', 'credit_limit' => '300.00']);
        $other = $this->makeCustomer($this->store, '0598000000');
        $other->update(['name' => 'Umm Sami']);
        $this->makeCreditInvoice($this->store, $abu, '120.00');
        $foreign = $this->makeCustomer($this->makeStore('Other'), '0599123457');
        $foreign->update(['name' => 'Abu Mohammad']);

        $api = $this->actingAs($this->owner, 'sanctum');

        $api->getJson('/api/v1/customers?search=Abu')->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', $abu->id)
            ->assertJsonPath('data.0.balance', '120.00')
            ->assertJsonPath('data.0.credit_limit', '300.00');
        $api->getJson('/api/v1/customers?search=0599 123')->assertOk()->assertJsonPath('data.0.id', $abu->id);
        $api->getJson('/api/v1/customers?search=Sami')->assertOk()->assertJsonPath('data.0.balance', '0.00');
    }

    public function test_sale_response_names_the_seller(): void
    {
        $this->actingAs($this->owner, 'sanctum')->postJson('/api/v1/sales', [
            'items' => [['product_id' => $this->makeProduct($this->store)->id, 'quantity' => 1]],
            'paid_amount' => '10.00',
            'payment_method' => 'cash',
        ], $this->idem())->assertCreated()
            ->assertJsonPath('data.seller.id', $this->owner->id)
            ->assertJsonPath('data.seller.name', 'Ali Ahmad');
    }

    public function test_dashboard_splits_collected_and_new_debt_and_buckets_today_by_hour(): void
    {
        $customer = $this->makeCustomer($this->store);
        app(SaleService::class)->create($this->owner, [
            'customer_id' => $customer->id,
            'items' => [['product_id' => $this->makeProduct($this->store, ['selling_price' => '15.00'])->id, 'quantity' => 3]],
            'paid_amount' => '20.00',
            'payment_method' => 'cash',
        ]);

        $response = $this->actingAs($this->owner, 'sanctum')->getJson('/api/v1/dashboard?period=today')->assertOk()
            ->assertJsonPath('data.summary.total_sales', '45.00')
            ->assertJsonPath('data.summary.collected_at_sale', '20.00')
            ->assertJsonPath('data.summary.new_debt', '25.00')
            ->assertJsonCount(24, 'data.charts.sales_hourly');

        $hourly = collect($response->json('data.charts.sales_hourly'));
        $this->assertSame('45.00', $hourly->firstWhere('amount', '!=', '0.00')['amount']);

        $this->actingAs($this->owner, 'sanctum')->getJson('/api/v1/dashboard?period=this_week')->assertOk()
            ->assertJsonPath('data.charts.sales_hourly', null);
    }

    public function test_register_returns_the_store(): void
    {
        $this->postJson('/api/v1/register', [
            'store_name' => 'Al-Noor Grocery',
            'owner_name' => 'Ali',
            'owner_phone' => '0599000021',
            'password' => 'password123',
            'password_confirmation' => 'password123',
        ])->assertCreated()->assertJsonPath('user.store.name', 'Al-Noor Grocery');
    }
}
