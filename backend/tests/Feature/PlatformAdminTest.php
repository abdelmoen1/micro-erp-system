<?php

namespace Tests\Feature;

use App\Models\AuditLog;
use App\Models\CatalogProduct;
use App\Models\Store;
use App\Models\StoreInvitation;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\Support\BuildsShopData;
use Tests\TestCase;

/**
 * Platform owner dashboard: who may reach /admin, store listing and details, account access vs.
 * subscription (two states that never overwrite each other), and per-store product isolation.
 */
class PlatformAdminTest extends TestCase
{
    use BuildsShopData;
    use RefreshDatabase;

    private function makeAdmin(?Store $store = null): User
    {
        $admin = $this->makeUser($store ?? $this->makeStore('Hisbah HQ'), 'owner');
        $admin->forceFill(['is_platform_admin' => true])->save();

        return $admin;
    }

    /** [method, uri] for every admin route, with ids that exist. */
    private function adminRoutes(Store $store, CatalogProduct $catalog): array
    {
        return [
            ['GET', '/api/v1/admin/overview'],
            ['GET', '/api/v1/admin/stores'],
            ['GET', "/api/v1/admin/stores/{$store->id}"],
            ['GET', "/api/v1/admin/stores/{$store->id}/products"],
            ['POST', "/api/v1/admin/stores/{$store->id}/status"],
            ['POST', "/api/v1/admin/stores/{$store->id}/subscription"],
            ['GET', '/api/v1/admin/products'],
            ['GET', "/api/v1/admin/catalog-products/{$catalog->id}"],
        ];
    }

    private function catalogItem(): CatalogProduct
    {
        // Outside the 729… range that makeProduct() generates.
        return CatalogProduct::create(['barcode' => '6291041500213', 'name' => 'Milk 1L', 'unit' => 'piece']);
    }

    // ---------------------------------------------------------------- authorization

    public static function storeRoles(): array
    {
        return ['owner' => ['owner'], 'manager' => ['manager'], 'employee' => ['employee']];
    }

    #[DataProvider('storeRoles')]
    public function test_store_members_cannot_reach_any_admin_route(string $role): void
    {
        $store = $this->makeStore('Shop');
        $member = $this->makeUser($store, $role);
        $catalog = $this->catalogItem();

        foreach ($this->adminRoutes($store, $catalog) as [$method, $uri]) {
            $this->actingAs($member, 'sanctum')
                ->json($method, $uri, ['status' => 'suspended'])
                ->assertForbidden()
                ->assertJsonPath('code', 'FORBIDDEN');
        }

        // Unknown ids answer the same 403, so ids cannot be probed.
        $this->actingAs($member, 'sanctum')->getJson('/api/v1/admin/stores/999999')->assertForbidden();

        $this->assertSame('active', $store->fresh()->status);
        $this->assertSame(0, AuditLog::count());
    }

    public function test_guests_get_401_on_admin_routes(): void
    {
        $store = $this->makeStore('Shop');

        foreach ($this->adminRoutes($store, $this->catalogItem()) as [$method, $uri]) {
            $this->json($method, $uri)->assertUnauthorized();
        }
    }

    public function test_platform_admin_reaches_every_admin_route(): void
    {
        $admin = $this->makeAdmin();
        $store = $this->makeStore('Shop');
        $this->makeUser($store, 'owner');

        foreach ($this->adminRoutes($store, $this->catalogItem()) as [$method, $uri]) {
            $body = str_ends_with($uri, '/status') ? ['status' => 'active'] : ['status' => 'inactive'];
            $this->actingAs($admin, 'sanctum')->json($method, $uri, $method === 'POST' ? $body : [])->assertOk();
        }
    }

    public function test_deactivated_platform_admin_is_refused(): void
    {
        $admin = $this->makeAdmin();
        $admin->forceFill(['status' => User::STATUS_INACTIVE])->save();

        $this->actingAs($admin, 'sanctum')->getJson('/api/v1/admin/overview')
            ->assertForbidden()
            ->assertJsonPath('code', 'USER_INACTIVE');
    }

