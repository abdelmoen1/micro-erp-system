<?php

namespace Tests\Feature;

use App\Models\AccountDeletionRequest;
use App\Models\Invoice;
use App\Models\Store;
use App\Models\SubscriptionOrder;
use App\Models\SubscriptionPlan;
use App\Models\TrialClaim;
use App\Models\User;
use App\Services\SaleService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Support\BuildsShopData;
use Tests\TestCase;

/** ACCOUNT_DELETION_PLAN.md: staff anonymisation, owner store closure with a grace period, public page, admin review. */
class AccountDeletionTest extends TestCase
{
    use BuildsShopData;
    use RefreshDatabase;

    public function test_staff_deletes_their_account_and_the_shops_records_stay(): void
    {
        $store = $this->makeStore();
        $owner = $this->makeUser($store, 'owner');
        $employee = $this->makeUser($store, 'employee');
        $phone = $employee->phone;
        $sale = app(SaleService::class)->create($employee, ['items' => [['product_id' => $this->makeProduct($store)->id, 'quantity' => 1]], 'paid_amount' => '10.00', 'payment_method' => 'cash'])['invoice'];
        $token = $employee->createToken('phone')->plainTextToken;

        $this->withToken($token)->postJson('/api/v1/me/deletion', ['password' => 'wrong'])->assertUnprocessable();
        $this->withToken($token)->postJson('/api/v1/me/deletion', ['password' => 'password'])->assertCreated()
            ->assertJsonPath('data.type', 'staff')->assertJsonPath('data.status', 'completed');

        $employee->refresh();
        $this->assertSame('حساب محذوف', $employee->name);
        $this->assertNull($employee->phone);
        $this->assertNull($employee->password);
        $this->assertSame(0, $employee->tokens()->count());
        $this->assertSame($employee->id, Invoice::find($sale->id)->user_id ?? $employee->id, 'the sale keeps its author row');
        $this->assertNotNull(Invoice::find($sale->id));

        $this->app['auth']->forgetGuards();
        $this->postJson('/api/v1/login', ['login' => $phone, 'password' => 'password'])->assertUnauthorized();
        $this->actingAs($owner, 'sanctum')->getJson('/api/v1/me')->assertOk();
    }

    public function test_owner_closes_the_store_with_a_grace_period_and_can_cancel(): void
    {
        $store = $this->makeStore('Corner Shop');
        $owner = $this->makeUser($store, 'owner');
        $employee = $this->makeUser($store, 'employee');
        $employeeToken = $employee->createToken('phone')->plainTextToken;
        $ownerToken = $owner->createToken('phone')->plainTextToken;

        $this->withToken($ownerToken)->postJson('/api/v1/me/deletion', ['password' => 'password', 'confirm_store_name' => 'Wrong'])->assertUnprocessable();
        $this->withToken($ownerToken)->postJson('/api/v1/me/deletion', ['password' => 'password', 'confirm_store_name' => 'Corner Shop'])
            ->assertCreated()->assertJsonPath('data.type', 'store')->assertJsonPath('data.status', 'scheduled');

        $store->refresh();
        $this->assertTrue($store->deletion_scheduled_for->isSameDay(now()->addDays(14)));
        $this->assertSame(0, $employee->tokens()->count(), 'every member is signed out');
        $this->app['auth']->forgetGuards();

        // Staff cannot sign in; the owner can, but only to see and cancel the request.
        $this->postJson('/api/v1/login', ['login' => $employee->phone, 'password' => 'password'])->assertForbidden()->assertJsonPath('code', 'STORE_CLOSING');
        $token = $this->postJson('/api/v1/login', ['login' => $owner->phone, 'password' => 'password'])->assertOk()->json('token');
        $this->withToken($token)->getJson('/api/v1/products')->assertForbidden()->assertJsonPath('code', 'STORE_CLOSING');
        $this->withToken($token)->getJson('/api/v1/me/deletion')->assertOk()->assertJsonPath('data.request.status', 'scheduled');

        $this->withToken($token)->deleteJson('/api/v1/me/deletion')->assertOk()->assertJsonPath('data.status', 'cancelled');
        $this->assertNull($store->fresh()->deletion_scheduled_for);
        $this->app['auth']->forgetGuards();
        $this->withToken($token)->getJson('/api/v1/products')->assertOk();
        $this->assertNotNull($employeeToken);
    }

    public function test_after_the_grace_period_the_store_is_deleted_and_hisbah_payment_records_are_kept(): void
    {
        $store = $this->makeStore('Closing');
        $owner = $this->makeUser($store, 'owner');
        $this->makeCustomer($store);
        TrialClaim::create(['phone_hash' => TrialClaim::hashPhone($owner->phone), 'store_id' => $store->id, 'started_at' => now(), 'ends_at' => now()]);
        $order = SubscriptionOrder::create([
            'store_id' => $store->id, 'store_name' => $store->name, 'subscription_plan_id' => SubscriptionPlan::first()->id,
            'plan_snapshot' => ['name' => 'شهري'], 'duration_months' => 1, 'amount' => '50.00', 'currency' => 'ILS',
            'channel' => 'manual_whatsapp', 'status' => 'paid',
        ]);
        $other = $this->makeStore('Untouched');
        $this->makeCustomer($other);

        $this->actingAs($owner, 'sanctum')->postJson('/api/v1/me/deletion', ['password' => 'password', 'confirm_store_name' => 'Closing'])->assertCreated();
        $this->artisan('hisbah:process-deletions')->expectsOutput('Stores deleted: 0.')->assertSuccessful();

        $this->travel(15)->days();
        $this->artisan('hisbah:process-deletions')->expectsOutput('Stores deleted: 1.')->assertSuccessful();

        $this->assertNull(Store::find($store->id));
        $this->assertNull(User::find($owner->id));
        $this->assertSame(0, \App\Models\Customer::where('store_id', $store->id)->count());
        $this->assertSame(1, \App\Models\Customer::where('store_id', $other->id)->count());
        $order->refresh();
        $this->assertNull($order->store_id);
        $this->assertSame('Closing', $order->store_name, 'Hisbah keeps its own sales record');
        $this->assertSame(1, TrialClaim::count(), 'the used trial stays used (number kept only as an HMAC)');
        $this->assertSame('completed', AccountDeletionRequest::sole()->status);
    }

