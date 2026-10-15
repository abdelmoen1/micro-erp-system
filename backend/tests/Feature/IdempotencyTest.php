<?php

namespace Tests\Feature;

use App\Models\Debt;
use App\Models\IdempotencyKey;
use App\Models\Invoice;
use App\Models\Payment;
use App\Models\Store;
use App\Models\User;
use App\Services\IdempotencyService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\Str;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\Support\BuildsShopData;
use Tests\TestCase;

/**
 * US-0101 — duplicate-safe financial writes (regression for DEF-02).
 */
class IdempotencyTest extends TestCase
{
    use BuildsShopData;
    use RefreshDatabase;

    /** Every financial route. A new financial endpoint must be added here and to scenario(). */
    private const FINANCIAL_ROUTES = [
        'POST api/v1/payments',
        'POST api/v1/payments/{payment}/reverse',
        'POST api/v1/payment-groups/{paymentGroupId}/reverse',
        'POST api/v1/customers/{customer}/debts/pay-all',
        'POST api/v1/debts',
        'POST api/v1/invoices',
    ];

    private Store $store;
    private User $owner;

    protected function setUp(): void
    {
        parent::setUp();
        $this->store = $this->makeStore();
        $this->owner = $this->makeUser($this->store, 'owner');
    }

    /** TC-0101-01: an identical replay creates one record and returns the same response. */
    public function test_replay_returns_the_first_response_and_writes_once(): void
    {
        $debt = $this->makeCreditInvoice($this->store, $this->makeCustomer($this->store))->debt;
        $key = $this->idem();
        $body = ['debt_id' => $debt->id, 'amount' => '40.00', 'method' => 'cash'];

        $first = $this->actingAs($this->owner, 'sanctum')->postJson('/api/v1/payments', $body, $key)->assertCreated();
        $second = $this->actingAs($this->owner, 'sanctum')->postJson('/api/v1/payments', $body, $key)->assertCreated();

        $this->assertSame($first->getContent(), $second->getContent());
        $second->assertHeader('Idempotent-Replay', 'true');
        $first->assertHeaderMissing('Idempotent-Replay');
        $this->assertSame(1, Payment::count());
        $this->assertDatabaseHas('debts', ['id' => $debt->id, 'remaining_amount' => '60.00']);
    }

    /** TC-0101-02: the same key with a different body is rejected and writes nothing. */
    public function test_key_reuse_with_a_different_body_is_a_conflict(): void
    {
        $debt = $this->makeCreditInvoice($this->store, $this->makeCustomer($this->store))->debt;
        $key = $this->idem();

        $this->actingAs($this->owner, 'sanctum')
            ->postJson('/api/v1/payments', ['debt_id' => $debt->id, 'amount' => '40.00', 'method' => 'cash'], $key)
            ->assertCreated();
        $this->actingAs($this->owner, 'sanctum')
            ->postJson('/api/v1/payments', ['debt_id' => $debt->id, 'amount' => '50.00', 'method' => 'cash'], $key)
            ->assertStatus(409)
            ->assertJsonPath('code', 'IDEMPOTENCY_KEY_REUSED');

        $this->assertSame(1, Payment::count());
    }

    /** TC-0101-03: every financial endpoint requires a key. */
    #[DataProvider('financialScenarios')]
    public function test_missing_key_is_rejected_with_428(string $scenario): void
    {
        [$method, $uri, $body, $effect] = $this->scenario($scenario);
        $before = $effect();

        $this->actingAs($this->owner, 'sanctum')->json($method, $uri, $body)
            ->assertStatus(428)
            ->assertJsonPath('code', 'IDEMPOTENCY_KEY_REQUIRED');

        $this->assertSame($before, $effect());
    }

    public function test_malformed_key_is_rejected(): void
    {
        $this->actingAs($this->owner, 'sanctum')
            ->postJson('/api/v1/debts', [], ['Idempotency-Key' => 'not-a-uuid'])
            ->assertUnprocessable()
            ->assertJsonPath('code', 'IDEMPOTENCY_KEY_INVALID');
    }

