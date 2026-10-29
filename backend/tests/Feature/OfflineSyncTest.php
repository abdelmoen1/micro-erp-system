<?php

namespace Tests\Feature;

use App\Models\AuditLog;
use App\Models\Customer;
use App\Models\Debt;
use App\Models\Invoice;
use App\Models\Payment;
use App\Models\Product;
use App\Models\Store;
use App\Models\SyncConflict;
use App\Models\User;
use App\Services\SaleService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Str;
use RuntimeException;
use Tests\Support\BuildsShopData;
use Tests\TestCase;

/**
 * US-1101, US-1102, US-1106 — offline sync (doc 16): FIFO, exactly once, accept-and-flag sales,
 * held payments, bootstrap / delta and the manager's resolutions.
 */
class OfflineSyncTest extends TestCase
{
    use BuildsShopData;
    use RefreshDatabase;

    private Store $store;
    private User $owner;
    private User $employee;
    private int $seq = 0;

    protected function setUp(): void
    {
        parent::setUp();
        $this->store = $this->makeStore();
        $this->owner = $this->makeUser($this->store, 'owner');
        $this->employee = $this->makeUser($this->store, 'employee');
    }

    /** TC-1101-01 / AC-07: 10 queued items take effect in FIFO order, each once. */
    public function test_ten_items_apply_in_fifo_order(): void
    {
        $customer = $this->makeCustomer($this->store);
        $product = $this->makeProduct($this->store, ['current_stock' => 100]);
        $items = [];

        for ($i = 0; $i < 5; $i++) {
            // A credit sale, then a payment of part of it: the payment needs the sale's debt first.
            $items[] = $this->saleItem(['customer_id' => $customer->id, 'paid_amount' => '0', 'items' => [['product_id' => $product->id, 'quantity' => 1]]]);
            $items[] = $this->paymentItem($customer, '4.00', 'jawwal_pay');
        }

        $results = $this->batch($items, $this->employee)->assertOk()->json('results');

        $this->assertCount(10, $results);
        $this->assertSame(array_column($items, 'seq'), array_column($results, 'seq'));
        $this->assertSame(array_fill(0, 10, 'applied'), array_column($results, 'status'));
        $this->assertSame(5, Invoice::count());
        // A customer payment is allocated oldest debt first, so one may split over two debts.
        $this->assertSame(5, Payment::distinct()->count('payment_group_id'));
        $this->assertEquals(20.0, (float) Payment::sum('amount'));
        $this->assertEquals(30.0, (float) Debt::sum('remaining_amount'));
        $this->assertSame(['jawwal_pay'], Payment::distinct()->pluck('method')->all());
        $this->assertSame('95.000', (string) $product->fresh()->current_stock);
        $this->assertNotNull(Invoice::first()->synced_at);
        $this->assertSame(0, SyncConflict::count());
    }

    /** TC-1101-02 / AC-06: a resent batch (the answer was lost) changes nothing. */
    public function test_a_resent_batch_is_duplicate_and_has_no_second_effect(): void
    {
        $customer = $this->makeCustomer($this->store);
        $this->makeCreditInvoice($this->store, $customer, '50.00');
        $product = $this->makeProduct($this->store);
        $items = [
            $this->saleItem(['paid_amount' => '20.00', 'payment_method' => 'palpay', 'items' => [['product_id' => $product->id, 'quantity' => 2]]]),
            $this->paymentItem($customer, '10.00'),
        ];

        $first = $this->batch($items)->json('results');
        $second = $this->batch($items)->assertOk()->json('results');

        $this->assertSame(['applied', 'applied'], array_column($first, 'status'));
        $this->assertSame(['duplicate', 'duplicate'], array_column($second, 'status'));
        $this->assertSame(array_column($first, 'server_id'), array_column($second, 'server_id'));
        $this->assertSame(2, Invoice::count());
        $this->assertSame(1, Payment::count());
        $this->assertSame('palpay', Invoice::latest('id')->first()->payment_method);
    }

