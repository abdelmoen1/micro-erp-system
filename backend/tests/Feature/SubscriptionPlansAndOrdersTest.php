<?php

namespace Tests\Feature;

use App\Models\AdminAccessLog;
use App\Models\Store;
use App\Models\SubscriptionOrder;
use App\Models\SubscriptionPayment;
use App\Models\SubscriptionPlan;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use LogicException;
use Tests\Support\BuildsShopData;
use Tests\Support\HmacTestProvider;
use Tests\TestCase;

/** SUBSCRIPTION_ARCHITECTURE.md: trial, plans, entitlements, manual WhatsApp orders, admin confirmation, webhooks. */
class SubscriptionPlansAndOrdersTest extends TestCase
{
    use BuildsShopData;
    use RefreshDatabase;

    private function admin(): User
    {
        $admin = $this->makeUser($this->makeStore('Platform'), 'owner');
        $admin->forceFill(['is_platform_admin' => true])->save();

        return $admin;
    }

    private function pricedPlan(string $code = 'monthly', string $price = '50.00', array $extra = []): SubscriptionPlan
    {
        $plan = SubscriptionPlan::where('code', $code)->firstOrFail();
        $plan->fill(['price' => $price, 'currency' => 'ILS', 'is_active' => true] + $extra)->save();

        return $plan->fresh();
    }

    private function register(string $phone, string $store = 'متجر'): \Illuminate\Testing\TestResponse
    {
        return $this->postJson('/api/v1/register', [
            'store_name' => $store, 'owner_name' => 'Owner', 'owner_phone' => $phone,
            'password' => 'secret-pass-1', 'password_confirmation' => 'secret-pass-1',
        ]);
    }

    private function expiredStore(): Store
    {
        $store = $this->makeStore('Expired');
        $store->forceFill(['trial_ends_at' => now()->subDay()])->save();

        return $store;
    }

    public function test_a_new_store_gets_one_fourteen_day_trial_with_every_feature(): void
    {
        $token = $this->register('0599100100')->assertCreated()->json('token');
        $store = Store::latest('id')->first();

        $this->assertSame(14, (int) round($store->trial_started_at->diffInDays($store->trial_ends_at)));
        $this->withToken($token)->getJson('/api/v1/subscription')->assertOk()
            ->assertJsonPath('data.lifecycle', 'trial')
            ->assertJsonPath('data.has_access', true)
            ->assertJsonPath('data.days_left', 14)
            ->assertJsonPath('data.entitlements.features', array_keys(config('hisbah.features')));
    }

    public function test_deleting_and_recreating_with_the_same_number_gives_no_second_trial(): void
    {
        $this->register('0599100100')->assertCreated();
        $first = Store::latest('id')->first();
        app(\App\Services\StoreDeletionService::class)->delete($first, $this->admin());

        $token = $this->register('0599100100', 'متجر جديد')->assertCreated()->json('token');
        $this->withToken($token)->getJson('/api/v1/subscription')
            ->assertJsonPath('data.has_access', false)
            ->assertJsonPath('data.lifecycle', 'expired');
        // Another number still gets a trial.
        $this->app['auth']->forgetGuards();
        $this->withoutToken();
        $other = $this->register('0599200200', 'آخر');
        $other->assertCreated();
        $this->withToken($other->json('token'))->getJson('/api/v1/subscription')->assertJsonPath('data.has_access', true);
    }

