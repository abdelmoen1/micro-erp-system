<?php

namespace Tests\Feature;

use App\Models\AuditLog;
use App\Services\AuditService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\Str;
use LogicException;
use Tests\Support\BuildsShopData;
use Tests\TestCase;

/**
 * US-0103 — critical audit log (with US-0105 for role changes and deactivation).
 */
class AuditLogTest extends TestCase
{
    use BuildsShopData;
    use RefreshDatabase;

    /** TC-0103-01: a payment reversal is logged with actor, action, entity and reason. */
    public function test_payment_reversal_is_audited(): void
    {
        $store = $this->makeStore();
        $manager = $this->makeUser($store, 'manager');
        $debt = $this->makeCreditInvoice($store, $this->makeCustomer($store))->debt;
        $payment = $debt->payments()->create(['amount' => '40.00', 'method' => 'cash', 'paid_at' => now()]);

        $this->actingAs($manager, 'sanctum')
            ->postJson("/api/v1/payments/{$payment->id}/reverse", ['reason' => 'Duplicate entry'], $this->idem())
            ->assertOk();

        $log = AuditLog::sole();
        $this->assertSame('payment.reversed', $log->action);
        $this->assertSame($manager->id, $log->user_id);
        $this->assertSame($store->id, $log->store_id);
        $this->assertSame('Payment', $log->entity_type);
        $this->assertSame((string) $payment->id, $log->entity_id);
        $this->assertSame('Duplicate entry', $log->metadata['reason']);
        $this->assertSame('40.00', $log->metadata['amount']);
        $this->assertNotNull($log->created_at);

        $group = (string) Str::uuid();
        $debt->payments()->create(['amount' => '10.00', 'method' => 'cash', 'paid_at' => now(), 'payment_group_id' => $group]);
        $this->actingAs($manager, 'sanctum')
            ->postJson("/api/v1/payment-groups/{$group}/reverse", ['reason' => 'Wrong customer'], $this->idem())
            ->assertOk();
        $this->assertDatabaseHas('audit_logs', ['action' => 'payment_group.reversed', 'entity_id' => $group]);
    }

    /** TC-0103-02: a role change is logged with the old and new role. */
    public function test_role_change_is_audited(): void
    {
        $store = $this->makeStore();
        $owner = $this->makeUser($store);
        $employee = $this->makeUser($store, 'employee');

        $this->actingAs($owner, 'sanctum')
            ->patchJson("/api/v1/users/{$employee->id}/role", ['role' => 'manager'])
            ->assertOk();

        $log = AuditLog::where('action', 'user.role_changed')->sole();
        $this->assertSameMetadata(['old_role' => 'employee', 'new_role' => 'manager'], $log->metadata);
        $this->assertSame($owner->id, $log->user_id);
    }

    public function test_opening_debt_invitation_and_deactivation_are_audited(): void
    {
        $store = $this->makeStore();
        $owner = $this->makeUser($store);
        $employee = $this->makeUser($store, 'employee');
        $api = $this->actingAs($owner, 'sanctum');

        $debtId = $api->postJson('/api/v1/debts', ['customer_id' => $this->makeCustomer($store)->id, 'amount' => '50.00'], $this->idem())
            ->assertCreated()->json('data.debt.id');
        $api->putJson("/api/v1/debts/{$debtId}", ['amount' => '55.00'])->assertOk();
        $api->postJson('/api/v1/invitations', ['role' => 'employee'])->assertCreated();
        $api->postJson("/api/v1/users/{$employee->id}/deactivate")->assertOk();
        $api->deleteJson("/api/v1/debts/{$debtId}")->assertOk();

        $this->assertSame(
            ['opening_debt.created', 'opening_debt.updated', 'invitation.created', 'user.deactivated', 'opening_debt.deleted'],
            AuditLog::orderBy('id')->pluck('action')->all(),
        );
        $this->assertSameMetadata(['old_amount' => '50.00', 'new_amount' => '55.00'], AuditLog::where('action', 'opening_debt.updated')->sole()->metadata);
    }

    /** TC-0103-03: when the action's transaction rolls back, no audit row exists. */
    public function test_rolled_back_action_leaves_no_audit_row(): void
    {
        $store = $this->makeStore();
        $owner = $this->makeUser($store);
        $this->actingAs($owner);

        try {
            DB::transaction(function () use ($owner) {
                app(AuditService::class)->record('payment.reversed', $owner, ['reason' => 'x']);
                throw new \RuntimeException('business failure');
            });
        } catch (\RuntimeException) {
        }

        $this->assertSame(0, AuditLog::count());
    }

    /** TC-0103-04: no API route can modify or delete audit rows, and the model refuses it. */
    public function test_audit_rows_cannot_be_changed(): void
    {
        $auditRoutes = collect(Route::getRoutes()->getRoutes())
            ->filter(fn($route) => str_contains($route->uri(), 'audit'));
        $this->assertCount(0, $auditRoutes, 'No audit endpoint exists in the MVP; none may mutate audit rows.');

        $store = $this->makeStore();
        $owner = $this->makeUser($store);
        $this->actingAs($owner);
        $log = app(AuditService::class)->record('user.role_changed', $owner);

        try {
            $log->update(['action' => 'tampered']);
            $this->fail('Updating an audit row must throw.');
        } catch (LogicException) {
        }

        try {
            $log->delete();
            $this->fail('Deleting an audit row must throw.');
        } catch (LogicException) {
        }

        $this->assertDatabaseHas('audit_logs', ['id' => $log->id, 'action' => 'user.role_changed']);
    }

    /**
     * Same keys, values and types; key order ignored (MySQL JSON columns do not keep it).
     */
    private function assertSameMetadata(array $expected, ?array $actual): void
    {
        $this->assertNotNull($actual);
        ksort($expected);
        ksort($actual);
        $this->assertSame($expected, $actual);
    }
}