    /** AC-06: an online checkout that timed out, then queued with its key and body, is one sale. */
    public function test_an_uncertain_online_sale_moved_to_the_queue_is_recorded_once(): void
    {
        $product = $this->makeProduct($this->store);
        $body = ['paid_amount' => '10.00', 'payment_method' => 'bank_of_palestine', 'items' => [['product_id' => $product->id, 'quantity' => 1]]];
        $key = (string) Str::uuid();

        $online = $this->actingAs($this->owner, 'sanctum')
            ->postJson('/api/v1/sales', $body, ['Idempotency-Key' => $key])
            ->assertCreated();

        $result = $this->batch([$this->saleItem($body, key: $key)])->json('results.0');

        $this->assertSame('duplicate', $result['status']);
        $this->assertSame($online->json('data.id'), $result['server_id']);
        $this->assertSame(1, Invoice::count());
    }

    /** And the other way round: the online attempt never arrived, so the queued one applies. */
    public function test_a_queued_sale_whose_online_attempt_never_arrived_applies(): void
    {
        $product = $this->makeProduct($this->store);
        $result = $this->batch([$this->saleItem(['paid_amount' => '10.00', 'payment_method' => 'cash', 'items' => [['product_id' => $product->id, 'quantity' => 1]]])])
            ->json('results.0');

        $this->assertSame('applied', $result['status']);
        $this->assertSame(1, Invoice::count());
    }

    /** TC-1101-03 / D-03: a payment above the current balance is held, not applied, not lost. */
    public function test_a_payment_above_the_balance_is_held_for_review(): void
    {
        $customer = $this->makeCustomer($this->store);
        $this->makeCreditInvoice($this->store, $customer, '20.00');
        $item = $this->paymentItem($customer, '25.00');

        $result = $this->batch([$item])->json('results.0');
        $again = $this->batch([$item])->json('results.0');

        $this->assertSame('conflict', $result['status']);
        $this->assertSame('PAYMENT_EXCEEDS_REMAINING', $result['error']['code']);
        $this->assertSame('conflict', $again['status']);
        $this->assertSame(0, Payment::count());
        $this->assertDatabaseCount('sync_conflicts', 1);
        $this->assertDatabaseHas('sync_conflicts', [
            'client_transaction_id' => $item['client_transaction_id'],
            'kind' => 'conflict',
            'status' => 'open',
            'customer_id' => $customer->id,
            'amount' => '25.00',
        ]);
    }

    /** TC-1101-04 / D-27: a sale below zero stock is recorded and flagged. */
    public function test_negative_stock_is_recorded_and_flagged(): void
    {
        $product = $this->makeProduct($this->store, ['current_stock' => 1]);

        $result = $this->batch([$this->saleItem(['paid_amount' => '30.00', 'payment_method' => 'cash', 'items' => [['product_id' => $product->id, 'quantity' => 3]]])])
            ->json('results.0');

        $this->assertSame('flagged', $result['status']);
        $this->assertSame(['NEGATIVE_STOCK'], $result['flags']);
        $this->assertSame('-2.000', (string) $product->fresh()->current_stock);
        $this->assertDatabaseHas('sync_conflicts', ['kind' => 'flagged', 'invoice_id' => $result['server_id'], 'reason' => 'NEGATIVE_STOCK']);
    }

    /** Decision A: the price the cashier charged is kept, and the difference is flagged. */
    public function test_an_offline_sale_keeps_the_charged_price_and_flags_the_change(): void
    {
        $product = $this->makeProduct($this->store, ['selling_price' => '12.00']);
        $item = $this->saleItem(['paid_amount' => '20.00', 'payment_method' => 'cash', 'items' => [['product_id' => $product->id, 'quantity' => 2]]]);
        $item['charged'] = [['product_id' => $product->id, 'sale_unit' => null, 'unit_price' => '10.00']];

        $result = $this->batch([$item])->json('results.0');

        $this->assertSame('flagged', $result['status']);
        $this->assertSame(['PRICE_CHANGED'], $result['flags']);
        $invoice = Invoice::with('items')->find($result['server_id']);
        $this->assertSame('20.00', (string) $invoice->total_amount);
        $this->assertSame('10.00', (string) $invoice->items->first()->unit_price);
        $this->assertFalse($invoice->has_debt);
    }

    /** Online POST /sales still ignores any price the client sends. */
    public function test_online_sales_still_ignore_client_prices(): void
    {
        $product = $this->makeProduct($this->store, ['selling_price' => '12.00']);

        $this->actingAs($this->owner, 'sanctum')->postJson('/api/v1/sales', [
            'paid_amount' => '12.00',
            'payment_method' => 'cash',
            'items' => [['product_id' => $product->id, 'quantity' => 1, 'unit_price' => '1.00']],
            'charged' => [['product_id' => $product->id, 'unit_price' => '1.00']],
        ], ['Idempotency-Key' => (string) Str::uuid()])->assertCreated()->assertJsonPath('data.total_amount', '12.00');
    }