    public function test_plans_start_unpriced_and_inactive_and_only_the_platform_admin_prices_them(): void
    {
        $owner = $this->makeUser($this->makeStore(), 'owner');
        $this->assertSame(['monthly', 'semiannual', 'annual'], SubscriptionPlan::ordered()->pluck('code')->all());
        $this->assertSame([1, 6, 12], SubscriptionPlan::ordered()->pluck('duration_months')->all());
        $this->actingAs($owner, 'sanctum')->getJson('/api/v1/subscription/plans')->assertOk()->assertJsonCount(0, 'data');

        $plan = SubscriptionPlan::where('code', 'monthly')->first();
        $this->actingAs($owner, 'sanctum')->patchJson("/api/v1/admin/subscription-plans/{$plan->id}", ['price' => 10])->assertForbidden();

        $admin = $this->admin();
        $this->actingAs($admin, 'sanctum')->patchJson("/api/v1/admin/subscription-plans/{$plan->id}", ['is_active' => true])
            ->assertUnprocessable();
        $this->actingAs($admin, 'sanctum')->patchJson("/api/v1/admin/subscription-plans/{$plan->id}", [
            'price' => '49.90', 'currency' => 'ILS', 'is_active' => true, 'limits' => ['max_employees' => 2, 'bogus' => 9],
        ])->assertOk()->assertJsonPath('data.price', '49.90');
        $this->assertSame(['max_employees' => 2], $plan->fresh()->limits);

        $this->actingAs($owner, 'sanctum')->getJson('/api/v1/subscription/plans')->assertOk()
            ->assertJsonCount(1, 'data')->assertJsonPath('data.0.currency', 'ILS')
            ->assertJsonPath('meta.online_providers', []);
    }

    public function test_whatsapp_request_creates_a_pending_order_and_never_activates(): void
    {
        config(['hisbah.whatsapp_business_number' => '970599000111']);
        $plan = $this->pricedPlan('semiannual', '250.00');
        $store = $this->expiredStore();
        $owner = $this->makeUser($store, 'owner');
        $employee = $this->makeUser($store, 'employee');

        $this->actingAs($employee, 'sanctum')->postJson('/api/v1/subscription/orders', ['plan_id' => $plan->id, 'channel' => 'manual_whatsapp'])
            ->assertForbidden();

        $response = $this->actingAs($owner, 'sanctum')->postJson('/api/v1/subscription/orders', ['plan_id' => $plan->id, 'channel' => 'manual_whatsapp'])
            ->assertCreated()
            ->assertJsonPath('data.status', 'pending_contact')
            ->assertJsonPath('data.amount', '250.00');
        $reference = $response->json('data.reference');
        $this->assertMatchesRegularExpression('/^HSB-[A-Z2-9]{10}$/', $reference);

        $url = urldecode($response->json('data.whatsapp_url'));
        $this->assertStringStartsWith('https://wa.me/970599000111?text=', $url);
        foreach ([$reference, 'Expired', 'نصف سنوي', '250.00 ILS', '6 أشهر'] as $part) {
            $this->assertStringContainsString($part, $url);
        }
        $this->assertStringNotContainsString($owner->phone, $url, 'no personal number in the message');

        // Asking again returns the same open order; nothing was activated.
        $this->actingAs($owner, 'sanctum')->postJson('/api/v1/subscription/orders', ['plan_id' => $plan->id, 'channel' => 'manual_whatsapp'])
            ->assertCreated()->assertJsonPath('data.reference', $reference);
        $this->assertFalse($store->fresh()->hasAccess());
        $this->assertSame(1, SubscriptionOrder::count());

        // The price is the server's: a later price change does not alter the open order.
        $plan->update(['price' => '1.00']);
        $this->assertSame('250.00', SubscriptionOrder::first()->amount);
    }

    public function test_online_payment_is_unavailable_until_a_provider_is_configured(): void
    {
        $plan = $this->pricedPlan();
        $owner = $this->makeUser($this->makeStore(), 'owner');

        $this->actingAs($owner, 'sanctum')->postJson('/api/v1/subscription/orders', ['plan_id' => $plan->id, 'channel' => 'online', 'provider' => 'palpay'])
            ->assertStatus(503)->assertJsonPath('code', 'PAYMENT_PROVIDER_UNAVAILABLE');
        $this->postJson('/api/v1/payments/webhooks/palpay', ['reference' => 'x'])->assertNotFound();
        $this->assertSame(0, SubscriptionOrder::count());
    }