    public function test_public_registration_cannot_grant_platform_admin(): void
    {
        $response = $this->postJson('/api/v1/register', [
            'store_name' => 'Sneaky',
            'owner_name' => 'Eve',
            'email' => 'eve@example.com',
            'password' => 'Password123',
            'password_confirmation' => 'Password123',
            'is_platform_admin' => true,
            'role' => 'admin',
            'status' => 'active',
            'subscription_status' => 'active',
        ])->assertCreated()->assertJsonPath('user.is_platform_admin', false);

        $user = User::where('email', 'eve@example.com')->firstOrFail();
        $this->assertFalse($user->isPlatformAdmin());
        $this->assertSame('inactive', $user->store->fresh()->subscription_status);

        $this->withToken($response->json('token'))->getJson('/api/v1/admin/overview')->assertForbidden();
    }

    public function test_store_owner_cannot_change_access_or_subscription_through_store_settings(): void
    {
        $store = $this->makeStore('Shop');
        $owner = $this->makeUser($store, 'owner');

        $this->actingAs($owner, 'sanctum')->patchJson('/api/v1/my-store', [
            'timezone' => 'Asia/Gaza',
            'status' => 'suspended',
            'subscription_status' => 'active',
            'subscription_expires_at' => '2099-01-01',
            'is_platform_admin' => true,
        ])->assertOk();

        $store->refresh();
        $this->assertSame('active', $store->status);
        $this->assertSame('inactive', $store->subscription_status);
        $this->assertNull($store->subscription_expires_at);
        $this->assertFalse($owner->fresh()->isPlatformAdmin());
    }

    // ---------------------------------------------------------------- listing and details

    public function test_overview_counts_stores_and_subscription_states(): void
    {
        $admin = $this->makeAdmin(); // its store is in its trial
        $this->makeStore('Suspended')->forceFill(['status' => 'suspended'])->save(); // trial
        $this->makeStore('Paid')->forceFill(['subscription_status' => 'active', 'subscription_expires_at' => now()->addMonth()])->save();
        $this->makeStore('Lapsed')->forceFill(['subscription_status' => 'active', 'subscription_expires_at' => now()->subDay(), 'trial_ends_at' => now()->subDays(2)])->save();
        $this->makeStore('Open-ended')->forceFill(['subscription_status' => 'active'])->save();
        $this->makeStore('Never paid')->forceFill(['trial_ends_at' => now()->subMinute()])->save();

        $this->actingAs($admin, 'sanctum')->getJson('/api/v1/admin/overview')
            ->assertOk()
            ->assertJsonPath('data.stores.total', 6)
            ->assertJsonPath('data.stores.active', 5)
            ->assertJsonPath('data.stores.suspended', 1)
            ->assertJsonPath('data.subscriptions.active', 2)
            ->assertJsonPath('data.subscriptions.trial', 2)
            ->assertJsonPath('data.subscriptions.expired', 1)
            ->assertJsonPath('data.subscriptions.inactive', 1);
    }

    public function test_store_list_searches_filters_and_paginates(): void
    {
        $admin = $this->makeAdmin();
        $bakery = $this->makeStore('Bakery Al-Amal', ['address' => 'Gaza, Rimal', 'phone' => '0599000001']);
        $bakery->forceFill(['created_at' => now()->subDays(12)])->save();
        $this->makeUser($bakery, 'owner', ['email' => 'baker@example.com', 'name' => 'Abu Samir']);
        $grocer = $this->makeStore('Grocer');
        $grocer->forceFill(['status' => 'suspended', 'subscription_status' => 'active', 'subscription_expires_at' => now()->subDay(), 'trial_ends_at' => now()->subDays(3)])->save();

        $as = $this->actingAs($admin, 'sanctum');

        $as->getJson('/api/v1/admin/stores?search=baker@example')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', $bakery->id)
            ->assertJsonPath('data.0.owner.email', 'baker@example.com')
            ->assertJsonPath('data.0.address', 'Gaza, Rimal')
            ->assertJsonPath('data.0.days_since_registration', 12)
            ->assertJsonPath('data.0.status', 'active')
            ->assertJsonPath('data.0.subscription.state', 'trial');

        $as->getJson('/api/v1/admin/stores?search=Rimal')->assertJsonPath('data.0.id', $bakery->id);

        $as->getJson('/api/v1/admin/stores?status=suspended')
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', $grocer->id);

        $as->getJson('/api/v1/admin/stores?subscription=expired')
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.subscription.state', 'expired');

        $as->getJson('/api/v1/admin/stores?per_page=1&sort=oldest')
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('meta.total', 3)
            ->assertJsonPath('meta.last_page', 3);

        $as->getJson('/api/v1/admin/stores?status=closed')->assertStatus(422);
    }