    /** D-03: a credit limit the phone could not see is recorded and flagged, not refused. */
    public function test_an_unseen_credit_limit_breach_is_recorded_and_flagged(): void
    {
        $customer = $this->makeCustomer($this->store);
        $customer->update(['credit_limit' => '15.00']);
        $this->makeCreditInvoice($this->store, $customer, '10.00');
        $product = $this->makeProduct($this->store);

        $result = $this->batch([$this->saleItem(['customer_id' => $customer->id, 'paid_amount' => '0', 'items' => [['product_id' => $product->id, 'quantity' => 1]]])], $this->employee)
            ->json('results.0');

        $this->assertSame('flagged', $result['status']);
        $this->assertSame(['CREDIT_LIMIT_EXCEEDED'], $result['flags']);
        $this->assertSame(2, Invoice::count());
        $this->assertDatabaseHas('sync_conflicts', ['kind' => 'flagged', 'reason' => 'CREDIT_LIMIT_EXCEEDED', 'customer_id' => $customer->id]);
    }

    /** D-26: an owner's override confirmed on the phone is audited as online, with no review item. */
    public function test_an_override_confirmed_offline_is_audited_and_not_flagged(): void
    {
        $customer = $this->makeCustomer($this->store);
        $customer->update(['credit_limit' => '5.00']);
        $product = $this->makeProduct($this->store);

        $result = $this->batch([$this->saleItem([
            'customer_id' => $customer->id,
            'paid_amount' => '0',
            'confirm_over_limit' => true,
            'items' => [['product_id' => $product->id, 'quantity' => 1]],
        ])])->json('results.0');

        $this->assertSame('applied', $result['status']);
        $this->assertSame(0, SyncConflict::count());
        $override = AuditLog::where('action', 'sale.credit_limit_overridden')->firstOrFail();
        $this->assertTrue($override->metadata['offline']);
    }

    /** A product or customer deactivated after the phone's refresh: recorded and flagged. */
    public function test_inactive_product_and_customer_are_flagged_not_refused(): void
    {
        $customer = $this->makeCustomer($this->store);
        $customer->forceFill(['status' => Customer::STATUS_INACTIVE])->save();
        $product = $this->makeProduct($this->store, ['status' => Product::STATUS_INACTIVE]);

        $result = $this->batch([$this->saleItem(['customer_id' => $customer->id, 'paid_amount' => '10.00', 'payment_method' => 'cash', 'items' => [['product_id' => $product->id, 'quantity' => 1]]])])
            ->json('results.0');

        $this->assertSame('flagged', $result['status']);
        $this->assertEqualsCanonicalizing(['CUSTOMER_INACTIVE', 'PRODUCT_INACTIVE'], $result['flags']);
    }

    /** BR-08: the sale and the payment carry the time they happened; arrival is `synced_at`. */
    public function test_occurred_at_is_kept_as_the_business_time(): void
    {
        Carbon::setTestNow('2026-10-29 12:00:00');
        $customer = $this->makeCustomer($this->store);
        $this->makeCreditInvoice($this->store, $customer, '50.00');
        $product = $this->makeProduct($this->store);

        $results = $this->batch([
            $this->saleItem(['paid_amount' => '10.00', 'payment_method' => 'cash', 'items' => [['product_id' => $product->id, 'quantity' => 1]]], at: '2026-10-28T21:30:00+02:00'),
            $this->paymentItem($customer, '5.00', at: '2026-10-28T22:00:00+02:00'),
        ])->json('results');

        $invoice = Invoice::find($results[0]['server_id']);
        $this->assertSame('2026-10-28 19:30:00', $invoice->created_at->utc()->format('Y-m-d H:i:s'));
        $this->assertSame('2026-10-29 12:00:00', $invoice->synced_at->utc()->format('Y-m-d H:i:s'));
        $payment = Payment::firstOrFail();
        $this->assertSame('2026-10-28 20:00:00', $payment->paid_at->utc()->format('Y-m-d H:i:s'));
        $this->assertNotNull($payment->synced_at);
    }

