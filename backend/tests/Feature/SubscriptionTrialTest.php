<?php

namespace Tests\Feature;

use App\Models\Customer;
use App\Models\Product;
use App\Models\Store;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Routing\Route as RouteDefinition;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Route;
use Tests\Support\BuildsShopData;
use Tests\TestCase;

/**
 * Seven-day trial and subscription enforcement: the trial runs from registration, business routes
 * need a running trial or a valid paid subscription (403 SUBSCRIPTION_EXPIRED), sign-in and the
 * renewal endpoints stay open, data is kept, and suspension is a separate, stronger state.
 */
class SubscriptionTrialTest extends TestCase
{
    use BuildsShopData;
    use RefreshDatabase;

    private const REGISTRATION = [
        'store_name' => 'بقالة التجربة',
        'owner_name' => 'صاحب المتجر',
        'phone' => '0599123456',
        'owner_phone' => '0599000051',
        'address' => 'شارع عمر المختار، غزة',
        'email' => 'trial@example.com',
        'password' => 'Password123',
        'password_confirmation' => 'Password123',
    ];

    protected function setUp(): void
    {
        parent::setUp();
        config(['hisbah.support_whatsapp' => '970599000000', 'hisbah.trial_days' => 7]);
    }

    private function expiredStore(string $name = 'Shop'): Store
    {
        $store = $this->makeStore($name);
        $store->forceFill(['trial_ends_at' => now()->subMinute()])->save();

        return $store->fresh();
    }

    // ---------------------------------------------------------------- trial start

    public function test_registration_starts_a_seven_day_trial_from_the_registration_time(): void
    {
        Carbon::setTestNow('2026-10-25 09:30:15');

        $response = $this->postJson('/api/v1/register', self::REGISTRATION)
            ->assertCreated()
            ->assertJsonPath('user.store.subscription_state', 'trial')
            ->assertJsonPath('user.store.has_access', true);

        $store = Store::sole();
        $this->assertSame('2026-10-25 09:30:15', $store->created_at->format('Y-m-d H:i:s'));
        $this->assertSame('2026-11-01 09:30:15', $store->trial_ends_at->format('Y-m-d H:i:s'));
        $this->assertSame('inactive', $store->subscription_status, 'A trial is not a paid subscription.');
        $this->assertNotNull($response->json('user.store.trial_ends_at'));
    }

    public function test_every_way_a_store_is_created_gets_the_trial_and_the_length_is_configurable(): void
    {
        config(['hisbah.trial_days' => 3]);
        Carbon::setTestNow('2026-10-25 12:00:00');

        $store = Store::create(['name' => 'Direct']);

        $this->assertSame('2026-10-28 12:00:00', $store->fresh()->trial_ends_at->format('Y-m-d H:i:s'));
    }

    // ---------------------------------------------------------------- boundaries

    public function test_access_holds_until_the_last_second_of_the_trial_and_stops_exactly_at_its_end(): void
    {
        $store = $this->makeStore('Shop');
        $owner = $this->makeUser($store, 'owner');
        $end = $store->fresh()->trial_ends_at;

        $this->travelTo($end->copy()->subSecond());
        $this->actingAs($owner->fresh(), 'sanctum')->getJson('/api/v1/dashboard')->assertOk();

        $this->travelTo($end);
        $this->actingAs($owner->fresh(), 'sanctum')->getJson('/api/v1/dashboard')
            ->assertForbidden()
            ->assertJsonPath('code', 'SUBSCRIPTION_EXPIRED')
            ->assertJsonPath('details.state', 'inactive')
            ->assertJsonPath('details.has_access', false)
            ->assertJsonPath('details.support_whatsapp', '970599000000');

        $this->travelTo($end->copy()->addDays(30));
        $this->actingAs($owner->fresh(), 'sanctum')->getJson('/api/v1/customers')->assertJsonPath('code', 'SUBSCRIPTION_EXPIRED');
    }