    public function test_store_details_show_owner_contact_members_and_counts(): void
    {
        $admin = $this->makeAdmin();
        $store = $this->makeStore('Shop', ['phone' => '0599111222', 'address' => 'Khan Younis']);
        $owner = $this->makeUser($store, 'owner', ['name' => 'Owner One', 'phone' => '0599333444']);
        $this->makeUser($store, 'employee');
        $this->makeProduct($store);
        $this->makeProduct($store, ['status' => 'inactive']);

        $this->actingAs($admin, 'sanctum')->getJson("/api/v1/admin/stores/{$store->id}")
            ->assertOk()
            ->assertJsonPath('data.name', 'Shop')
            ->assertJsonPath('data.phone', '0599111222')
            ->assertJsonPath('data.address', 'Khan Younis')
            ->assertJsonPath('data.owner.id', $owner->id)
            ->assertJsonPath('data.owner.phone', '0599333444')
            ->assertJsonPath('data.users_count', 2)
            ->assertJsonPath('data.products_count', 2)
            ->assertJsonPath('data.active_products_count', 1)
            ->assertJsonCount(2, 'data.members')
            ->assertJsonPath('data.subscription.state', 'trial')
            ->assertJsonPath('data.subscription.has_access', true)
            ->assertJsonMissingPath('data.members.0.password');

        $this->actingAs($admin, 'sanctum')->getJson('/api/v1/admin/stores/999999')->assertNotFound();
    }

    // ---------------------------------------------------------------- account access

    public function test_suspending_a_store_blocks_its_members_and_records_who_and_when(): void
    {
        $admin = $this->makeAdmin();
        $store = $this->makeStore('Shop');
        $store->forceFill(['subscription_status' => 'active'])->save();
        $owner = $this->makeUser($store, 'owner', ['email' => 'owner@shop.ps']);
        $other = $this->makeStore('Other');
        $otherOwner = $this->makeUser($other, 'owner');

        $this->actingAs($admin, 'sanctum')
            ->postJson("/api/v1/admin/stores/{$store->id}/status", ['status' => 'suspended', 'reason' => 'Unpaid since September'])
            ->assertOk()
            ->assertJsonPath('data.status', 'suspended')
            ->assertJsonPath('data.suspension_reason', 'Unpaid since September')
            ->assertJsonPath('data.status_changed_by.id', $admin->id)
            ->assertJsonPath('data.subscription.status', 'active');

        $store->refresh();
        $this->assertSame('suspended', $store->status);
        $this->assertSame($admin->id, $store->status_changed_by);
        $this->assertNotNull($store->status_changed_at);
        $this->assertSame('active', $store->subscription_status, 'Suspension must not touch the subscription.');

        $log = AuditLog::where('action', 'store.suspended')->sole();
        $this->assertSame($store->id, $log->store_id);
        $this->assertSame($admin->id, $log->user_id);
        $this->assertSame('Unpaid since September', $log->metadata['reason']);

        // Existing session and a new sign-in are both refused.
        $this->actingAs($owner->fresh(), 'sanctum')->getJson('/api/v1/me')
            ->assertForbidden()
            ->assertJsonPath('code', 'STORE_SUSPENDED');
        $this->postJson('/api/v1/login', ['email' => 'owner@shop.ps', 'password' => 'password'])
            ->assertForbidden()
            ->assertJsonPath('code', 'STORE_SUSPENDED')
            ->assertJsonMissingPath('token');

        // Other stores are untouched.
        $this->actingAs($otherOwner->fresh(), 'sanctum')->getJson('/api/v1/me')->assertOk();

        // Reactivation restores access and clears the reason.
        $this->actingAs($admin, 'sanctum')
            ->postJson("/api/v1/admin/stores/{$store->id}/status", ['status' => 'active'])
            ->assertOk()
            ->assertJsonPath('data.status', 'active')
            ->assertJsonPath('data.suspension_reason', null);
        $this->postJson('/api/v1/login', ['email' => 'owner@shop.ps', 'password' => 'password'])->assertOk();
        $this->assertSame(1, AuditLog::where('action', 'store.reactivated')->count());

        $this->actingAs($admin, 'sanctum')->getJson("/api/v1/admin/stores/{$store->id}")
            ->assertJsonPath('data.history.0.action', 'store.reactivated')
            ->assertJsonPath('data.history.0.by.id', $admin->id)
            ->assertJsonPath('data.history.1.action', 'store.suspended');
    }

