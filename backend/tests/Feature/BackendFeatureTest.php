<?php

namespace Tests\Feature;

use App\Enums\UserRole;
use App\Models\Customer;
use App\Models\Debt;
use App\Models\Invoice;
use App\Models\Store;
use App\Models\StoreInvitation;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Str;
use Tests\TestCase;

class BackendFeatureTest extends TestCase
{
    use RefreshDatabase;

    protected function createStoreOwner(array $overrides = []): User
    {
        $store = Store::create([
            'name' => $overrides['store_name'] ?? 'Main Store',
            'phone' => $overrides['store_phone'] ?? '0590000000',
            'address' => $overrides['store_address'] ?? 'Nablus',
        ]);

        $user = User::factory()->make([
            'name' => $overrides['owner_name'] ?? 'Owner Name',
            'email' => $overrides['email'] ?? 'owner@example.com',
            'password' => 'password123',
        ]);

        $user->store_id = $store->id;
        $user->role = UserRole::OWNER;
        $user->save();

        return $user->fresh();
    }

    protected function makeEmployeeForStore(User $owner, array $overrides = []): User
    {
        $employee = User::factory()->make([
            'name' => $overrides['name'] ?? 'Employee Name',
            'email' => $overrides['email'] ?? 'employee@example.com',
            'password' => 'password123',
        ]);

        $employee->store_id = $owner->store_id;
        $employee->role = $overrides['role'] ?? UserRole::EMPLOYEE;
        $employee->save();

        return $employee->fresh();
    }

    public function test_owner_can_register_login_and_logout(): void
    {
        $payload = [
            'store_name' => 'Test Store',
            'owner_name' => 'Store Owner',
            'email' => 'store.owner@example.com',
            'phone' => '0591234567',
            'address' => 'Ramallah',
            'password' => 'Password123!',
            'password_confirmation' => 'Password123!',
        ];

        $response = $this->postJson('/api/register', $payload);

        $response->assertStatus(201)
            ->assertJsonPath('message', 'تم إنشاء المتجر والمالك بنجاح')
            ->assertJsonPath('user.email', 'store.owner@example.com')
            ->assertJsonPath('user.role', 'owner')
            ->assertJsonPath('token', fn ($token) => is_string($token) && $token !== '');

        $user = User::query()->where('email', 'store.owner@example.com')->firstOrFail();
        $this->assertNotNull($user->store_id);

        $loginResponse = $this->postJson('/api/login', [
            'email' => 'store.owner@example.com',
            'password' => 'Password123!',
        ]);

        $loginResponse->assertStatus(200)
            ->assertJsonPath('message', 'تم تسجيل دخولك بنجاح')
            ->assertJsonPath('user.email', 'store.owner@example.com');

        $this->actingAs($user, 'sanctum');

        $this->getJson('/api/me')
            ->assertStatus(200)
            ->assertJsonPath('user.email', 'store.owner@example.com');

        $this->postJson('/api/logout')->assertStatus(200)
            ->assertJsonPath('message', 'تم تسجيل الخروج بنجاح');
    }

    public function test_owner_can_create_and_accept_invitation(): void
    {
        $owner = $this->createStoreOwner();
        $this->actingAs($owner, 'sanctum');

        $invitationResponse = $this->postJson('/api/invitations', [
            'email' => 'invitee@example.com',
            'role' => UserRole::EMPLOYEE->value,
            'expires_in_hours' => 24,
        ]);

        $invitationResponse->assertStatus(201)
            ->assertJsonPath('message', 'تم إنشاء الدعوة بنجاح')
            ->assertJsonPath('invitation.email', 'invitee@example.com')
            ->assertJsonPath('invitation.role', 'employee');

        $token = $invitationResponse->json('invitation.token');
        $this->assertNotEmpty($token);

        $this->assertDatabaseHas('store_invitations', [
            'store_id' => $owner->store_id,
            'email' => 'invitee@example.com',
            'role' => UserRole::EMPLOYEE->value,
        ]);

        Auth::forgetGuards();

        $this->postJson('/api/register/invitation', [
            'token' => $token,
            'name' => 'Invited User',
            'email' => 'invitee@example.com',
            'password' => 'Password123!',
            'password_confirmation' => 'Password123!',
        ])->assertStatus(201)
            ->assertJsonPath('message', 'تم إنشاء الحساب والانضمام إلى المتجر بنجاح')
            ->assertJsonPath('user.email', 'invitee@example.com')
            ->assertJsonPath('user.role', 'employee');

        $this->assertDatabaseHas('users', [
            'email' => 'invitee@example.com',
            'store_id' => $owner->store_id,
            'role' => UserRole::EMPLOYEE->value,
        ]);
    }