    /** A due date is checked against the day of the sale, not the day it synced. */
    public function test_due_date_is_checked_against_the_day_of_the_sale(): void
    {
        Carbon::setTestNow('2026-10-29 12:00:00');
        $customer = $this->makeCustomer($this->store);
        $product = $this->makeProduct($this->store);

        $result = $this->batch([$this->saleItem([
            'customer_id' => $customer->id,
            'paid_amount' => '0',
            'due_date' => '2026-10-28',
            'items' => [['product_id' => $product->id, 'quantity' => 1]],
        ], at: '2026-10-27T10:00:00+02:00')])->json('results.0');

        $this->assertSame('applied', $result['status']);
    }

    public function test_an_item_outside_the_time_window_is_held(): void
    {
        $product = $this->makeProduct($this->store);

        $result = $this->batch([$this->saleItem(['paid_amount' => '10.00', 'payment_method' => 'cash', 'items' => [['product_id' => $product->id, 'quantity' => 1]]], at: now()->subDays(40)->toIso8601String())])
            ->json('results.0');

        $this->assertSame('rejected_validation', $result['status']);
        $this->assertSame('OCCURRED_AT_OUT_OF_RANGE', $result['error']['code']);
        $this->assertSame(0, Invoice::count());
        $this->assertDatabaseHas('sync_conflicts', ['kind' => 'rejected', 'reason' => 'OCCURRED_AT_OUT_OF_RANGE']);
    }

    /** BR-10: an invalid item is stored for review and does not stop the items after it. */
    public function test_an_invalid_item_is_held_and_later_items_still_apply(): void
    {
        $other = $this->makeProduct($this->makeStore('Other'));
        $product = $this->makeProduct($this->store);

        $results = $this->batch([
            $this->saleItem(['paid_amount' => '10.00', 'payment_method' => 'cash', 'items' => [['product_id' => $other->id, 'quantity' => 1]]]),
            $this->saleItem(['paid_amount' => '10.00', 'payment_method' => 'cash', 'items' => [['product_id' => $product->id, 'quantity' => 1]]]),
        ])->json('results');

        $this->assertSame(['rejected_validation', 'applied'], array_column($results, 'status'));
        $this->assertSame('VALIDATION_FAILED', $results[0]['error']['code']);
        $this->assertSame(1, Invoice::count());
        $this->assertDatabaseHas('sync_conflicts', ['kind' => 'rejected', 'status' => 'open']);
    }

    public function test_another_stores_customer_is_held_as_not_found(): void
    {
        $foreign = $this->makeCustomer($this->makeStore('Other'));

        $result = $this->batch([$this->paymentItem($foreign, '5.00')])->json('results.0');

        $this->assertSame('rejected_validation', $result['status']);
        $this->assertSame('NOT_FOUND', $result['error']['code']);
        $this->assertDatabaseHas('sync_conflicts', ['reason' => 'NOT_FOUND', 'customer_id' => null]);
    }

    /** 04 §3.9: a technical failure stops the batch at that item; earlier items stay applied. */
    public function test_a_technical_failure_halts_the_batch_at_that_item(): void
    {
        $customer = $this->makeCustomer($this->store);
        $this->makeCreditInvoice($this->store, $customer, '50.00');
        $product = $this->makeProduct($this->store);
        $this->partialMock(SaleService::class, fn($mock) => $mock->shouldReceive('create')->andThrow(new RuntimeException('database went away')));
        $items = [
            $this->paymentItem($customer, '5.00'),
            $this->saleItem(['paid_amount' => '10.00', 'payment_method' => 'cash', 'items' => [['product_id' => $product->id, 'quantity' => 1]]]),
            $this->paymentItem($customer, '5.00'),
        ];

        $response = $this->batch($items)->assertOk();

        $this->assertSame(['applied'], array_column($response->json('results'), 'status'));
        $this->assertSame($items[1]['client_transaction_id'], $response->json('halted.client_transaction_id'));
        $this->assertSame(1, Payment::count());
        $this->assertSame(0, SyncConflict::count());
    }

    public function test_the_batch_envelope_is_validated(): void
    {
        $this->actingAs($this->owner, 'sanctum')->postJson('/api/v1/sync/batch', [
            'device_id' => 'phone-1',
            'items' => [['client_transaction_id' => 'not-a-uuid', 'seq' => 1, 'type' => 'return', 'occurred_at' => 'x', 'payload' => []]],
        ])->assertStatus(422)->assertJsonValidationErrors(['items.0.client_transaction_id', 'items.0.type', 'items.0.occurred_at', 'items.0.payload']);
    }