    public function test_repeating_the_current_status_changes_nothing(): void
    {
        $admin = $this->makeAdmin();
        $store = $this->makeStore('Shop');

        $this->actingAs($admin, 'sanctum')->postJson("/api/v1/admin/stores/{$store->id}/status", ['status' => 'active'])->assertOk();

        $this->assertNull($store->fresh()->status_changed_at);
        $this->assertSame(0, AuditLog::count());
    }

    public function test_status_is_validated(): void
    {
        $admin = $this->makeAdmin();
        $store = $this->makeStore('Shop');

        $this->actingAs($admin, 'sanctum')->postJson("/api/v1/admin/stores/{$store->id}/status", [])
            ->assertStatus(422)->assertJsonValidationErrors('status');
        $this->actingAs($admin, 'sanctum')->postJson("/api/v1/admin/stores/{$store->id}/status", ['status' => 'deleted'])
            ->assertStatus(422)->assertJsonValidationErrors('status');
        $this->actingAs($admin, 'sanctum')->postJson("/api/v1/admin/stores/{$store->id}/status", ['status' => 'suspended', 'reason' => str_repeat('x', 501)])
            ->assertStatus(422)->assertJsonValidationErrors('reason');

        $this->assertSame('active', $store->fresh()->status);
    }

    public function test_suspended_store_blocks_google_sign_in_and_invitations(): void
    {
        $store = $this->makeStore('Shop');
        $owner = $this->makeUser($store, 'owner');
        $store->forceFill(['status' => 'suspended'])->save();

        StoreInvitation::create([
            'store_id' => $store->id,
            'invited_by' => $owner->id,
            'role' => 'employee',
            'token_hash' => hash('sha256', 'invite-token'),
            'expires_at' => now()->addDay(),
        ]);

        $this->postJson('/api/v1/register/invitation', [
            'token' => 'invite-token',
            'name' => 'New Hire',
            'email' => 'hire@example.com',
            'password' => 'Password123',
            'password_confirmation' => 'Password123',
        ])->assertForbidden()->assertJsonPath('code', 'STORE_SUSPENDED');

        $this->assertFalse(User::where('email', 'hire@example.com')->exists());

        // AuthService::findGoogleUser is the Google path's account check.
        $this->expectExceptionMessage('تم إيقاف حساب هذا المتجر');
        app(\App\Services\AuthService::class)->findGoogleUser(['sub' => 'g-1', 'email' => $owner->email]);
    }

