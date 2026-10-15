<?php

namespace Tests\Feature;

use App\Enums\UserRole;
use App\Models\Customer;
use App\Models\Debt;
use App\Models\Invoice;
use App\Models\Payment;
use App\Models\Store;
use App\Models\StoreInvitation;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class BackendFeatureTest extends TestCase
{
    use RefreshDatabase;

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

    private function customer(Store $store, string $phone = '0590000001'): Customer
    {
        return Customer::create(['store_id' => $store->id, 'name' => 'Customer', 'phone' => $phone]);
    }

    private function invoice(Store $store, Customer $customer, bool $debt = true, float $total = 100): Invoice
    {
        $invoice = Invoice::create([
            'store_id' => $store->id,
            'customer_id' => $customer->id,
            'total_amount' => $total,
            'has_debt' => $debt,
            'payment_method' => $debt ? null : 'cash',
            'source' => 'sale',
        ]);
        $invoice->items()->create(['item_name' => 'Item', 'quantity' => 2, 'unit_price' => $total / 2, 'total' => $total]);
        if ($debt) {
            Debt::create(['store_id' => $store->id, 'invoice_id' => $invoice->id, 'amount' => $total, 'remaining_amount' => $total, 'status' => 'unpaid']);
        }
        return $invoice->fresh();
    }

    public function test_authentication_register_login_logout_and_protected_access(): void
    {
        $this->getJson('/api/v1/customers')->assertUnauthorized();
        $registered = $this->postJson('/api/v1/register', [
            'store_name' => 'Main',
            'owner_name' => 'Owner',
            'email' => 'owner@example.com',
            'password' => 'password',
            'password_confirmation' => 'password',
        ])->assertCreated()->assertJsonStructure(['message', 'user', 'token']);
        $this->postJson('/api/v1/login', ['email' => 'owner@example.com', 'password' => 'password'])->assertOk()->assertJsonStructure(['token']);
        $token = $registered->json('token');
        $this->withHeader('Authorization', "Bearer {$token}")->postJson('/api/v1/logout')->assertOk();
        $this->assertDatabaseHas('users', ['email' => 'owner@example.com', 'role' => 'owner']);
    }

    public function test_roles_and_invitations(): void
    {
        $store = $this->store('Main');
        $owner = $this->user($store);
        $manager = $this->user($store, 'manager');
        $employee = $this->user($store, 'employee');
        $this->assertTrue($owner->hasRole('owner'));
        $this->assertTrue($owner->hasRole(['owner', 'admin']));
        $invitation = $this->actingAs($owner, 'sanctum')->postJson('/api/v1/invitations', ['email' => 'new@example.com', 'role' => 'employee'])->assertCreated()->json('invitation');
        $this->assertDatabaseHas('store_invitations', ['id' => $invitation['id'], 'store_id' => $store->id]);
        $this->app['auth']->forgetGuards();
        $this->postJson('/api/v1/register/invitation', ['token' => $invitation['token'], 'name' => 'New', 'email' => 'new@example.com', 'password' => 'password', 'password_confirmation' => 'password'])->assertCreated();
        $this->postJson('/api/v1/register/invitation', ['token' => $invitation['token'], 'name' => 'Again', 'email' => 'again@example.com', 'password' => 'password', 'password_confirmation' => 'password'])->assertUnprocessable();
        $this->actingAs($employee, 'sanctum')->postJson('/api/v1/invitations', ['role' => 'employee'])->assertForbidden();
        $this->actingAs($owner, 'sanctum')->postJson('/api/v1/invitations', ['role' => 'owner'])->assertUnprocessable();
        $expired = StoreInvitation::create(['store_id' => $store->id, 'invited_by' => $owner->id, 'role' => 'employee', 'token_hash' => hash('sha256', 'expired'), 'expires_at' => Carbon::now()->subMinute()]);
        $this->app['auth']->forgetGuards();
        $this->postJson('/api/v1/register/invitation', ['token' => 'expired', 'name' => 'Old', 'email' => 'old@example.com', 'password' => 'password', 'password_confirmation' => 'password'])->assertUnprocessable();
        $this->actingAs($owner, 'sanctum')->getJson('/api/v1/users')->assertOk()->assertJsonFragment(['id' => $employee->id]);
        $this->actingAs($owner, 'sanctum')->patchJson("/api/v1/users/{$employee->id}/role", ['role' => 'manager'])->assertOk();
        $this->assertDatabaseHas('users', ['id' => $employee->id, 'role' => 'manager']);
        $this->actingAs($manager, 'sanctum')->getJson('/api/v1/users')->assertForbidden();
    }

    public function test_customer_crud_validation_history_and_store_isolation(): void
    {
        $a = $this->store('A');
        $b = $this->store('B');
        $owner = $this->user($a);
        $other = $this->user($b);
        $ca = $this->customer($a);
        $cb = $this->customer($b, '0590000002');
        $api = $this->actingAs($owner, 'sanctum');
        $api->postJson('/api/v1/customers', ['name' => 'Created', 'phone' => '0590000003'])->assertCreated();
        $api->postJson('/api/v1/customers', ['name' => 'Bad', 'phone' => '1'])->assertUnprocessable();
        $this->assertNotContains($cb->id, $api->getJson('/api/v1/customers')->assertOk()->json('data.*.id'));
        $api->getJson("/api/v1/customers/{$cb->id}")->assertNotFound();
        $api->putJson("/api/v1/customers/{$cb->id}", ['name' => 'Hack'])->assertNotFound();
        $api->deleteJson("/api/v1/customers/{$cb->id}")->assertNotFound();
        $api->putJson("/api/v1/customers/{$ca->id}", ['name' => 'Updated'])->assertOk();
        $this->actingAs($other, 'sanctum')->getJson('/api/v1/customers')->assertJsonPath('data.0.id', $cb->id);
        $this->assertDatabaseHas('customers', ['id' => $ca->id, 'name' => 'Updated']);
        $this->invoice($a, $ca);
        $this->actingAs($owner, 'sanctum')->deleteJson("/api/v1/customers/{$ca->id}")->assertUnprocessable();
        $this->actingAs($owner, 'sanctum')->deleteJson("/api/v1/customers/{$cb->id}")->assertNotFound();
    }

    public function test_invoices_totals_debts_update_delete_and_isolation(): void
    {
        $a = $this->store('A');
        $b = $this->store('B');
        $owner = $this->user($a);
        $ca = $this->customer($a);
        $cb = $this->customer($b, '0590000002');
        $api = $this->actingAs($owner, 'sanctum');
        $cash = $api->postJson('/api/v1/invoices', ['customer_id' => $ca->id, 'has_debt' => false, 'payment_method' => 'cash', 'items' => [['item_name' => 'A', 'quantity' => 2, 'unit_price' => 10], ['item_name' => 'B', 'quantity' => 1, 'unit_price' => 5.5]]], $this->idem())->assertCreated();
        $cashId = $cash->json('data.id');
        $this->assertDatabaseHas('invoices', ['id' => $cashId, 'total_amount' => 25.50]);
        $this->assertDatabaseCount('debts', 0);
        $debtResponse = $api->postJson('/api/v1/invoices', ['customer_id' => $ca->id, 'has_debt' => true, 'items' => [['item_name' => 'Debt', 'quantity' => 2, 'unit_price' => 50]]], $this->idem())->assertCreated();
        $debtId = $debtResponse->json('data.debt.id');
        $this->assertDatabaseHas('debts', ['id' => $debtId, 'amount' => 100, 'remaining_amount' => 100, 'status' => 'unpaid']);
        $foreign = $this->invoice($b, $cb);
        $api->getJson("/api/v1/invoices/{$foreign->id}")->assertNotFound();
        $api->putJson("/api/v1/invoices/{$foreign->id}", ['items' => [['item_name' => 'x', 'quantity' => 1, 'unit_price' => 1]]])->assertNotFound();
        $api->deleteJson("/api/v1/invoices/{$foreign->id}")->assertNotFound();
        $this->assertNotContains($foreign->id, $api->getJson('/api/v1/invoices')->assertOk()->json('data.*.id'));
        $api->putJson("/api/v1/invoices/{$cashId}", ['items' => [['item_name' => 'Updated', 'quantity' => 3, 'unit_price' => 10]]])->assertOk();
        $this->assertDatabaseHas('invoices', ['id' => $cashId, 'total_amount' => 30]);
        $api->deleteJson("/api/v1/invoices/{$cashId}")->assertOk();
        $this->assertDatabaseMissing('invoices', ['id' => $cashId]);
        $api->postJson('/api/v1/invoices', ['customer_id' => $ca->id, 'has_debt' => false, 'items' => []], $this->idem())->assertUnprocessable();
    }

    public function test_debts_payments_status_reversal_pay_all_and_isolation(): void
    {
        $a = $this->store('A');
        $b = $this->store('B');
        $owner = $this->user($a);
        $manager = $this->user($a, 'manager');
        $employee = $this->user($a, 'employee');
        $ca = $this->customer($a);
        $cb = $this->customer($b, '0590000002');
        $foreign = $this->invoice($b, $cb);
        $invoice = $this->invoice($a, $ca, true, 100);
        $debt = $invoice->debt;
        $api = $this->actingAs($employee, 'sanctum');
        $foreignPayment = $foreign->debt->payments()->create(['amount' => 1, 'method' => 'cash', 'paid_at' => now()]);
        $this->assertNotContains($foreign->debt->id, $api->getJson('/api/v1/debts')->assertOk()->json('data.*.id'));
        $api->getJson("/api/v1/debts/{$foreign->debt->id}")->assertNotFound();
        $api->getJson("/api/v1/customers/{$cb->id}/debts")->assertNotFound();
        $api->putJson("/api/v1/debts/{$foreign->debt->id}", ['amount' => 2])->assertNotFound();
        $api->deleteJson("/api/v1/debts/{$foreign->debt->id}")->assertNotFound();
        $api->postJson('/api/v1/payments', ['debt_id' => $debt->id, 'amount' => 40, 'method' => 'cash'], $this->idem())->assertCreated();
        $this->assertDatabaseHas('debts', ['id' => $debt->id, 'remaining_amount' => 60, 'status' => 'partially_paid']);
        $api->postJson('/api/v1/payments', ['debt_id' => $debt->id, 'amount' => 61, 'method' => 'cash'], $this->idem())->assertUnprocessable();
        $api->postJson('/api/v1/payments', ['debt_id' => $debt->id, 'amount' => 60, 'method' => 'cash'], $this->idem())->assertCreated();
        $this->assertDatabaseHas('debts', ['id' => $debt->id, 'remaining_amount' => 0, 'status' => 'paid']);
        $payment = Payment::where('debt_id', $debt->id)->first();
        $this->actingAs($manager, 'sanctum')->postJson("/api/v1/payments/{$payment->id}/reverse", ['reason' => 'Correction'], $this->idem())->assertOk();
        $this->assertDatabaseHas('debts', ['id' => $debt->id, 'remaining_amount' => 40, 'status' => 'partially_paid']);
        $paymentsResponse = $this->actingAs($manager, 'sanctum')->getJson('/api/v1/payments')->assertOk();
        $visiblePaymentIds = collect($paymentsResponse->json('data'))->flatMap(fn($operation) => collect($operation['payments'])->pluck('id'));
        $this->assertNotContains($foreignPayment->id, $visiblePaymentIds->all());
        $this->actingAs($manager, 'sanctum')->postJson("/api/v1/payments/{$foreignPayment->id}/reverse", ['reason' => 'Hack'], $this->idem())->assertNotFound();
        $this->actingAs($owner, 'sanctum')->postJson("/api/v1/customers/{$ca->id}/debts/pay-all", ['method' => 'cash'], $this->idem())->assertCreated();
        $this->assertDatabaseHas('debts', ['id' => $debt->id, 'remaining_amount' => 0, 'status' => 'paid']);
        $this->actingAs($employee, 'sanctum')->postJson('/api/v1/payments', ['debt_id' => $foreign->debt->id, 'amount' => 1, 'method' => 'cash'], $this->idem())->assertUnprocessable();
    }

    public function test_user_policy_is_scoped_and_rejects_unauthorized_role_changes(): void
    {
        $a = $this->store('A');
        $b = $this->store('B');
        $owner = $this->user($a);
        $target = $this->user($a, 'employee');
        $foreign = $this->user($b, 'employee');
        $this->actingAs($owner, 'sanctum')->patchJson("/api/v1/users/{$foreign->id}/role", ['role' => 'manager'])->assertNotFound(); // US-0105 AC4: cross-store targets are 404
        $this->actingAs($target, 'sanctum')->patchJson("/api/v1/users/{$owner->id}/role", ['role' => 'employee'])->assertForbidden();
        $this->actingAs($owner, 'sanctum')->patchJson("/api/v1/users/{$target->id}/role", ['role' => 'invalid'])->assertUnprocessable();
        $this->assertDatabaseHas('users', ['id' => $foreign->id, 'store_id' => $b->id, 'role' => 'employee']);
    }

    public function test_role_matrix_protects_administrative_and_financial_operations(): void
    {
        $store = $this->store('Main');
        $owner = $this->user($store);
        $manager = $this->user($store, 'manager');
        $employee = $this->user($store, 'employee');
        $customer = $this->customer($store);
        $invoice = $this->invoice($store, $customer, true, 100);
        $debt = $invoice->debt;

        $employeeApi = $this->actingAs($employee, 'sanctum');
        $employeeApi->postJson('/api/v1/customers', ['name' => 'Employee customer', 'phone' => '0590000003'])->assertCreated();
        $employeeApi->postJson('/api/v1/invoices', [
            'customer_id' => $customer->id,
            'has_debt' => false,
            'payment_method' => 'cash',
            'items' => [['item_name' => 'Cash item', 'quantity' => 1, 'unit_price' => 10]],
        ], $this->idem())->assertCreated();
        $employeeApi->postJson('/api/v1/payments', ['debt_id' => $debt->id, 'amount' => 10, 'method' => 'cash'], $this->idem())->assertCreated();
        $employeeApi->deleteJson("/api/v1/invoices/{$invoice->id}")->assertForbidden();
        $employeeApi->putJson("/api/v1/debts/{$debt->id}", ['amount' => 90])->assertForbidden();
        $employeeApi->deleteJson("/api/v1/debts/{$debt->id}")->assertForbidden();
        $payment = Payment::where('debt_id', $debt->id)->first();
        $employeeApi->postJson("/api/v1/payments/{$payment->id}/reverse", ['reason' => 'Not allowed'], $this->idem())->assertForbidden();
        $employeeApi->postJson("/api/v1/customers/{$customer->id}/debts/pay-all", ['method' => 'cash'], $this->idem())->assertCreated(); // D-12: employees may record full repayment
        $employeeApi->getJson('/api/v1/users')->assertForbidden();
        $employeeApi->postJson('/api/v1/invitations', ['role' => 'employee'])->assertForbidden();

        $managerApi = $this->actingAs($manager, 'sanctum');
        $managerApi->getJson('/api/v1/users')->assertForbidden();
        $managerApi->patchJson("/api/v1/users/{$employee->id}/role", ['role' => 'manager'])->assertForbidden();
        $managerApi->postJson('/api/v1/invitations', ['role' => 'employee'])->assertForbidden();
        $managerApi->postJson("/api/v1/payments/{$payment->id}/reverse", ['reason' => 'Manager correction'], $this->idem())->assertOk();
        $managerApi->postJson("/api/v1/customers/{$customer->id}/debts/pay-all", ['method' => 'cash'], $this->idem())->assertCreated();

        $this->assertDatabaseHas('users', ['id' => $owner->id, 'role' => 'owner']);
        $this->assertDatabaseHas('payments', ['id' => $payment->id, 'is_reversed' => true]);
    }

    public function test_invoice_conversion_and_payment_protected_deletion_rules(): void
    {
        $store = $this->store('Main');
        $owner = $this->user($store);
        $customer = $this->customer($store);
        $api = $this->actingAs($owner, 'sanctum');

        $convertible = $this->invoice($store, $customer, true, 100);
        $convertibleDebtId = $convertible->debt->id;
        $api->putJson("/api/v1/invoices/{$convertible->id}", [
            'has_debt' => false,
            'payment_method' => 'cash',
        ])->assertOk();
        $this->assertDatabaseHas('invoices', ['id' => $convertible->id, 'has_debt' => false, 'payment_method' => 'cash']);
        $this->assertDatabaseHas('debts', ['id' => $convertibleDebtId]);
        $this->assertNotNull(Debt::withTrashed()->find($convertibleDebtId)->deleted_at);

        $cash = $this->invoice($store, $customer, false, 50);
        $api->putJson("/api/v1/invoices/{$cash->id}", ['has_debt' => true])->assertUnprocessable();
        $this->assertDatabaseHas('invoices', ['id' => $cash->id, 'has_debt' => false]);

        $paid = $this->invoice($store, $customer, true, 75);
        $payment = $paid->debt->payments()->create(['amount' => 25, 'method' => 'cash', 'paid_at' => now()]);
        $api->deleteJson("/api/v1/invoices/{$paid->id}")->assertUnprocessable();
        $this->assertDatabaseHas('invoices', ['id' => $paid->id]);
        $this->assertDatabaseHas('debts', ['id' => $paid->debt->id, 'remaining_amount' => 75]);
        $this->assertDatabaseHas('payments', ['id' => $payment->id, 'is_reversed' => false]);
    }

    public function test_opening_debt_lifecycle_is_role_protected_and_consistent(): void
    {
        $store = $this->store('Main');
        $owner = $this->user($store);
        $manager = $this->user($store, 'manager');
        $employee = $this->user($store, 'employee');
        $customer = $this->customer($store);
        $payload = ['customer_id' => $customer->id, 'amount' => 120];

        $employee->load('store');
        $this->actingAs($employee, 'sanctum')->postJson('/api/v1/debts', $payload, $this->idem())->assertForbidden();
        $created = $this->actingAs($manager, 'sanctum')->postJson('/api/v1/debts', $payload, $this->idem())->assertCreated();
        $debtId = $created->json('data.debt.id');
        $this->assertDatabaseHas('debts', ['id' => $debtId, 'amount' => 120, 'remaining_amount' => 120, 'status' => 'unpaid']);
        $this->actingAs($manager, 'sanctum')->putJson("/api/v1/debts/{$debtId}", ['amount' => 150])->assertOk();
        $this->assertDatabaseHas('debts', ['id' => $debtId, 'amount' => 150, 'remaining_amount' => 150]);
        $this->actingAs($owner, 'sanctum')->deleteJson("/api/v1/debts/{$debtId}")->assertOk();
        $this->assertDatabaseMissing('debts', ['id' => $debtId]);
    }
}