    /** TC-1102-01: the first bootstrap has every row; a delta only what changed since. */
    public function test_bootstrap_returns_everything_then_only_changes(): void
    {
        Carbon::setTestNow('2026-10-29 08:00:00');
        $products = [$this->makeProduct($this->store), $this->makeProduct($this->store), $this->makeProduct($this->store)];
        $customer = $this->makeCustomer($this->store);
        $quiet = $this->makeCustomer($this->store);
        $this->makeProduct($this->makeStore('Other'));

        // `since` is inclusive (a row changed in the same second is sent again, never missed).
        Carbon::setTestNow('2026-10-29 08:30:00');
        $first =$this->actingAs($this->employee, 'sanctum')->getJson('/api/v1/sync/bootstrap?entity=products&limit=2')->assertOk();
        $this->assertCount(2, $first->json('data'));
        $this->assertSame($products[1]->id, $first->json('next_after_id'));
        $rest = $this->getJson('/api/v1/sync/bootstrap?entity=products&limit=2&after_id=' . $first->json('next_after_id'))->assertOk();
        $this->assertSame([$products[2]->id], array_column($rest->json('data'), 'id'));
        $this->assertNull($rest->json('next_after_id'));
        $since = $first->json('server_time');

        Carbon::setTestNow('2026-10-29 09:00:00');
        $products[0]->update(['selling_price' => '11.00']);
        $this->makeCreditInvoice($this->store, $customer, '40.00');

        $delta = $this->getJson('/api/v1/sync/bootstrap?entity=products&since=' . urlencode($since))->assertOk();
        $this->assertSame([$products[0]->id], array_column($delta->json('data'), 'id'));
        $this->assertSame('11.00', $delta->json('data.0.selling_price'));

        $customers = $this->getJson('/api/v1/sync/bootstrap?entity=customers&since=' . urlencode($since))->assertOk();
        $this->assertSame([$customer->id], array_column($customers->json('data'), 'id'));
        $this->assertSame('40.00', $customers->json('data.0.balance'));
        $this->assertFalse($customers->json('data.0.deleted'));
        $this->assertNotContains($quiet->id, array_column($customers->json('data'), 'id'));
    }

    public function test_bootstrap_reports_deleted_customers(): void
    {
        Carbon::setTestNow('2026-10-29 08:00:00');
        $customer = $this->makeCustomer($this->store);
        $since = now()->addMinute()->toIso8601String();
        Carbon::setTestNow('2026-10-29 09:00:00');
        $customer->delete();

        $this->actingAs($this->owner, 'sanctum')
            ->getJson('/api/v1/sync/bootstrap?entity=customers&since=' . urlencode($since))
            ->assertOk()
            ->assertJsonPath('data.0.id', $customer->id)
            ->assertJsonPath('data.0.deleted', true);
    }

    /** SCR-W-18: owners and managers see the review list; employees do not. */
    public function test_only_owner_and_manager_see_the_review_list(): void
    {
        $customer = $this->makeCustomer($this->store);
        $this->batch([$this->paymentItem($customer, '5.00')]);

        $this->actingAs($this->employee, 'sanctum')->getJson('/api/v1/sync/conflicts')->assertForbidden();
        $this->actingAs($this->makeUser($this->store, 'manager'), 'sanctum')
            ->getJson('/api/v1/sync/conflicts')
            ->assertOk()
            ->assertJsonPath('open_count', 1)
            ->assertJsonPath('data.0.kind', 'conflict')
            ->assertJsonPath('data.0.customer.id', $customer->id)
            ->assertJsonPath('data.0.payment_method', 'cash')
            ->assertJsonPath('data.0.user.id', $this->owner->id);

        $other = $this->makeUser($this->makeStore('Other'), 'owner');
        $this->actingAs($other, 'sanctum')->getJson('/api/v1/sync/conflicts')->assertOk()->assertJsonPath('open_count', 0);
    }