    public function test_trial_days_left_counts_down_and_reaches_zero(): void
    {
        $store = $this->makeStore('Shop');
        $owner = $this->makeUser($store, 'owner');

        $this->actingAs($owner, 'sanctum')->getJson('/api/v1/subscription')
            ->assertOk()
            ->assertJsonPath('data.state', 'trial')
            ->assertJsonPath('data.trial_days_left', 7);

        $this->travel(6)->days();
        $this->travel(1)->hours();
        $this->actingAs($owner->fresh(), 'sanctum')->getJson('/api/v1/subscription')->assertJsonPath('data.trial_days_left', 1);

        $this->travel(1)->days();
        $this->actingAs($owner->fresh(), 'sanctum')->getJson('/api/v1/subscription')
            ->assertJsonPath('data.trial_days_left', 0)
            ->assertJsonPath('data.has_access', false);
    }

    // ---------------------------------------------------------------- after expiry

    public function test_an_expired_store_can_sign_in_and_reach_only_the_session_routes(): void
    {
        $store = $this->expiredStore();
        $this->makeUser($store, 'owner', ['email' => 'owner@shop.ps']);

        $login = $this->postJson('/api/v1/login', ['login' => $this->phoneOf('owner@shop.ps'), 'password' => 'password'])
            ->assertOk()
            ->assertJsonPath('user.store.has_access', false)
            ->assertJsonPath('user.store.subscription_state', 'inactive');
        $token = $login->json('token');

        $this->withToken($token)->getJson('/api/v1/me')->assertOk()->assertJsonPath('user.store.has_access', false);
        $this->withToken($token)->getJson('/api/v1/subscription')
            ->assertOk()
            ->assertJsonPath('data.state', 'inactive')
            ->assertJsonPath('data.support_whatsapp', '970599000000');
        $this->withToken($token)->getJson('/api/v1/products')->assertForbidden()->assertJsonPath('code', 'SUBSCRIPTION_EXPIRED');
        $this->withToken($token)->postJson('/api/v1/logout')->assertOk();
    }

    /** Every route under `store` is behind `subscribed` except the three session routes. */
    public function test_every_business_route_is_behind_the_subscription_check(): void
    {
        $store = $this->expiredStore();
        $owner = $this->makeUser($store, 'owner');

        $storeRoutes = collect(Route::getRoutes()->getRoutes())
            ->filter(fn(RouteDefinition $r) => in_array('store', $r->gatherMiddleware(), true));
        $open = $storeRoutes->reject(fn(RouteDefinition $r) => in_array('subscribed', $r->gatherMiddleware(), true))
            ->map(fn(RouteDefinition $r) => implode('|', array_diff($r->methods(), ['HEAD'])) . ' ' . $r->uri())
            ->sort()->values()->all();

        // The account itself stays usable without a subscription: sign out, see why, change the password,
        // and reach technical support.
        $this->assertSame(['GET api/v1/me', 'GET api/v1/subscription', 'GET api/v1/support-tickets', 'PATCH api/v1/me/password', 'PATCH api/v1/me/phone', 'POST api/v1/logout', 'POST api/v1/support-tickets'], $open);
        $this->assertGreaterThan(40, $storeRoutes->count() - 7);

        // A sample of reads and writes, including idempotent financial writes.
        foreach ([['GET', '/dashboard'], ['GET', '/customers'], ['POST', '/customers'], ['GET', '/sales'], ['POST', '/sales'],
            ['GET', '/debts'], ['POST', '/payments'], ['GET', '/users'], ['GET', '/my-store'], ['PATCH', '/my-store'], ['POST', '/stock-adjustments']] as [$method, $uri]) {
            $this->actingAs($owner, 'sanctum')->json($method, '/api/v1' . $uri, ['name' => 'x'], $this->idem())
                ->assertForbidden()
                ->assertJsonPath('code', 'SUBSCRIPTION_EXPIRED');
        }
    }