    public function test_platform_admin_of_a_suspended_store_keeps_admin_access_only(): void
    {
        $store = $this->makeStore('Hisbah HQ');
        $admin = $this->makeAdmin($store);
        $admin->forceFill(['email' => 'admin@hisbah.ps', 'password' => Hash::make('password')])->save();
        $store->forceFill(['status' => 'suspended'])->save();

        $this->postJson('/api/v1/login', ['email' => 'admin@hisbah.ps', 'password' => 'password'])
            ->assertOk()
            ->assertJsonPath('user.is_platform_admin', true);

        $this->actingAs($admin->fresh(), 'sanctum')->getJson('/api/v1/admin/overview')->assertOk();
        $this->actingAs($admin->fresh(), 'sanctum')->getJson('/api/v1/me')->assertJsonPath('code', 'STORE_SUSPENDED');
    }

    // ---------------------------------------------------------------- subscription

    public function test_activating_a_subscription_keeps_account_access_separate(): void
    {
        $admin = $this->makeAdmin();
        $store = $this->makeStore('Shop');
        $store->forceFill(['status' => 'suspended'])->save();
        $expires = now()->addMonths(3)->startOfMinute();

        $this->actingAs($admin, 'sanctum')
            ->postJson("/api/v1/admin/stores/{$store->id}/subscription", [
                'status' => 'active',
                'expires_at' => $expires->toIso8601String(),
                'note' => 'Jawwal Pay transfer #4471',
            ])
            ->assertOk()
            ->assertJsonPath('data.subscription.status', 'active')
            ->assertJsonPath('data.subscription.state', 'active')
            ->assertJsonPath('data.subscription.changed_by.id', $admin->id)
            ->assertJsonPath('data.status', 'suspended');

        $store->refresh();
        $this->assertSame('suspended', $store->status, 'Activating a subscription must not reopen a suspended store.');
        $this->assertSame('active', $store->subscription_status);
        $this->assertTrue($store->subscription_expires_at->equalTo($expires));
        $this->assertNotNull($store->subscription_started_at);
        $this->assertSame($admin->id, $store->subscription_changed_by);

        $log = AuditLog::where('action', 'store.subscription_activated')->sole();
        $this->assertSame($store->id, $log->store_id);
        $this->assertSame($admin->id, $log->user_id);
        $this->assertSame('Jawwal Pay transfer #4471', $log->metadata['note']);

        // Deactivating the subscription leaves account access alone too; the store is back on its
        // (still running) trial.
        $store->forceFill(['status' => 'active'])->save();
        $this->actingAs($admin, 'sanctum')
            ->postJson("/api/v1/admin/stores/{$store->id}/subscription", ['status' => 'inactive'])
            ->assertOk()
            ->assertJsonPath('data.subscription.status', 'inactive')
            ->assertJsonPath('data.subscription.state', 'trial')
            ->assertJsonPath('data.status', 'active');
        $this->assertSame('active', $store->fresh()->status);
        $this->assertSame(1, AuditLog::where('action', 'store.subscription_deactivated')->count());
    }

    public function test_renewal_moves_the_expiry_and_keeps_the_start_date(): void
    {
        $admin = $this->makeAdmin();
        $store = $this->makeStore('Shop');
        $started = now()->subMonth()->startOfSecond();
        $store->forceFill(['subscription_status' => 'active', 'subscription_started_at' => $started, 'subscription_expires_at' => now()->addDay()])->save();

        $this->actingAs($admin, 'sanctum')
            ->postJson("/api/v1/admin/stores/{$store->id}/subscription", ['status' => 'active', 'expires_at' => now()->addYear()->toDateString()])
            ->assertOk();

        $store->refresh();
        $this->assertTrue($store->subscription_started_at->equalTo($started));
        $this->assertTrue($store->subscription_expires_at->greaterThan(now()->addMonths(11)));
    }