    public function test_admin_workflow_only_a_confirmed_matching_payment_activates_once(): void
    {
        $plan = $this->pricedPlan('monthly', '50.00');
        $store = $this->expiredStore();
        $owner = $this->makeUser($store, 'owner');
        $orderId = $this->actingAs($owner, 'sanctum')->postJson('/api/v1/subscription/orders', ['plan_id' => $plan->id, 'channel' => 'manual_whatsapp'])->json('data.id');
        $admin = $this->admin();
        $base = "/api/v1/admin/subscription-orders/{$orderId}";

        // Store members never reach the admin workflow.
        $this->actingAs($owner, 'sanctum')->postJson("{$base}/confirm-payment", [])->assertForbidden();

        $this->actingAs($admin, 'sanctum')->postJson("{$base}/status", ['status' => 'awaiting_payment', 'note' => 'contacted'])->assertOk()
            ->assertJsonPath('data.status', 'awaiting_payment');
        $this->actingAs($admin, 'sanctum')->postJson("{$base}/status", ['status' => 'paid'])->assertUnprocessable();
        $this->actingAs($admin, 'sanctum')->postJson("{$base}/notes", ['note' => 'receipt photo received, not verified'])->assertCreated();
        $this->assertFalse($store->fresh()->hasAccess(), 'notes and status moves never activate');

        $payment = ['amount' => '50.00', 'currency' => 'ILS', 'payment_method' => 'bank_transfer', 'transaction_reference' => 'TX-1', 'payment_verified' => true];
        $this->actingAs($admin, 'sanctum')->postJson("{$base}/confirm-payment", ['payment_verified' => false] + $payment)->assertUnprocessable();
        $this->actingAs($admin, 'sanctum')->postJson("{$base}/confirm-payment", ['amount' => '40.00'] + $payment)
            ->assertStatus(409)->assertJsonPath('code', 'PAYMENT_AMOUNT_MISMATCH');
        $this->assertFalse($store->fresh()->hasAccess());

        $this->travelTo(now()->startOfMinute());
        $this->actingAs($admin, 'sanctum')->postJson("{$base}/confirm-payment", $payment)->assertOk()
            ->assertJsonPath('data.status', 'paid')
            ->assertJsonPath('data.reviewed_by.id', $admin->id)
            ->assertJsonCount(1, 'data.payments');
        $store->refresh();
        $this->assertTrue($store->hasAccess());
        $this->assertSame($plan->id, $store->subscription_plan_id);
        $this->assertTrue($store->subscription_expires_at->equalTo(now()->addMonthNoOverflow()), 'expired store: from the activation date');

        $this->actingAs($admin, 'sanctum')->postJson("{$base}/confirm-payment", ['transaction_reference' => 'TX-2'] + $payment)
            ->assertStatus(409)->assertJsonPath('code', 'ORDER_ALREADY_ACTIVATED');
        $this->assertSame(1, SubscriptionPayment::count());

        $types = $this->actingAs($admin, 'sanctum')->getJson($base)->json('data.events.*.type');
        $this->assertSame(['created', 'status', 'note', 'payment', 'activated'], $types);
        $this->assertDatabaseHas('audit_logs', ['store_id' => $store->id, 'action' => 'store.subscription_activated']);
    }