    public function test_owner_can_manage_customers(): void
    {
        $owner = $this->createStoreOwner();
        $this->actingAs($owner, 'sanctum');

        $response = $this->postJson('/api/customers', [
            'name' => 'Ali Hassan',
            'phone' => '0591234567',
            'address' => 'Hebron',
            'notes' => 'Preferred customer',
        ]);

        $response->assertStatus(201)
            ->assertJsonPath('message', 'تم انشاء العميل بنجاح')
            ->assertJsonPath('customer.name', 'Ali Hassan');

        $customer = Customer::query()->where('phone', '0591234567')->firstOrFail();

        $this->getJson('/api/customers')
            ->assertStatus(200)
            ->assertJsonPath('data.0.name', 'Ali Hassan');

        $this->getJson('/api/customers/' . $customer->id)
            ->assertStatus(200)
            ->assertJsonPath('data.name', 'Ali Hassan');

        $this->patchJson('/api/customers/' . $customer->id, [
            'name' => 'Ali Hassan Updated',
            'phone' => '0597654321',
            'address' => 'Jerusalem',
            'notes' => 'Updated notes',
        ])->assertStatus(200)
            ->assertJsonPath('data.name', 'Ali Hassan Updated');

        $this->deleteJson('/api/customers/' . $customer->id)->assertStatus(200)
            ->assertJsonPath('message', 'تم حذف العميل بنجاح.');

        $this->assertSoftDeleted('customers', ['id' => $customer->id]);
    }

    public function test_owner_can_create_invoice_with_debt_and_process_payments_and_reversals(): void
    {
        $owner = $this->createStoreOwner();
        $this->actingAs($owner, 'sanctum');

        $customer = Customer::create([
            'name' => 'Customer A',
            'phone' => '0590000001',
            'address' => 'Bethlehem',
            'store_id' => $owner->store_id,
        ]);

        $invoiceResponse = $this->postJson('/api/invoices', [
            'customer_id' => $customer->id,
            'has_debt' => true,
            'items' => [
                ['item_name' => 'Chair', 'quantity' => 2, 'unit_price' => 50],
            ],
        ]);

        $invoiceResponse->assertStatus(201)
            ->assertJsonPath('data.total_amount', 100)
            ->assertJsonPath('data.has_debt', true)
            ->assertJsonPath('data.debt.amount', 100);

        $debt = Debt::query()->firstOrFail();
        $this->assertEquals(100.0, (float) $debt->remaining_amount);
        $this->assertSame('unpaid', $debt->status);

        $paymentResponse = $this->postJson('/api/payments', [
            'debt_id' => $debt->id,
            'amount' => 40,
            'method' => 'cash',
            'paid_at' => now()->toDateTimeString(),
        ]);

        $paymentResponse->assertStatus(201)
            ->assertJsonPath('data.amount', 40);

        $debt->refresh();
        $this->assertEquals(60.0, (float) $debt->remaining_amount);
        $this->assertSame('partially_paid', $debt->status);

        $reverseResponse = $this->postJson('/api/payments/' . $paymentResponse->json('data.id') . '/reverse', [
            'reason' => 'test reversal',
        ]);

        $reverseResponse->assertStatus(200)
            ->assertJsonPath('message', 'تم إلغاء الدفعة وإعادة المبلغ إلى الدين بنجاح.');

        $debt->refresh();
        $this->assertEquals(100.0, (float) $debt->remaining_amount);
        $this->assertSame('unpaid', $debt->status);

        $groupCustomer = Customer::create([
            'name' => 'Customer B',
            'phone' => '0590000002',
            'address' => 'Nablus',
            'store_id' => $owner->store_id,
        ]);

        $largeInvoice = $this->postJson('/api/invoices', [
            'customer_id' => $groupCustomer->id,
            'has_debt' => true,
            'items' => [
                ['item_name' => 'Desk', 'quantity' => 1, 'unit_price' => 75],
            ],
        ]);

        $largeInvoice->assertStatus(201);

        $payAllResponse = $this->postJson('/api/customers/' . $groupCustomer->id . '/debts/pay-all', [
            'method' => 'jawwal_pay',
            'paid_at' => now()->toDateTimeString(),
        ]);

        $payAllResponse->assertStatus(201)
            ->assertJsonPath('message', 'تم تسديد جميع ديون العميل بنجاح.')
            ->assertJsonPath('data.debts_count', 1);

        $paymentGroupId = $payAllResponse->json('data.payment_group_id');

        $this->postJson('/api/payment-groups/' . $paymentGroupId . '/reverse', [
            'reason' => 'bulk reversal',
        ])->assertStatus(200)
            ->assertJsonPath('message', 'تم إلغاء عملية السداد بالكامل بنجاح.');
    }

    public function test_owner_can_manage_store_users(): void
    {
        $owner = $this->createStoreOwner();
        $employee = $this->makeEmployeeForStore($owner, ['email' => 'emp@example.com']);
        $this->actingAs($owner, 'sanctum');

        $this->getJson('/api/users')
            ->assertStatus(200)
            ->assertJsonPath('data.0.email', 'emp@example.com');

        $this->patchJson('/api/users/' . $employee->id . '/role', [
            'role' => UserRole::MANAGER->value,
        ])->assertStatus(200)
            ->assertJsonPath('data.role', 'manager');

        $employee->refresh();
        $this->assertSame(UserRole::MANAGER->value, $employee->role->value);

        $this->deleteJson('/api/users/' . $employee->id)
            ->assertStatus(200)
            ->assertJsonPath('message', 'تم حذف المستخدم بنجاح');

        $this->assertDatabaseMissing('users', ['id' => $employee->id]);
    }
}