    public function test_a_bare_expiry_date_runs_to_the_end_of_that_day_in_the_store_timezone(): void
    {
        $admin = $this->makeAdmin();
        $store = $this->makeStore('Shop', ['timezone' => 'Asia/Gaza']);
        $day = now()->addDays(10)->toDateString();

        $this->actingAs($admin, 'sanctum')
            ->postJson("/api/v1/admin/stores/{$store->id}/subscription", ['status' => 'active', 'expires_at' => $day])
            ->assertOk();

        $local = $store->fresh()->subscription_expires_at->setTimezone('Asia/Gaza');
        $this->assertSame($day . ' 23:59:59', $local->format('Y-m-d H:i:s'));
    }

    public function test_subscription_is_validated(): void
    {
        $admin = $this->makeAdmin();
        $store = $this->makeStore('Shop');
        $url = "/api/v1/admin/stores/{$store->id}/subscription";

        $this->actingAs($admin, 'sanctum')->postJson($url, ['status' => 'trial'])->assertStatus(422)->assertJsonValidationErrors('status');
        $this->actingAs($admin, 'sanctum')->postJson($url, ['status' => 'active', 'expires_at' => now()->subDay()->toIso8601String()])
            ->assertStatus(422)->assertJsonValidationErrors('expires_at');
        $this->actingAs($admin, 'sanctum')->postJson($url, ['status' => 'active', 'expires_at' => 'not-a-date'])
            ->assertStatus(422)->assertJsonValidationErrors('expires_at');
        $this->actingAs($admin, 'sanctum')->postJson($url, ['status' => 'inactive', 'expires_at' => now()->addMonth()->toIso8601String()])
            ->assertStatus(422)->assertJsonValidationErrors('expires_at');

        $this->assertSame('inactive', $store->fresh()->subscription_status);
        $this->assertSame(0, AuditLog::count());
    }

    public function test_an_expired_subscription_does_not_suspend_the_store(): void
    {
        $store = $this->makeStore('Shop');
        $owner = $this->makeUser($store, 'owner');
        $store->forceFill(['subscription_status' => 'active', 'subscription_expires_at' => now()->subDay(), 'trial_ends_at' => now()->subDays(3)])->save();

        $this->assertSame('expired', $store->fresh()->subscriptionState());
        $this->assertSame('active', $store->fresh()->status);
        // Signed in and told why; business routes wait for renewal (SubscriptionTrialTest).
        $this->actingAs($owner, 'sanctum')->getJson('/api/v1/me')->assertOk();
        $this->actingAs($owner, 'sanctum')->getJson('/api/v1/dashboard')->assertForbidden()->assertJsonPath('code', 'SUBSCRIPTION_EXPIRED');
    }

    // ---------------------------------------------------------------- products and isolation

    public function test_store_products_endpoint_returns_only_that_stores_rows(): void
    {
        $admin = $this->makeAdmin();
        $mine = $this->makeStore('Mine');
        $theirs = $this->makeStore('Theirs');
        $own = $this->makeProduct($mine, ['name' => 'Mine tea', 'selling_price' => '12.00', 'cost_price' => '9.50']);
        $this->makeProduct($theirs, ['name' => 'Their tea', 'selling_price' => '15.00']);

        $this->actingAs($admin, 'sanctum')->getJson("/api/v1/admin/stores/{$mine->id}/products")
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', $own->id)
            ->assertJsonPath('data.0.selling_price', '12.00')
            ->assertJsonPath('data.0.cost_price', '9.50');
    }

