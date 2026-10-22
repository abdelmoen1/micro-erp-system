<?php

namespace Tests\Feature;

use App\Models\Payment;
use App\Models\Store;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\Support\BuildsShopData;
use Tests\TestCase;

/**
 * US-0105 — role matrix (05 §6 as approved under D-12) and staff deactivation (D-13).
 * Regression for DEF-04, DEF-09 and the DEF-05 containment.
 */
class RoleMatrixTest extends TestCase
{
    use BuildsShopData;
    use RefreshDatabase;

    private const ALL = ['owner' => true, 'manager' => true, 'employee' => true];
    private const OWNER_MANAGER = ['owner' => true, 'manager' => true, 'employee' => false];
    private const OWNER_ONLY = ['owner' => true, 'manager' => false, 'employee' => false];

    /** action => who may perform it */
    private const MATRIX = [
        'view dashboard' => self::ALL,
        'list customers, sales, debts, payments' => self::ALL,
        'create customer' => self::ALL,
        'update customer' => self::ALL,
        'set customer credit limit (US-0305)' => self::OWNER_MANAGER,
        'delete customer without history' => self::OWNER_MANAGER,
        'create sale' => self::ALL,
        'update sale notes (DEF-05 containment)' => self::OWNER_MANAGER,
        'void sale (US-0503)' => self::OWNER_MANAGER,
        'record payment' => self::ALL,
        'pay all (D-12)' => self::ALL,
        'reverse payment' => self::OWNER_MANAGER,
        'reverse payment group' => self::OWNER_MANAGER,
        'create opening debt' => self::OWNER_MANAGER,
        'update opening debt' => self::OWNER_MANAGER,
        'delete opening debt' => self::OWNER_MANAGER,
        'invite staff' => self::OWNER_ONLY,
        'list staff' => self::OWNER_ONLY,
        'change role' => self::OWNER_ONLY,
        'deactivate staff' => self::OWNER_ONLY,
        'set store timezone' => self::OWNER_ONLY,
    ];

    public static function matrix(): array
    {
        $rows = [];
        foreach (self::MATRIX as $action => $roles) {
            foreach ($roles as $role => $allowed) {
                $rows["{$action} as {$role}"] = [$action, $role, $allowed];
            }
        }

        return $rows;
    }

    /** TC-0105-01: every cell of the authorization matrix. */
    #[DataProvider('matrix')]
    public function test_role_matrix(string $action, string $role, bool $allowed): void
    {
        $store = $this->makeStore();
        $owner = $this->makeUser($store, 'owner');
        $actor = $role === 'owner' ? $owner : $this->makeUser($store, $role);

        [$method, $uri, $body, $headers] = $this->request($action, $store);
        $response = $this->actingAs($actor, 'sanctum')->json($method, $uri, $body, $headers);

        if ($action === 'list customers, sales, debts, payments') {
            foreach (['customers', 'invoices', 'debts'] as $list) {
                $this->actingAs($actor, 'sanctum')->getJson("/api/v1/{$list}")->assertOk();
            }
        }

        if ($allowed) {
            $this->assertTrue($response->isSuccessful(), "{$action} as {$role} should be allowed: " . $response->getContent());
        } else {
            $response->assertForbidden()->assertJsonPath('code', 'FORBIDDEN');
        }
    }

    /** TC-0105-02: nobody can assign the owner role (DEF-04). */
    public function test_owner_role_cannot_be_assigned(): void
    {
        $store = $this->makeStore();
        $owner = $this->makeUser($store);
        $employee = $this->makeUser($store, 'employee');

        $this->actingAs($owner, 'sanctum')
            ->patchJson("/api/v1/users/{$employee->id}/role", ['role' => 'owner'])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('role');

        $this->assertDatabaseHas('users', ['id' => $employee->id, 'role' => 'employee']);
        $this->actingAs($owner, 'sanctum')
            ->postJson("/api/v1/users/{$owner->id}/deactivate")
            ->assertForbidden();
    }

    /** TC-0105-03: a deactivated employee loses tokens and cannot log in. */
    public function test_deactivated_user_is_blocked_and_tokens_revoked(): void
    {
        $store = $this->makeStore();
        $owner = $this->makeUser($store);
        $employee = $this->makeUser($store, 'employee', ['email' => 'staff@example.com']);

        $token = $this->postJson('/api/v1/login', ['email' => 'staff@example.com', 'password' => 'password'])
            ->assertOk()->json('token');
        $this->withToken($token)->getJson('/api/v1/me')->assertOk();
        $this->app['auth']->forgetGuards();

        $this->withToken('')->actingAs($owner, 'sanctum')
            ->postJson("/api/v1/users/{$employee->id}/deactivate")
            ->assertOk()
            ->assertJsonPath('data.status', 'inactive');
        $this->app['auth']->forgetGuards();

        $this->assertSame(0, $employee->tokens()->count());
        $this->withToken($token)->getJson('/api/v1/me')->assertUnauthorized();

        $this->postJson('/api/v1/login', ['email' => 'staff@example.com', 'password' => 'password'])
            ->assertForbidden()
            ->assertJsonPath('code', 'USER_INACTIVE');

        // A session that somehow survived is still refused by the active-user middleware.
        $this->actingAs($employee->fresh(), 'sanctum')->getJson('/api/v1/customers')
            ->assertForbidden()
            ->assertJsonPath('code', 'USER_INACTIVE');

        $this->assertNotNull($employee->fresh()->deactivated_at);
        $this->assertSame(1, User::whereKey($employee->id)->count(), 'Users are deactivated, never deleted.');
    }