    /**
     * TC-0101-04: two concurrent requests with the same key. The race is simulated:
     * the second request does not see the first one's key at lookup time, executes,
     * then hits the unique (store_id, key) constraint. Its whole transaction rolls back
     * and it replays the winner's response.
     */
    public function test_concurrent_duplicate_produces_one_record(): void
    {
        $debt = $this->makeCreditInvoice($this->store, $this->makeCustomer($this->store))->debt;
        $headers = $this->idem();
        $body = ['debt_id' => $debt->id, 'amount' => '40.00', 'method' => 'cash'];

        $first = $this->actingAs($this->owner, 'sanctum')->postJson('/api/v1/payments', $body, $headers)->assertCreated();

        $this->app->instance(IdempotencyService::class, new class extends IdempotencyService {
            private bool $blind = true;

            protected function find(int $storeId, string $key): ?IdempotencyKey
            {
                if ($this->blind) {
                    $this->blind = false;

                    return null;
                }

                return parent::find($storeId, $key);
            }
        });

        $second = $this->actingAs($this->owner, 'sanctum')->postJson('/api/v1/payments', $body, $headers)->assertCreated();

        $this->assertSame($first->getContent(), $second->getContent());
        $second->assertHeader('Idempotent-Replay', 'true');
        $this->assertSame(1, Payment::count());
        $this->assertDatabaseHas('debts', ['id' => $debt->id, 'remaining_amount' => '60.00']);
    }

    /** TC-0101-05: a failed business transaction does not persist the key; a retry runs normally. */
    public function test_failed_request_does_not_store_the_key(): void
    {
        $debt = $this->makeCreditInvoice($this->store, $this->makeCustomer($this->store))->debt;
        $key = $this->idem();

        $this->actingAs($this->owner, 'sanctum')
            ->postJson('/api/v1/payments', ['debt_id' => $debt->id, 'amount' => '500.00', 'method' => 'cash'], $key)
            ->assertUnprocessable();
        $this->assertSame(0, IdempotencyKey::count());

        Route::middleware(['api', 'auth:sanctum', 'store', 'idempotent'])
            ->post('/api/v1/_test/half-write', function () use ($debt) {
                $debt->payments()->create(['amount' => '1.00', 'method' => 'cash', 'paid_at' => now()]);
                throw new \RuntimeException('boom after a write');
            });
        $this->actingAs($this->owner, 'sanctum')->postJson('/api/v1/_test/half-write', [], $this->idem())->assertStatus(500);
        $this->assertSame(0, Payment::count(), 'A write before the failure must be rolled back.');
        $this->assertSame(0, IdempotencyKey::count());

        $this->actingAs($this->owner, 'sanctum')
            ->postJson('/api/v1/payments', ['debt_id' => $debt->id, 'amount' => '100.00', 'method' => 'cash'], $key)
            ->assertCreated();
        $this->assertSame(1, Payment::count());
    }

    /** TC-0101-06: the same key in two stores gives each store its own result. */
    public function test_keys_are_scoped_per_store(): void
    {
        $otherStore = $this->makeStore('Other');
        $otherOwner = $this->makeUser($otherStore, 'owner');
        $key = $this->idem();

        $a = $this->actingAs($this->owner, 'sanctum')
            ->postJson('/api/v1/debts', ['customer_id' => $this->makeCustomer($this->store)->id, 'amount' => '10.00'], $key)
            ->assertCreated();
        $b = $this->actingAs($otherOwner, 'sanctum')
            ->postJson('/api/v1/debts', ['customer_id' => $this->makeCustomer($otherStore)->id, 'amount' => '10.00'], $key)
            ->assertCreated();

        $b->assertHeaderMissing('Idempotent-Replay');
        $this->assertNotSame($a->json('data.id'), $b->json('data.id'));
        $this->assertSame(2, Debt::count());
    }