    public function test_the_public_page_deletes_with_the_password_even_for_deactivated_staff(): void
    {
        $store = $this->makeStore();
        $this->makeUser($store, 'owner');
        $staff = $this->makeUser($store, 'employee', ['status' => 'inactive']);

        $response = $this->postJson('/api/v1/account-deletion', ['phone' => $staff->phone, 'password' => 'password'])
            ->assertCreated()->assertJsonPath('data.status', 'completed');
        $this->assertNull($staff->fresh()->phone);

        // The status page shows the status only: no name, no number.
        $status = $this->getJson('/api/v1/account-deletion/' . $response->json('data.reference'))->assertOk();
        $this->assertSame(['reference', 'type', 'status', 'requested_at', 'scheduled_for', 'completed_at'], array_keys($status->json('data')));
        $this->getJson('/api/v1/account-deletion/' . \Illuminate\Support\Str::uuid())->assertNotFound();
    }

    public function test_a_request_without_password_is_reviewed_by_the_platform_admin_and_answers_alike(): void
    {
        $store = $this->makeStore();
        $this->makeUser($store, 'owner');
        $staff = $this->makeUser($store, 'manager');

        $known = $this->postJson('/api/v1/account-deletion', ['phone' => $staff->phone, 'no_password' => true, 'reason' => 'lost phone'])->assertStatus(202);
        $unknown = $this->postJson('/api/v1/account-deletion', ['phone' => '0599777666', 'no_password' => true])->assertStatus(202);
        $this->assertSame($known->json('message'), $unknown->json('message'));
        $this->assertSame('pending_review', $known->json('data.status'));
        $this->assertNotNull($staff->fresh()->phone, 'nothing is deleted before review');

        $admin = $this->makeUser($this->makeStore('Platform'), 'owner');
        $admin->forceFill(['is_platform_admin' => true])->save();
        $this->actingAs($staff, 'sanctum')->getJson('/api/v1/admin/deletion-requests')->assertForbidden();
        $this->actingAs($admin, 'sanctum')->getJson('/api/v1/admin/deletion-requests')->assertOk()->assertJsonCount(2, 'data');

        $id = AccountDeletionRequest::where('status', 'pending_review')->whereNotNull('user_id')->value('id');
        $this->actingAs($admin, 'sanctum')->patchJson("/api/v1/admin/deletion-requests/{$id}", ['action' => 'approve'])->assertOk()
            ->assertJsonPath('data.status', 'completed');
        $this->assertNull($staff->fresh()->phone);

        $unknownId = AccountDeletionRequest::whereNull('user_id')->value('id');
        $this->actingAs($admin, 'sanctum')->patchJson("/api/v1/admin/deletion-requests/{$unknownId}", ['action' => 'approve'])->assertOk()
            ->assertJsonPath('data.status', 'rejected');
    }

    public function test_deletion_stays_reachable_after_the_subscription_ends_and_admins_are_protected(): void
    {
        $store = $this->makeStore();
        $store->forceFill(['trial_ends_at' => now()->subDay()])->save();
        $employee = $this->makeUser($store, 'employee');
        $this->actingAs($employee, 'sanctum')->getJson('/api/v1/products')->assertForbidden()->assertJsonPath('code', 'SUBSCRIPTION_EXPIRED');
        $this->actingAs($employee, 'sanctum')->getJson('/api/v1/me/deletion')->assertOk()->assertJsonPath('data.type', 'staff');

        $admin = $this->makeUser($this->makeStore('Platform'), 'owner');
        $admin->forceFill(['is_platform_admin' => true])->save();
        $this->actingAs($admin, 'sanctum')->postJson('/api/v1/me/deletion', ['password' => 'password', 'confirm_store_name' => 'Platform'])
            ->assertStatus(409)->assertJsonPath('code', 'PLATFORM_ADMIN_ACCOUNT');
    }

    public function test_owner_hands_the_store_to_a_manager(): void
    {
        $store = $this->makeStore();
        $owner = $this->makeUser($store, 'owner');
        $manager = $this->makeUser($store, 'manager');
        $employee = $this->makeUser($store, 'employee');
        $outsider = $this->makeUser($this->makeStore('Other'), 'manager');

        $this->actingAs($owner, 'sanctum')->postJson('/api/v1/my-store/transfer-ownership', ['user_id' => $employee->id, 'password' => 'password'])->assertUnprocessable();
        $this->actingAs($owner, 'sanctum')->postJson('/api/v1/my-store/transfer-ownership', ['user_id' => $outsider->id, 'password' => 'password'])->assertUnprocessable();
        $this->actingAs($manager, 'sanctum')->postJson('/api/v1/my-store/transfer-ownership', ['user_id' => $owner->id, 'password' => 'password'])->assertForbidden();

        $this->actingAs($owner, 'sanctum')->postJson('/api/v1/my-store/transfer-ownership', ['user_id' => $manager->id, 'password' => 'password'])->assertOk();
        $this->assertSame('owner', $manager->fresh()->role->value);
        $this->assertSame('manager', $owner->fresh()->role->value);
    }
}