    public function test_staff_of_an_expired_store_are_blocked_too(): void
    {
        $store = $this->expiredStore();
        foreach (['manager', 'employee'] as $role) {
            $this->actingAs($this->makeUser($store, $role), 'sanctum')->getJson('/api/v1/sales')->assertJsonPath('code', 'SUBSCRIPTION_EXPIRED');
        }
    }

    public function test_data_is_kept_after_expiry_and_back_when_the_admin_activates_the_subscription(): void
    {
        $store = $this->makeStore('Shop');
        $owner = $this->makeUser($store, 'owner');
        $customer = $this->makeCustomer($store);
        $invoice = $this->makeCreditInvoice($store, $customer, '75.00');
        $product = $this->makeProduct($store, ['name' => 'Tea', 'selling_price' => '12.00']);

        $this->travelTo($store->fresh()->trial_ends_at->copy()->addDay());
        $this->actingAs($owner->fresh(), 'sanctum')->getJson('/api/v1/customers')->assertForbidden();
        $this->assertTrue(Customer::whereKey($customer->id)->exists());
        $this->assertSame('12.00', Product::find($product->id)->selling_price);
        $this->assertSame('75.00', $invoice->debt->fresh()->remaining_amount);

        $admin = $this->makeUser($this->makeStore('HQ'), 'owner');
        $admin->forceFill(['is_platform_admin' => true])->save();
        $this->actingAs($admin, 'sanctum')
            ->postJson("/api/v1/admin/stores/{$store->id}/subscription", ['status' => 'active', 'expires_at' => now()->addMonth()->toDateString()])
            ->assertOk()
            ->assertJsonPath('data.subscription.state', 'active')
            ->assertJsonPath('data.subscription.has_access', true);

        $this->actingAs($owner->fresh(), 'sanctum')->getJson('/api/v1/customers')->assertOk()->assertJsonPath('data.0.id', $customer->id);
        $this->actingAs($owner->fresh(), 'sanctum')->getJson("/api/v1/products/{$product->id}")->assertOk()->assertJsonPath('data.selling_price', '12.00');
    }

    public function test_a_paid_subscription_that_passes_its_expiry_blocks_again_with_its_own_message(): void
    {
        $store = $this->expiredStore();
        $owner = $this->makeUser($store, 'owner');
        $store->forceFill(['subscription_status' => 'active', 'subscription_expires_at' => now()->addDay()])->save();

        $this->actingAs($owner->fresh(), 'sanctum')->getJson('/api/v1/dashboard')->assertOk();

        $this->travel(2)->days();
        $response = $this->actingAs($owner->fresh(), 'sanctum')->getJson('/api/v1/dashboard')
            ->assertForbidden()
            ->assertJsonPath('code', 'SUBSCRIPTION_EXPIRED')
            ->assertJsonPath('details.state', 'expired');
        $this->assertStringContainsString('انتهى اشتراك متجرك', $response->json('message'));
    }

    public function test_admin_deactivating_a_subscription_after_the_trial_removes_access(): void
    {
        $store = $this->expiredStore();
        $owner = $this->makeUser($store, 'owner');
        $store->forceFill(['subscription_status' => 'active'])->save();
        $this->actingAs($owner->fresh(), 'sanctum')->getJson('/api/v1/dashboard')->assertOk();

        $admin = $this->makeUser($this->makeStore('HQ'), 'owner');
        $admin->forceFill(['is_platform_admin' => true])->save();
        $this->actingAs($admin, 'sanctum')->postJson("/api/v1/admin/stores/{$store->id}/subscription", ['status' => 'inactive'])->assertOk();

        $this->actingAs($owner->fresh(), 'sanctum')->getJson('/api/v1/dashboard')->assertJsonPath('code', 'SUBSCRIPTION_EXPIRED');
    }