    public function test_renewing_an_active_subscription_extends_from_its_expiry(): void
    {
        $plan = $this->pricedPlan('annual', '400.00');
        $store = $this->makeStore('Active');
        $expiry = now()->addDays(10)->startOfSecond();
        $store->forceFill(['subscription_status' => 'active', 'subscription_expires_at' => $expiry, 'trial_ends_at' => now()->subMonth()])->save();
        $owner = $this->makeUser($store, 'owner');
        $orderId = $this->actingAs($owner, 'sanctum')->postJson('/api/v1/subscription/orders', ['plan_id' => $plan->id, 'channel' => 'manual_whatsapp'])->json('data.id');

        $this->actingAs($this->admin(), 'sanctum')->postJson("/api/v1/admin/subscription-orders/{$orderId}/confirm-payment", [
            'amount' => '400.00', 'currency' => 'ils', 'payment_method' => 'cash', 'transaction_reference' => 'R-9', 'payment_verified' => true,
        ])->assertOk();

        $this->assertTrue($store->fresh()->subscription_expires_at->equalTo($expiry->copy()->addMonthsNoOverflow(12)));
        $this->assertSame('expiring', (new Store(['name' => 'x']))->forceFill(['trial_ends_at' => now()->addDays(2)])->lifecycle());
    }

    public function test_plan_features_and_limits_are_enforced_by_the_server(): void
    {
        $plan = $this->pricedPlan('monthly', '30.00', ['features' => ['staff'], 'limits' => ['max_employees' => 1, 'max_products' => 1]]);
        $store = $this->makeStore('Limited');
        $store->forceFill(['subscription_status' => 'active', 'subscription_expires_at' => now()->addMonth(), 'subscription_plan_id' => $plan->id, 'trial_ends_at' => now()->subDay()])->save();
        $owner = $this->makeUser($store, 'owner');

        $this->actingAs($owner, 'sanctum')->getJson('/api/v1/subscription')
            ->assertJsonPath('data.entitlements.features', ['staff'])
            ->assertJsonPath('data.entitlements.limits.max_employees', 1);
        $this->actingAs($owner, 'sanctum')->postJson('/api/v1/purchases', ['lines' => []], $this->idem())
            ->assertForbidden()->assertJsonPath('code', 'FEATURE_NOT_IN_PLAN')->assertJsonPath('details.feature', 'suppliers');
        $this->actingAs($owner, 'sanctum')->postJson('/api/v1/products/import', [])
            ->assertForbidden()->assertJsonPath('code', 'FEATURE_NOT_IN_PLAN');

        $this->actingAs($owner, 'sanctum')->postJson('/api/v1/invitations', ['role' => 'employee'])->assertCreated();
        $this->makeUser($store, 'employee');
        $this->actingAs($owner, 'sanctum')->postJson('/api/v1/invitations', ['role' => 'employee'])
            ->assertForbidden()->assertJsonPath('code', 'PLAN_LIMIT_REACHED');

        $this->makeProduct($store);
        $this->actingAs($owner, 'sanctum')->postJson('/api/v1/products', ['name' => 'Second', 'selling_price' => '5.00', 'current_stock' => 1])
            ->assertForbidden()->assertJsonPath('details.limit', 'max_products');
    }

    public function test_payment_and_history_rows_are_append_only(): void
    {
        $plan = $this->pricedPlan();
        $store = $this->expiredStore();
        $order = app(\App\Services\SubscriptionService::class)->createOrder($store, $this->makeUser($store, 'owner'), $plan, 'manual_whatsapp');
        app(\App\Services\SubscriptionService::class)->confirmManualPayment($order, $this->admin(), [
            'amount' => '50.00', 'currency' => 'ILS', 'payment_method' => 'cash', 'transaction_reference' => 'C-1',
        ]);

        $this->expectException(LogicException::class);
        SubscriptionPayment::first()->update(['amount' => '1.00']);
    }