    /** TC-0101-07: replaying any financial endpoint has exactly one business effect. */
    #[DataProvider('financialScenarios')]
    public function test_replay_on_every_financial_endpoint_has_one_effect(string $scenario): void
    {
        [$method, $uri, $body, $effect] = $this->scenario($scenario);
        $before = $effect();
        $key = $this->idem();

        $first = $this->actingAs($this->owner, 'sanctum')->json($method, $uri, $body, $key);
        $this->assertTrue($first->isSuccessful(), "{$scenario}: " . $first->getContent());
        $afterFirst = $effect();
        $this->assertNotSame($before, $afterFirst, "{$scenario}: the first call must have an effect");

        $second = $this->actingAs($this->owner, 'sanctum')->json($method, $uri, $body, $key);
        $second->assertHeader('Idempotent-Replay', 'true');
        $this->assertSame($first->getContent(), $second->getContent());
        $this->assertSame($afterFirst, $effect(), "{$scenario}: the replay must not have a second effect");
    }

    /** DoD guard: the scenario list and the routes carrying the middleware stay in sync. */
    public function test_every_financial_route_is_protected_and_covered(): void
    {
        $protected = collect(Route::getRoutes()->getRoutes())
            ->filter(fn($route) => in_array('idempotent', $route->gatherMiddleware(), true))
            ->flatMap(fn($route) => collect($route->methods())
                ->reject(fn($m) => $m === 'HEAD')
                ->map(fn($m) => "{$m} {$route->uri()}"))
            ->sort()->values()->all();

        $expected = collect(self::FINANCIAL_ROUTES)->sort()->values()->all();

        $this->assertSame($expected, $protected);
        $this->assertCount(count(self::FINANCIAL_ROUTES), self::financialScenarios());
    }

    public static function financialScenarios(): array
    {
        return [
            'record payment' => ['payment'],
            'reverse payment' => ['reverse-payment'],
            'reverse payment group' => ['reverse-group'],
            'pay all' => ['pay-all'],
            'opening debt' => ['opening-debt'],
            'legacy invoice create' => ['invoice'],
        ];
    }

    /**
     * @return array{0:string,1:string,2:array,3:\Closure():string}
     */
    private function scenario(string $name): array
    {
        $customer = $this->makeCustomer($this->store);
        $debt = $this->makeCreditInvoice($this->store, $customer)->debt;

        $state = fn() => json_encode([
            'payments' => Payment::count(),
            'reversed' => Payment::where('is_reversed', true)->count(),
            'debts' => Debt::count(),
            'invoices' => Invoice::count(),
            'remaining' => Debt::orderBy('id')->pluck('remaining_amount')->map(fn($v) => (string) $v)->all(),
        ]);

        return match ($name) {
            'payment' => ['POST', '/api/v1/payments', ['debt_id' => $debt->id, 'amount' => '25.00', 'method' => 'cash'], $state],
            'reverse-payment' => (function () use ($debt, $state) {
                $payment = $debt->payments()->create(['amount' => '30.00', 'method' => 'cash', 'paid_at' => now()]);
                $debt->update(['remaining_amount' => '70.00', 'status' => 'partially_paid']);

                return ['POST', "/api/v1/payments/{$payment->id}/reverse", ['reason' => 'Entered twice'], $state];
            })(),
            'reverse-group' => (function () use ($debt, $state) {
                $group = (string) Str::uuid();
                $debt->payments()->create(['amount' => '100.00', 'method' => 'cash', 'paid_at' => now(), 'payment_group_id' => $group]);
                $debt->update(['remaining_amount' => '0.00', 'status' => 'paid']);

                return ['POST', "/api/v1/payment-groups/{$group}/reverse", ['reason' => 'Wrong customer'], $state];
            })(),
            'pay-all' => ['POST', "/api/v1/customers/{$customer->id}/debts/pay-all", ['method' => 'cash'], $state],
            'opening-debt' => ['POST', '/api/v1/debts', ['customer_id' => $customer->id, 'amount' => '75.50'], $state],
            'invoice' => ['POST', '/api/v1/invoices', [
                'customer_id' => $customer->id,
                'has_debt' => false,
                'payment_method' => 'cash',
                'items' => [['item_name' => 'Tea', 'quantity' => 2, 'unit_price' => '3.50']],
            ], $state],
        };
    }
}