    // ---------------------------------------------------------------- suspension stays separate

    public function test_suspension_wins_over_both_an_expired_trial_and_a_paid_subscription(): void
    {
        $expired = $this->expiredStore('Expired');
        $this->makeUser($expired, 'owner', ['email' => 'expired@shop.ps']);
        $expired->forceFill(['status' => 'suspended'])->save();

        $this->postJson('/api/v1/login', ['login' => $this->phoneOf('expired@shop.ps'), 'password' => 'password'])
            ->assertForbidden()->assertJsonPath('code', 'STORE_SUSPENDED');

        $paid = $this->makeStore('Paid');
        $owner = $this->makeUser($paid, 'owner');
        $paid->forceFill(['subscription_status' => 'active', 'status' => 'suspended'])->save();

        $this->actingAs($owner->fresh(), 'sanctum')->getJson('/api/v1/dashboard')->assertJsonPath('code', 'STORE_SUSPENDED');
        $this->actingAs($owner->fresh(), 'sanctum')->getJson('/api/v1/subscription')->assertJsonPath('code', 'STORE_SUSPENDED');
    }

    public function test_activating_the_subscription_of_a_suspended_store_does_not_reopen_it(): void
    {
        $store = $this->expiredStore();
        $owner = $this->makeUser($store, 'owner');
        $store->forceFill(['status' => 'suspended'])->save();

        $admin = $this->makeUser($this->makeStore('HQ'), 'owner');
        $admin->forceFill(['is_platform_admin' => true])->save();
        $this->actingAs($admin, 'sanctum')->postJson("/api/v1/admin/stores/{$store->id}/subscription", ['status' => 'active'])->assertOk();

        $this->actingAs($owner->fresh(), 'sanctum')->getJson('/api/v1/dashboard')->assertJsonPath('code', 'STORE_SUSPENDED');

        $this->actingAs($admin, 'sanctum')->postJson("/api/v1/admin/stores/{$store->id}/status", ['status' => 'active'])->assertOk();
        $this->actingAs($owner->fresh(), 'sanctum')->getJson('/api/v1/dashboard')->assertOk();
    }

    // ---------------------------------------------------------------- unauthorized access

    public function test_guests_get_401_on_the_subscription_and_business_routes(): void
    {
        $this->getJson('/api/v1/subscription')->assertUnauthorized();
        $this->getJson('/api/v1/dashboard')->assertUnauthorized();
    }

    public function test_store_clients_cannot_change_their_own_trial_or_subscription(): void
    {
        $store = $this->makeStore('Shop');
        $owner = $this->makeUser($store, 'owner');
        $before = $store->fresh()->trial_ends_at;

        $this->actingAs($owner, 'sanctum')->patchJson('/api/v1/my-store', [
            'timezone' => 'Asia/Gaza',
            'trial_ends_at' => '2099-01-01 00:00:00',
            'subscription_status' => 'active',
        ])->assertOk();

        $store->refresh();
        $this->assertTrue($store->trial_ends_at->equalTo($before));
        $this->assertSame('inactive', $store->subscription_status);
        $this->actingAs($owner, 'sanctum')->postJson("/api/v1/admin/stores/{$store->id}/subscription", ['status' => 'active'])->assertForbidden();
    }

    public function test_the_platform_admin_keeps_the_admin_routes_when_their_own_store_expires(): void
    {
        $hq = $this->expiredStore('HQ');
        /** @var User $admin */
        $admin = $this->makeUser($hq, 'owner');
        $admin->forceFill(['is_platform_admin' => true])->save();

        $this->actingAs($admin, 'sanctum')->getJson('/api/v1/admin/overview')->assertOk()->assertJsonPath('data.subscriptions.inactive', 1);
        $this->actingAs($admin, 'sanctum')->getJson('/api/v1/dashboard')->assertJsonPath('code', 'SUBSCRIPTION_EXPIRED');
    }
}