    /** TC-1106-01: apply a held payment once it fits (a new debt appeared), audited. */
    public function test_a_held_payment_can_be_applied_when_it_fits(): void
    {
        $customer = $this->makeCustomer($this->store);
        $this->batch([$this->paymentItem($customer, '30.00', 'palpay')]);
        $conflict = SyncConflict::firstOrFail();

        $this->resolve($conflict, 'applied')->assertStatus(422)->assertJsonPath('code', 'NOTHING_TO_PAY');
        $this->assertTrue($conflict->fresh()->isOpen());

        $this->makeCreditInvoice($this->store, $customer, '50.00');
        $this->resolve($conflict, 'applied')->assertOk()->assertJsonPath('data.resolution', 'applied');

        $this->assertSame('30.00', (string) Payment::firstOrFail()->amount);
        $this->assertSame('palpay', Payment::firstOrFail()->method);
        $this->assertDatabaseHas('debts', ['customer_id' => $customer->id, 'remaining_amount' => '20.00']);
        $audit = AuditLog::where('action', 'sync.conflict_resolved')->firstOrFail();
        $this->assertSame('applied', $audit->metadata['resolution']);
        $this->assertNotNull($audit->metadata['payment_group_id']);
    }

    public function test_a_held_payment_can_be_refunded_or_voided_with_a_reason(): void
    {
        $customer = $this->makeCustomer($this->store);
        $this->batch([$this->paymentItem($customer, '30.00'), $this->paymentItem($customer, '12.00')]);
        [$refund, $void] = SyncConflict::orderBy('id')->get()->all();

        $this->resolve($refund, 'refunded')->assertOk();
        $this->resolve($void, 'voided')->assertStatus(422)->assertJsonValidationErrors('note');
        $this->resolve($void, 'voided', 'Entered on the wrong customer')->assertOk()->assertJsonPath('data.resolution_note', 'Entered on the wrong customer');

        $this->assertSame(0, Payment::count());
        $this->assertSame(2, AuditLog::where('action', 'sync.conflict_resolved')->count());
        $this->resolve($refund, 'refunded')->assertStatus(409)->assertJsonPath('code', 'SYNC_CONFLICT_RESOLVED');
    }

    public function test_a_flagged_sale_is_acknowledged_and_cannot_be_applied(): void
    {
        $product = $this->makeProduct($this->store, ['current_stock' => 0]);
        $this->batch([$this->saleItem(['paid_amount' => '10.00', 'payment_method' => 'cash', 'items' => [['product_id' => $product->id, 'quantity' => 1]]])]);
        $flagged = SyncConflict::firstOrFail();

        $this->resolve($flagged, 'applied')->assertStatus(422)->assertJsonPath('code', 'SYNC_RESOLUTION_NOT_ALLOWED');
        $this->resolve($flagged, 'acknowledged')->assertOk()->assertJsonPath('data.status', 'resolved');
    }

    public function test_employees_cannot_resolve(): void
    {
        $customer = $this->makeCustomer($this->store);
        $this->batch([$this->paymentItem($customer, '5.00')]);

        $this->actingAs($this->employee, 'sanctum')
            ->postJson('/api/v1/sync/conflicts/' . SyncConflict::firstOrFail()->id . '/resolve', ['resolution' => 'refunded'], ['Idempotency-Key' => (string) Str::uuid()])
            ->assertForbidden();
    }

    private function saleItem(array $payload, ?string $key = null, ?string $at = null): array
    {
        return [
            'client_transaction_id' => $key ?? (string) Str::uuid(),
            'seq' => ++$this->seq,
            'type' => 'sale',
            'occurred_at' => $at ?? now()->subMinutes(5)->toIso8601String(),
            'payload' => $payload,
        ];
    }

    private function paymentItem(Customer $customer, string $amount, string $method = 'cash', ?string $at = null): array
    {
        return [
            'client_transaction_id' => (string) Str::uuid(),
            'seq' => ++$this->seq,
            'type' => 'payment',
            'occurred_at' => $at ?? now()->subMinutes(5)->toIso8601String(),
            'payload' => ['customer_id' => $customer->id, 'method' => $method, 'amount' => $amount],
        ];
    }

    private function batch(array $items, ?User $as = null)
    {
        return $this->actingAs($as ?? $this->owner, 'sanctum')
            ->postJson('/api/v1/sync/batch', ['device_id' => 'phone-1', 'items' => $items]);
    }

    private function resolve(SyncConflict $conflict, string $resolution, ?string $note = null)
    {
        return $this->actingAs($this->owner, 'sanctum')->postJson(
            "/api/v1/sync/conflicts/{$conflict->id}/resolve",
            ['resolution' => $resolution, 'note' => $note],
            ['Idempotency-Key' => (string) Str::uuid()],
        );
    }
}