    public function test_verified_provider_notifications_activate_once_and_forgeries_change_nothing(): void
    {
        config(['payments.providers.testpay' => ['label' => 'Test', 'enabled' => true, 'driver' => HmacTestProvider::class]]);
        $plan = $this->pricedPlan('monthly', '50.00');
        $store = $this->expiredStore();
        $owner = $this->makeUser($store, 'owner');
        $created = $this->actingAs($owner, 'sanctum')->postJson('/api/v1/subscription/orders', ['plan_id' => $plan->id, 'channel' => 'online', 'provider' => 'testpay'])
            ->assertCreated();
        $this->assertStringStartsWith('https://checkout.test.invalid/', $created->json('data.checkout_url'));
        $reference = $created->json('data.reference');
        $this->app['auth']->forgetGuards();

        $body = ['reference' => $reference, 'status' => 'paid', 'transaction_id' => 'T-1', 'amount' => '50.00', 'currency' => 'ILS'];
        [$json, $headers] = HmacTestProvider::sign($body);

        // Forged signature, then a wrong amount: nothing happens.
        $this->call('POST', '/api/v1/payments/webhooks/testpay', [], [], [], $this->server(['X-Test-Signature' => 'forged'] + $headers), $json)->assertStatus(400);
        [$bad, $badHeaders] = HmacTestProvider::sign(['amount' => '5.00'] + $body);
        $this->call('POST', '/api/v1/payments/webhooks/testpay', [], [], [], $this->server($badHeaders), $bad)->assertStatus(409);
        $this->assertFalse($store->fresh()->hasAccess());

        $this->call('POST', '/api/v1/payments/webhooks/testpay', [], [], [], $this->server($headers), $json)->assertOk()->assertJsonPath('result', 'activated');
        $this->call('POST', '/api/v1/payments/webhooks/testpay', [], [], [], $this->server($headers), $json)->assertOk()->assertJsonPath('result', 'duplicate');
        $this->assertTrue($store->fresh()->hasAccess());
        $this->assertSame(1, SubscriptionPayment::where('source', 'provider')->count());
    }

    public function test_expiry_notice_is_recorded_once_per_period(): void
    {
        $store = $this->makeStore('Soon');
        $store->forceFill(['trial_ends_at' => now()->addDays(2)])->save();
        $this->makeStore('Later');

        $this->artisan('hisbah:subscription-reminders')->assertSuccessful();
        $this->artisan('hisbah:subscription-reminders')->assertSuccessful();

        $this->assertSame(1, \App\Models\AuditLog::where('action', 'subscription.expiring_notice')->count());
        $this->assertSame($store->id, \App\Models\AuditLog::where('action', 'subscription.expiring_notice')->value('store_id'));
    }

    public function test_platform_admin_reads_of_store_data_are_logged(): void
    {
        $store = $this->makeStore('Watched');
        $this->makeProduct($store, ['cost_price' => '3.00']);
        $admin = $this->admin();

        $this->actingAs($admin, 'sanctum')->getJson("/api/v1/admin/stores/{$store->id}/products")->assertOk()
            ->assertJsonPath('data.0.cost_price', '3.00');
        $this->assertDatabaseHas('admin_access_logs', ['admin_id' => $admin->id, 'target_store_id' => $store->id, 'method' => 'GET']);

        // A store owner is refused before anything is logged as admin access.
        $this->actingAs($this->makeUser($store, 'owner'), 'sanctum')->getJson("/api/v1/admin/stores/{$store->id}/products")->assertForbidden();
        $this->assertSame(1, AdminAccessLog::count());
    }

    public function test_one_number_flooding_sign_up_does_not_block_other_shops_behind_the_same_proxy(): void
    {
        for ($i = 0; $i < 6; $i++) {
            $this->postJson('/api/v1/register', ['owner_phone' => '0599300300']);
        }
        $this->postJson('/api/v1/register', ['owner_phone' => '0599300300'])->assertStatus(429);

        $this->register('0599400400', 'Neighbour')->assertCreated();
    }

    private function server(array $headers): array
    {
        $server = [];
        foreach ($headers as $name => $value) {
            $key = strtoupper(str_replace('-', '_', $name));
            $server[in_array($key, ['CONTENT_TYPE', 'CONTENT_LENGTH'], true) ? $key : 'HTTP_' . $key] = $value;
        }

        return $server;
    }
}