    /** TC-0105-04: the deactivated user's history keeps its attribution (DEF-09). */
    public function test_attribution_is_preserved_after_deactivation(): void
    {
        $store = $this->makeStore();
        $owner = $this->makeUser($store);
        $employee = $this->makeUser($store, 'employee');
        $debt = $this->makeCreditInvoice($store, $this->makeCustomer($store))->debt;

        $this->actingAs($employee, 'sanctum')
            ->postJson('/api/v1/payments', ['debt_id' => $debt->id, 'amount' => '10.00', 'method' => 'cash'], $this->idem())
            ->assertCreated();
        $this->actingAs($owner, 'sanctum')->postJson("/api/v1/users/{$employee->id}/deactivate")->assertOk();

        $this->assertSame($employee->id, Payment::sole()->created_by);
        $this->assertFalse(collect(app('router')->getRoutes()->getRoutes())
            ->contains(fn($r) => $r->uri() === 'api/v1/users/{user}' && in_array('DELETE', $r->methods(), true)),
            'The user delete route is replaced by deactivation.');
    }

    /** TC-0105-05: staff actions targeting another store's user are 404. */
    public function test_cross_store_staff_targets_are_not_found(): void
    {
        $owner = $this->makeUser($this->makeStore('A'));
        $foreign = $this->makeUser($this->makeStore('B'), 'employee');

        $this->actingAs($owner, 'sanctum')->patchJson("/api/v1/users/{$foreign->id}/role", ['role' => 'manager'])->assertNotFound();
        $this->actingAs($owner, 'sanctum')->postJson("/api/v1/users/{$foreign->id}/deactivate")->assertNotFound();
        $this->assertDatabaseHas('users', ['id' => $foreign->id, 'role' => 'employee', 'status' => 'active']);
    }

    /**
     * @return array{0:string,1:string,2:array,3:array}
     */
    private function request(string $action, Store $store): array
    {
        $customer = $this->makeCustomer($store);
        $sale = $this->makeCreditInvoice($store, $customer);
        $debt = $sale->debt;
        $idem = $this->idem();

        return match ($action) {
            'view dashboard' => ['GET', '/api/v1/dashboard', [], []],
            'list customers, sales, debts, payments' => ['GET', '/api/v1/payments', [], []],
            'create customer' => ['POST', '/api/v1/customers', ['name' => 'New', 'phone' => '0599999999'], []],
            'update customer' => ['PUT', "/api/v1/customers/{$customer->id}", ['name' => 'Renamed'], []],
            'set customer credit limit (US-0305)' => ['PATCH', "/api/v1/customers/{$customer->id}", ['credit_limit' => '300.00'], []],
            'delete customer without history' => ['DELETE', '/api/v1/customers/' . $this->makeCustomer($store)->id, [], []],
            'create sale' => ['POST', '/api/v1/sales', [
                'customer_id' => $customer->id, 'paid_amount' => '10.00', 'payment_method' => 'cash',
                'items' => [['product_id' => $this->makeProduct($store)->id, 'quantity' => 1]],
            ], $idem],
            'update sale notes (DEF-05 containment)' => ['PATCH', "/api/v1/sales/{$sale->id}", ['notes' => 'Delivered'], []],
            'void sale (US-0503)' => ['POST', "/api/v1/sales/{$sale->id}/void", ['reason' => 'Rang up twice'], $idem],
            'record payment' => ['POST', '/api/v1/payments', ['debt_id' => $debt->id, 'amount' => '5.00', 'method' => 'cash'], $idem],
            'pay all (D-12)' => ['POST', "/api/v1/customers/{$customer->id}/debts/pay-all", ['method' => 'cash'], $idem],
            'reverse payment' => (function () use ($debt, $idem) {
                $payment = $debt->payments()->create(['amount' => '5.00', 'method' => 'cash', 'paid_at' => now()]);

                return ['POST', "/api/v1/payments/{$payment->id}/reverse", ['reason' => 'test'], $idem];
            })(),
            'reverse payment group' => (function () use ($debt, $idem) {
                $group = (string) Str::uuid();
                $debt->payments()->create(['amount' => '5.00', 'method' => 'cash', 'paid_at' => now(), 'payment_group_id' => $group]);

                return ['POST', "/api/v1/payment-groups/{$group}/reverse", ['reason' => 'test'], $idem];
            })(),
            'create opening debt' => ['POST', '/api/v1/debts', ['customer_id' => $customer->id, 'amount' => '20.00'], $idem],
            'update opening debt' => ['PUT', '/api/v1/debts/' . $this->openingDebtId($store, $customer), ['amount' => '30.00'], []],
            'delete opening debt' => ['DELETE', '/api/v1/debts/' . $this->openingDebtId($store, $customer), [], []],
            'invite staff' => ['POST', '/api/v1/invitations', ['role' => 'employee'], []],
            'list staff' => ['GET', '/api/v1/users', [], []],
            'change role' => ['PATCH', '/api/v1/users/' . $this->makeUser($store, 'employee')->id . '/role', ['role' => 'manager'], []],
            'deactivate staff' => ['POST', '/api/v1/users/' . $this->makeUser($store, 'employee')->id . '/deactivate', [], []],
            'set store timezone' => ['PATCH', '/api/v1/my-store', ['timezone' => 'Asia/Hebron'], []],
        };
    }

    private function openingDebtId(Store $store, $customer): int
    {
        $owner = User::where('store_id', $store->id)->where('role', 'owner')->first();

        $id = $this->actingAs($owner, 'sanctum')
            ->postJson('/api/v1/debts', ['customer_id' => $customer->id, 'amount' => '20.00'], $this->idem())
            ->assertCreated()
            ->json('data.debt.id');
        $this->app['auth']->forgetGuards();

        return $id;
    }
}