    public function test_shared_catalog_item_keeps_each_stores_price_cost_and_stock(): void
    {
        $admin = $this->makeAdmin();
        $north = $this->makeStore('North', ['address' => 'Jabalia']);
        $south = $this->makeStore('South', ['address' => 'Rafah']);
        $catalog = $this->catalogItem();

        $a = $this->makeProduct($north, ['catalog_product_id' => $catalog->id, 'barcode' => $catalog->barcode, 'name' => 'Milk', 'selling_price' => '6.00', 'cost_price' => '4.50', 'current_stock' => 30]);
        $b = $this->makeProduct($south, ['catalog_product_id' => $catalog->id, 'barcode' => $catalog->barcode, 'name' => 'Milk 1L', 'selling_price' => '7.25', 'cost_price' => '5.00', 'current_stock' => 4]);
        $this->makeProduct($south, ['name' => 'Bread']);

        $offers = $this->actingAs($admin, 'sanctum')->getJson("/api/v1/admin/catalog-products/{$catalog->id}")
            ->assertOk()
            ->assertJsonPath('data.barcode', $catalog->barcode)
            ->assertJsonPath('data.stores_count', 2)
            ->assertJsonCount(2, 'data.offers')
            ->json('data.offers');

        $byStore = collect($offers)->keyBy('store.id');
        $this->assertSame(['6.00', '4.50', '30', 'Jabalia'], [$byStore[$north->id]['selling_price'], $byStore[$north->id]['cost_price'], $byStore[$north->id]['current_stock'], $byStore[$north->id]['store']['address']]);
        $this->assertSame(['7.25', '5.00', '4', 'Rafah'], [$byStore[$south->id]['selling_price'], $byStore[$south->id]['cost_price'], $byStore[$south->id]['current_stock'], $byStore[$south->id]['store']['address']]);

        // The cross-store list shows one row per store product, never a merged one.
        $rows = $this->actingAs($admin, 'sanctum')->getJson('/api/v1/admin/products?search=' . $catalog->barcode)
            ->assertOk()
            ->assertJsonCount(2, 'data')
            ->json('data');
        $this->assertEqualsCanonicalizing([$a->id, $b->id], array_column($rows, 'id'));

        $this->actingAs($admin, 'sanctum')->getJson('/api/v1/admin/products?store=Rafah')
            ->assertJsonCount(2, 'data');
        $this->actingAs($admin, 'sanctum')->getJson("/api/v1/admin/products?store_id={$north->id}")
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.store.name', 'North');
    }

    public function test_store_owner_product_endpoints_stay_scoped_to_their_store(): void
    {
        $mine = $this->makeStore('Mine');
        $owner = $this->makeUser($mine, 'owner');
        $this->makeProduct($mine);
        $foreign = $this->makeProduct($this->makeStore('Theirs'));

        $this->actingAs($owner, 'sanctum')->getJson('/api/v1/products?status=all')->assertJsonCount(1, 'data');
        $this->actingAs($owner, 'sanctum')->getJson("/api/v1/products/{$foreign->id}")->assertNotFound();
        $this->actingAs($owner, 'sanctum')->getJson('/api/v1/admin/products')->assertForbidden();
    }

    // ---------------------------------------------------------------- granting admin

    public function test_platform_admin_is_granted_and_revoked_only_by_the_console_command(): void
    {
        $store = $this->makeStore('Shop');
        $user = $this->makeUser($store, 'owner', ['email' => 'me@hisbah.ps']);
        $user->createToken('device');

        $this->artisan('hisbah:platform-admin', ['email' => 'nobody@hisbah.ps'])->assertExitCode(1);
        $this->assertSame(1, User::count());

        $this->artisan('hisbah:platform-admin', ['email' => 'me@hisbah.ps'])->assertExitCode(0);
        $this->assertTrue($user->fresh()->isPlatformAdmin());
        $this->assertSame(1, $user->tokens()->count());

        $this->artisan('hisbah:platform-admin', ['email' => 'me@hisbah.ps', '--revoke' => true])->assertExitCode(0);
        $this->assertFalse($user->fresh()->isPlatformAdmin());
        $this->assertSame(0, $user->tokens()->count(), 'Revocation signs the account out everywhere.');
    }

    public function test_deactivated_accounts_cannot_be_granted_admin(): void
    {
        $user = $this->makeUser($this->makeStore('Shop'), 'owner', ['email' => 'gone@hisbah.ps']);
        $user->forceFill(['status' => User::STATUS_INACTIVE])->save();

        $this->artisan('hisbah:platform-admin', ['email' => 'gone@hisbah.ps'])->assertExitCode(1);
        $this->assertFalse($user->fresh()->isPlatformAdmin());
    }
}
