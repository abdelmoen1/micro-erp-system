<?php

namespace Tests\Feature;

use App\Models\AuditLog;
use App\Models\Debt;
use App\Models\Invoice;
use App\Models\InvoiceItem;
use App\Models\Payment;
use App\Models\Product;
use App\Models\StockMovement;
use App\Models\Store;
use App\Models\User;
use App\Support\Money;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Route;
use RuntimeException;
use Tests\Support\BuildsShopData;
use Tests\TestCase;

/**
 * US-0501 cash sale, US-0502 credit / partial sale, US-0503 immutability and void, with weighed
 * goods (CR-13 modified, doc 15 §4) and the approved D-26 / D-27 rules.
 */
class SaleTest extends TestCase
{
    use BuildsShopData;
    use RefreshDatabase;

    private Store $store;
    private User $owner;

    protected function setUp(): void
    {
        parent::setUp();
        $this->store = $this->makeStore();
        $this->owner = $this->makeUser($this->store);
    }

    // ---------------------------------------------------------------- US-0501

    /** TC-0501-01: prices come from the database, stock moves, paid = total, no debt. */
    public function test_cash_sale_uses_database_prices_and_deducts_stock(): void
    {
        $tea = $this->makeProduct($this->store, ['selling_price' => '6.50', 'current_stock' => 10]);

        $response = $this->sell($this->owner, [
            'items' => [['product_id' => $tea->id, 'quantity' => 3, 'unit_price' => '0.01', 'total' => '0.01']],
            'paid_amount' => '19.50',
            'payment_method' => 'cash',
        ])->assertCreated();

        $response->assertJsonPath('data.status', 'active')
            ->assertJsonPath('data.total_amount', '19.50')
            ->assertJsonPath('data.paid_amount', '19.50')
            ->assertJsonPath('data.debt_amount', '0.00')
            ->assertJsonPath('data.has_debt', false)
            ->assertJsonPath('data.customer', null)
            ->assertJsonPath('data.debt', null)
            ->assertJsonPath('data.items.0.product_id', $tea->id)
            ->assertJsonPath('data.items.0.unit', 'piece')
            ->assertJsonPath('data.items.0.quantity', '3')
            ->assertJsonPath('data.items.0.unit_price', '6.50')
            ->assertJsonPath('data.items.0.line_total', '19.50')
            ->assertJsonPath('flags', [])
            ->assertJsonPath('meta.currency', 'ILS');

        $invoiceId = $response->json('data.id');
        $this->assertSame('7.000', $tea->fresh()->current_stock);
        $this->assertDatabaseHas('stock_movements', [
            'product_id' => $tea->id, 'type' => 'sale', 'quantity' => -3,
            'reference_type' => 'invoice', 'reference_id' => $invoiceId, 'created_by' => $this->owner->id,
        ]);
        $this->assertSame(0, Debt::count());
        $this->assertSame($this->owner->id, Invoice::find($invoiceId)->created_by);
        $this->assertSame('sale.created', AuditLog::where('entity_id', (string) $invoiceId)->sole()->action);
    }

    /** TC-0501-02, D-27 as approved: a shortfall is sold with a NEGATIVE_STOCK warning. */
    public function test_stock_shortfall_is_allowed_with_negative_stock_flag(): void
    {
        $water = $this->makeProduct($this->store, ['name' => 'Water', 'selling_price' => '2.00', 'current_stock' => 2]);
        $bread = $this->makeProduct($this->store, ['selling_price' => '1.00', 'current_stock' => 50]);

        $this->sell($this->owner, [
            'items' => [['product_id' => $water->id, 'quantity' => 5], ['product_id' => $bread->id, 'quantity' => 1]],
            'paid_amount' => '11.00',
            'payment_method' => 'cash',
        ])->assertCreated()
            ->assertJsonPath('flags', ['NEGATIVE_STOCK'])
            ->assertJsonCount(1, 'warnings')
            ->assertJsonPath('warnings.0.code', 'NEGATIVE_STOCK')
            ->assertJsonPath('warnings.0.product_id', $water->id)
            ->assertJsonPath('warnings.0.name', 'Water')
            ->assertJsonPath('warnings.0.balance_after', '-3');

        $this->assertSame('-3.000', $water->fresh()->current_stock);
        $this->assertSame(['NEGATIVE_STOCK'], AuditLog::where('action', 'sale.created')->sole()->metadata['flags']);
        $this->artisan('hisbah:verify-stock')->assertExitCode(0);
    }

    /** TC-0501-03: a failure after the lines are written leaves nothing behind. */
    public function test_sale_is_atomic_when_a_later_step_fails(): void
    {
        $product = $this->makeProduct($this->store, ['current_stock' => 10]);
        $customer = $this->makeCustomer($this->store);
        Debt::creating(fn() => throw new RuntimeException('Injected failure after the lines.'));

        $this->sell($this->owner, [
            'customer_id' => $customer->id,
            'items' => [['product_id' => $product->id, 'quantity' => 4]],
            'paid_amount' => '0',
        ])->assertStatus(500);

        $this->assertSame(0, Invoice::count());
        $this->assertSame(0, InvoiceItem::count());
        $this->assertSame(['opening'], StockMovement::pluck('type')->all(), 'Only the opening movement remains.');
        $this->assertSame('10.000', $product->fresh()->current_stock);
        $this->assertSame(0, AuditLog::where('action', 'sale.created')->count());
    }

    /** TC-0501-04 (D-07): a fully paid sale needs no customer. */
    public function test_walk_in_sale_without_customer(): void
    {
        $this->sell($this->makeUser($this->store, 'employee'), [
            'items' => [['product_id' => $this->makeProduct($this->store)->id, 'quantity' => 1]],
            'paid_amount' => '10.00',
            'payment_method' => 'cash',
        ])->assertCreated()->assertJsonPath('data.customer', null);

        $this->assertNull(Invoice::sole()->customer_id);
    }

    /** TC-0501-05: another store's product is unknown here; nothing is written. */
    public function test_foreign_or_inactive_product_is_rejected(): void
    {
        $foreign = $this->makeProduct($this->makeStore('Other'));
        $inactive = $this->makeProduct($this->store, ['status' => Product::STATUS_INACTIVE]);

        foreach ([$foreign, $inactive] as $product) {
            $this->sell($this->owner, [
                'items' => [['product_id' => $product->id, 'quantity' => 1]],
                'paid_amount' => '10.00',
                'payment_method' => 'cash',
            ])->assertUnprocessable()->assertJsonValidationErrors('items.0.product_id');
        }

        $this->assertSame(0, Invoice::count());
        $this->assertSame('10.000', $foreign->fresh()->current_stock);
    }

    /** TC-0501-06: a replay returns the first response and deducts stock once. */
    public function test_idempotent_replay_deducts_stock_once(): void
    {
        $product = $this->makeProduct($this->store, ['current_stock' => 10]);
        $key = $this->idem();
        $body = ['items' => [['product_id' => $product->id, 'quantity' => 2]], 'paid_amount' => '20.00', 'payment_method' => 'cash'];

        $first = $this->actingAs($this->owner, 'sanctum')->postJson('/api/v1/sales', $body, $key)->assertCreated();
        $second = $this->actingAs($this->owner, 'sanctum')->postJson('/api/v1/sales', $body, $key)->assertCreated();

        $this->assertSame($first->getContent(), $second->getContent());
        $second->assertHeader('Idempotent-Replay', 'true');
        $this->assertSame(1, Invoice::count());
        $this->assertSame('8.000', $product->fresh()->current_stock);
    }

    public function test_payment_rules_are_validated(): void
    {
        $product = $this->makeProduct($this->store);

        $this->sell($this->owner, ['items' => [['product_id' => $product->id, 'quantity' => 1]], 'paid_amount' => '10.01', 'payment_method' => 'cash'])
            ->assertUnprocessable()->assertJsonValidationErrors('paid_amount');
        $this->sell($this->owner, ['items' => [['product_id' => $product->id, 'quantity' => 1]], 'paid_amount' => '10.00'])
            ->assertUnprocessable()->assertJsonValidationErrors('payment_method');
        $this->sell($this->owner, ['items' => [['product_id' => $product->id, 'quantity' => 1], ['product_id' => $product->id, 'quantity' => 2]], 'paid_amount' => '0'])
            ->assertUnprocessable()->assertJsonValidationErrors('items.1.product_id');
        $this->sell($this->owner, ['items' => [['product_id' => $product->id, 'quantity' => 1]], 'paid_amount' => '10.00', 'payment_method' => 'cash', 'store_id' => 99])
            ->assertUnprocessable()->assertJsonValidationErrors('store_id');

        $this->assertSame(0, Invoice::count());
    }

    // ------------------------------------------------------- Weighed goods (CR-13)

    /** doc 15 §4: kg to the gram, pieces whole, line total rounded half-up to 2 decimals. */
    public function test_weighed_and_piece_lines_are_exact(): void
    {
        $almonds = $this->weighed('60.00', '10');
        $spice = $this->weighed('7.50', '1');
        $cans = $this->makeProduct($this->store, ['selling_price' => '5.00', 'current_stock' => 20]);

        $this->sell($this->owner, [
            'items' => [
                ['product_id' => $almonds->id, 'quantity' => '0.750'],
                ['product_id' => $spice->id, 'quantity' => '0.333'],
                ['product_id' => $cans->id, 'quantity' => '3'],
            ],
            'paid_amount' => '62.50',
            'payment_method' => 'cash',
        ])->assertCreated()
            ->assertJsonPath('data.items.0.unit', 'kg')
            ->assertJsonPath('data.items.0.quantity', '0.750')
            ->assertJsonPath('data.items.0.line_total', '45.00')
            // 0.333 × 7.50 = 2.4975 → 2.50 (half-up)
            ->assertJsonPath('data.items.1.line_total', '2.50')
            ->assertJsonPath('data.items.2.quantity', '3')
            ->assertJsonPath('data.total_amount', '62.50');

        $this->assertSame('9.250', $almonds->fresh()->current_stock);
        $this->assertSame('0.667', $spice->fresh()->current_stock);
        $this->assertSame('17.000', $cans->fresh()->current_stock);
        $this->artisan('hisbah:verify-stock')->assertExitCode(0);
    }

    public function test_quantity_must_fit_the_unit(): void
    {
        $piece = $this->makeProduct($this->store);
        $kg = $this->weighed('10.00', '5');

        $this->sell($this->owner, ['items' => [['product_id' => $piece->id, 'quantity' => '1.5']], 'paid_amount' => '0', 'customer_id' => $this->makeCustomer($this->store)->id])
            ->assertUnprocessable()->assertJsonValidationErrors('items.0.quantity');
        $this->sell($this->owner, ['items' => [['product_id' => $kg->id, 'quantity' => '0.7505']], 'paid_amount' => '0'])
            ->assertUnprocessable()->assertJsonValidationErrors('items.0.quantity');
        $this->sell($this->owner, ['items' => [['product_id' => $kg->id, 'quantity' => '0']], 'paid_amount' => '0'])
            ->assertUnprocessable()->assertJsonValidationErrors('items.0.quantity');

        $this->assertSame(0, Invoice::count());
    }

    // ---------------------------------------------------------------- US-0502

    /** TC-0502-01: nothing paid → one debt for the whole total. */
    public function test_full_credit_sale_creates_one_debt(): void
    {
        $customer = $this->makeCustomer($this->store);

        $this->sell($this->owner, [
            'customer_id' => $customer->id,
            'items' => [['product_id' => $this->makeProduct($this->store)->id, 'quantity' => 2]],
            'paid_amount' => '0',
        ])->assertCreated()
            ->assertJsonPath('data.payment_method', null)
            ->assertJsonPath('data.debt.amount', '20.00')
            ->assertJsonPath('data.debt.remaining_amount', '20.00');

        $this->assertDatabaseHas('debts', ['customer_id' => $customer->id, 'amount' => 20, 'remaining_amount' => 20, 'status' => 'unpaid']);
    }

    /** TC-0502-02, TC-0502-03 (SRS example, AC-03): 3 cartons at 15, paid 20, 25 on credit. */
    public function test_partial_sale_matches_the_srs_example_and_is_consistent(): void
    {
        $customer = $this->makeCustomer($this->store);
        $carton = $this->makeProduct($this->store, ['selling_price' => '15.00', 'current_stock' => 10]);

        $response = $this->sell($this->owner, [
            'customer_id' => $customer->id,
            'items' => [['product_id' => $carton->id, 'quantity' => 3]],
            'paid_amount' => '20.00',
            'payment_method' => 'cash',
        ])->assertCreated()
            ->assertJsonPath('data.total_amount', '45.00')
            ->assertJsonPath('data.paid_amount', '20.00')
            ->assertJsonPath('data.debt_amount', '25.00')
            ->assertJsonPath('data.debt.amount', '25.00')
            ->assertJsonPath('data.debt.remaining_amount', '25.00')
            ->assertJsonPath('data.debt.status', 'unpaid')
            ->assertJsonPath('data.debt.customer_id', $customer->id);

        $invoice = Invoice::with('debt', 'items')->findOrFail($response->json('data.id'));
        $this->assertSame('45.00', $invoice->total_amount);
        $this->assertSame($invoice->total_amount, Money::sum($invoice->items->pluck('total')));
        $this->assertSame('25.00', Money::sub($invoice->total_amount, $invoice->paid_amount));
        $this->assertSame('25.00', $invoice->debt->amount);
        $this->assertSame($customer->id, $invoice->debt->customer_id);
        $this->assertSame('7.000', $carton->fresh()->current_stock);
    }

    /** TC-0502-04, D-26 as approved: employee refused; owner / manager confirm, and it is audited. */
    public function test_credit_limit_is_enforced_by_role(): void
    {
        $customer = $this->makeCustomer($this->store);
        $customer->update(['credit_limit' => '100.00']);
        $this->makeCreditInvoice($this->store, $customer, '90.00');
        $product = $this->makeProduct($this->store, ['selling_price' => '25.00']);
        $body = ['customer_id' => $customer->id, 'items' => [['product_id' => $product->id, 'quantity' => 1]], 'paid_amount' => '0'];
        $employee = $this->makeUser($this->store, 'employee');
        $manager = $this->makeUser($this->store, 'manager');

        foreach ([$body, $body + ['confirm_over_limit' => true]] as $attempt) {
            $this->sell($employee, $attempt)->assertUnprocessable()
                ->assertJsonPath('code', 'CREDIT_LIMIT_EXCEEDED')
                ->assertJsonPath('details.credit_limit', '100.00')
                ->assertJsonPath('details.outstanding', '90.00')
                ->assertJsonPath('details.new_debt', '25.00')
                ->assertJsonPath('details.balance_after', '115.00')
                ->assertJsonPath('details.can_override', false);
        }

        $this->sell($manager, $body)->assertUnprocessable()
            ->assertJsonPath('code', 'CREDIT_LIMIT_CONFIRMATION_REQUIRED')
            ->assertJsonPath('details.can_override', true);

        $this->assertSame(1, Invoice::count(), 'Refused attempts write nothing.');
        $this->assertSame('10.000', $product->fresh()->current_stock);

        $saleId = $this->sell($manager, $body + ['confirm_over_limit' => true])->assertCreated()->json('data.id');

        $override = AuditLog::where('action', 'sale.credit_limit_overridden')->sole();
        $this->assertSame((string) $saleId, $override->entity_id);
        $this->assertSame($manager->id, $override->user_id);
        $this->assertSame('115.00', $override->metadata['balance_after']);
    }

    public function test_sale_within_the_credit_limit_needs_no_confirmation(): void
    {
        $customer = $this->makeCustomer($this->store);
        $customer->update(['credit_limit' => '100.00']);
        $this->makeCreditInvoice($this->store, $customer, '75.00');

        $this->sell($this->makeUser($this->store, 'employee'), [
            'customer_id' => $customer->id,
            'items' => [['product_id' => $this->makeProduct($this->store, ['selling_price' => '25.00'])->id, 'quantity' => 1]],
            'paid_amount' => '0',
        ])->assertCreated();

        $this->assertSame(0, AuditLog::where('action', 'sale.credit_limit_overridden')->count());
    }

    /** TC-0502-05: an unpaid remainder needs a customer. */
    public function test_partial_sale_requires_a_customer(): void
    {
        $this->sell($this->owner, [
            'items' => [['product_id' => $this->makeProduct($this->store)->id, 'quantity' => 1]],
            'paid_amount' => '4.00',
            'payment_method' => 'cash',
        ])->assertUnprocessable()->assertJsonValidationErrors('customer_id');

        $this->assertSame(0, Invoice::count());
    }

    /** TC-0502-06: due date stored on the debt; never in the past; only when a debt results. */
    public function test_due_date_rules(): void
    {
        $customer = $this->makeCustomer($this->store);
        $product = $this->makeProduct($this->store);
        $credit = ['customer_id' => $customer->id, 'items' => [['product_id' => $product->id, 'quantity' => 1]], 'paid_amount' => '0'];

        $this->sell($this->owner, $credit + ['due_date' => now()->subDays(2)->toDateString()])
            ->assertUnprocessable()->assertJsonValidationErrors('due_date');
        $this->sell($this->owner, ['items' => [['product_id' => $product->id, 'quantity' => 1]], 'paid_amount' => '10.00', 'payment_method' => 'cash', 'due_date' => now()->addDays(7)->toDateString()])
            ->assertUnprocessable()->assertJsonValidationErrors('due_date');

        $due = now()->addDays(30)->toDateString();
        $this->sell($this->owner, $credit + ['due_date' => $due])->assertCreated()->assertJsonPath('data.debt.due_date', $due);
        $this->assertSame($due, Debt::sole()->due_date->toDateString());
    }

    // ---------------------------------------------------------------- US-0503

    /** TC-0503-01, TC-0503-06: financial fields are rejected for every role; notes for owner / manager. */
    public function test_sales_are_final_and_only_notes_change(): void
    {
        $sale = $this->creditSale();
        $other = $this->makeCustomer($this->store);
        $attempts = [
            ['items' => [['product_id' => 1, 'quantity' => 9]]],
            ['total_amount' => '1.00'],
            ['paid_amount' => '20.00'],
            ['customer_id' => $other->id],
            ['payment_method' => 'cash', 'has_debt' => false],
        ];

        foreach (['owner', 'manager'] as $role) {
            $actor = $role === 'owner' ? $this->owner : $this->makeUser($this->store, $role);

            foreach ($attempts as $body) {
                $this->actingAs($actor, 'sanctum')->patchJson("/api/v1/sales/{$sale->id}", $body + ['notes' => 'x'])
                    ->assertUnprocessable()->assertJsonPath('code', 'INVOICE_IMMUTABLE');
            }

            $this->actingAs($actor, 'sanctum')->patchJson("/api/v1/sales/{$sale->id}", ['notes' => "Checked by {$role}"])
                ->assertOk()->assertJsonPath('data.notes', "Checked by {$role}");
        }

        $employee = $this->makeUser($this->store, 'employee');
        foreach ([...$attempts, ['notes' => 'x']] as $body) {
            $this->actingAs($employee, 'sanctum')->patchJson("/api/v1/sales/{$sale->id}", $body)->assertForbidden();
        }

        $fresh = $sale->fresh();
        $this->assertSame('30.00', $fresh->total_amount);
        $this->assertSame('0.00', $fresh->paid_amount);
        $this->assertSame($sale->customer_id, $fresh->customer_id);
        $this->assertSame('Checked by manager', $fresh->notes);
    }

    /** TC-0503-02 */
    public function test_employee_cannot_void(): void
    {
        $sale = $this->creditSale();

        $this->sell($this->makeUser($this->store, 'employee'), ['reason' => 'x'], "/api/v1/sales/{$sale->id}/void")
            ->assertForbidden();
        $this->assertSame(Invoice::STATUS_ACTIVE, $sale->fresh()->status);
    }

    /** TC-0503-03: live payments or returns block the void with a 409. */
    public function test_void_is_blocked_by_live_payments_and_returns(): void
    {
        $sale = $this->creditSale();
        $this->actingAs($this->owner, 'sanctum')
            ->postJson('/api/v1/payments', ['debt_id' => $sale->debt->id, 'amount' => '5.00', 'method' => 'cash'], $this->idem())
            ->assertCreated();

        $this->void($sale)->assertStatus(409)->assertJsonPath('code', 'INVOICE_HAS_PAYMENTS');

        $this->actingAs($this->owner, 'sanctum')
            ->postJson('/api/v1/payments/' . Payment::sole()->id . '/reverse', ['reason' => 'Wrong'], $this->idem())
            ->assertOk();
        $this->void($sale)->assertOk()->assertJsonPath('data.status', 'voided');

        $returned = $this->creditSale();
        $returned->items()->update(['returned_quantity' => 1]);
        $this->void($returned)->assertStatus(409)->assertJsonPath('code', 'INVOICE_HAS_RETURNS');
    }

    /** TC-0503-04 + the S2 demo: 0.750 kg + 3 pieces, partial payment, then void. */
    public function test_void_restores_exact_stock_cancels_debt_and_audits(): void
    {
        $customer = $this->makeCustomer($this->store);
        $almonds = $this->weighed('60.00', '2');
        $cans = $this->makeProduct($this->store, ['selling_price' => '5.00', 'current_stock' => 1]);

        $sale = $this->sell($this->owner, [
            'customer_id' => $customer->id,
            'items' => [['product_id' => $almonds->id, 'quantity' => '0.750'], ['product_id' => $cans->id, 'quantity' => 3]],
            'paid_amount' => '20.00',
            'payment_method' => 'cash',
        ])->assertCreated()
            ->assertJsonPath('data.total_amount', '60.00')
            ->assertJsonPath('data.debt.remaining_amount', '40.00')
            ->assertJsonPath('flags', ['NEGATIVE_STOCK']);
        $this->assertSame('1.250', $almonds->fresh()->current_stock);
        $this->assertSame('-2.000', $cans->fresh()->current_stock);

        $invoiceId = $sale->json('data.id');
        $this->void(Invoice::find($invoiceId), 'Customer cancelled')->assertOk()
            ->assertJsonPath('data.status', 'voided')
            ->assertJsonPath('data.void_reason', 'Customer cancelled')
            ->assertJsonPath('data.voided_by', $this->owner->id)
            ->assertJsonPath('data.debt.status', 'cancelled')
            ->assertJsonPath('data.debt.remaining_amount', '0.00');

        $this->assertSame('2.000', $almonds->fresh()->current_stock);
        $this->assertSame('1.000', $cans->fresh()->current_stock);
        $this->assertSame(2, StockMovement::where('type', 'sale_void')->where('reference_id', $invoiceId)->count());
        $this->assertDatabaseHas('invoices', ['id' => $invoiceId, 'total_amount' => 60, 'paid_amount' => 20]);
        $this->assertSame(2, InvoiceItem::where('invoice_id', $invoiceId)->count(), 'Nothing is hard-deleted.');
        $this->assertSame(1, Debt::where('invoice_id', $invoiceId)->count());

        $audit = AuditLog::where('action', 'sale.voided')->sole();
        $this->assertSame((string) $invoiceId, $audit->entity_id);
        $this->assertSame('Customer cancelled', $audit->metadata['reason']);
        $this->assertSame('40.00', $audit->metadata['debt_amount_cancelled']);
        $this->assertEqualsCanonicalizing(
            [['product_id' => $almonds->id, 'quantity' => '0.750'], ['product_id' => $cans->id, 'quantity' => '3']],
            $audit->metadata['stock_restored'],
        );
        $this->artisan('hisbah:verify-stock')->assertExitCode(0);
    }

    /** A second void (new key) is a 409 and reverses nothing; a replay (same key) repeats the 200. */
    public function test_void_happens_once(): void
    {
        $product = $this->makeProduct($this->store, ['current_stock' => 10]);
        $sale = $this->creditSale($product, 3);
        $key = $this->idem();

        $first = $this->actingAs($this->owner, 'sanctum')->postJson("/api/v1/sales/{$sale->id}/void", ['reason' => 'Twice'], $key)->assertOk();
        $replay = $this->actingAs($this->owner, 'sanctum')->postJson("/api/v1/sales/{$sale->id}/void", ['reason' => 'Twice'], $key)->assertOk();
        $this->assertSame($first->getContent(), $replay->getContent());

        $this->void($sale)->assertStatus(409)->assertJsonPath('code', 'INVOICE_ALREADY_VOIDED');
        $this->actingAs($this->owner, 'sanctum')->postJson("/api/v1/invoices/{$sale->id}/void", ['reason' => 'Alias'], $this->idem())
            ->assertStatus(409)->assertJsonPath('code', 'INVOICE_ALREADY_VOIDED');

        $this->assertSame('10.000', $product->fresh()->current_stock);
        $this->assertSame(1, StockMovement::where('type', 'sale_void')->count());
        $this->assertSame(1, AuditLog::where('action', 'sale.voided')->count());
    }

    /** TC-0503-05 (DEF-01): no delete route exists for sales or invoices, and no legacy create. */
    public function test_no_delete_or_legacy_create_route_exists(): void
    {
        $routes = collect(Route::getRoutes()->getRoutes())
            ->flatMap(fn($route) => collect($route->methods())->map(fn($method) => "{$method} {$route->uri()}"));

        foreach (['DELETE api/v1/sales/{invoice}', 'DELETE api/v1/invoices/{invoice}', 'POST api/v1/invoices'] as $removed) {
            $this->assertNotContains($removed, $routes->all(), "{$removed} must not exist.");
        }

        $sale = $this->creditSale();
        $this->actingAs($this->owner, 'sanctum')->deleteJson("/api/v1/sales/{$sale->id}")->assertStatus(405);
        $this->assertDatabaseHas('invoices', ['id' => $sale->id]);
    }

    public function test_opening_debt_is_not_voidable(): void
    {
        $opening = $this->actingAs($this->owner, 'sanctum')
            ->postJson('/api/v1/debts', ['customer_id' => $this->makeCustomer($this->store)->id, 'amount' => '50.00'], $this->idem())
            ->assertCreated()->json('data.id');

        $this->void(Invoice::find($opening))->assertStatus(409)->assertJsonPath('code', 'INVOICE_NOT_VOIDABLE');
    }

    /** A voided sale no longer counts, and its cancelled debt cannot be paid. */
    public function test_voided_sale_leaves_dashboard_and_debt_cannot_be_paid(): void
    {
        $sale = $this->creditSale();
        $this->actingAs($this->owner, 'sanctum')->getJson('/api/v1/dashboard?period=today')->assertOk()
            ->assertJsonPath('data.invoices.total', 1)
            ->assertJsonPath('data.debts.total_remaining', '30.00');

        $this->void($sale)->assertOk();

        $this->actingAs($this->owner, 'sanctum')->getJson('/api/v1/dashboard?period=today')->assertOk()
            ->assertJsonPath('data.invoices.total', 0)
            ->assertJsonPath('data.debts.total_debt', '0.00')
            ->assertJsonPath('data.debts.total_remaining', '0.00');
        $this->actingAs($this->owner, 'sanctum')
            ->postJson('/api/v1/payments', ['debt_id' => $sale->debt->id, 'amount' => '5.00', 'method' => 'cash'], $this->idem())
            ->assertUnprocessable()->assertJsonPath('code', 'DEBT_ALREADY_PAID');
    }

    public function test_another_stores_sale_is_not_found(): void
    {
        $theirs = $this->makeStore('Other');
        $sale = $this->makeCreditInvoice($theirs, $this->makeCustomer($theirs));

        $this->actingAs($this->owner, 'sanctum')->getJson("/api/v1/sales/{$sale->id}")->assertNotFound();
        $this->void($sale)->assertNotFound();
        $this->assertSame(Invoice::STATUS_ACTIVE, $sale->fresh()->status);
    }

    // ---------------------------------------------------------------- helpers

    private function sell(User $actor, array $body, string $uri = '/api/v1/sales')
    {
        $response = $this->actingAs($actor, 'sanctum')->postJson($uri, $body, $this->idem());
        $this->app['auth']->forgetGuards();

        return $response;
    }

    private function void(Invoice $sale, string $reason = 'Mistake')
    {
        return $this->sell($this->owner, ['reason' => $reason], "/api/v1/sales/{$sale->id}/void");
    }

    private function weighed(string $pricePerKg, string $stock): Product
    {
        $id = $this->actingAs($this->owner, 'sanctum')->postJson('/api/v1/products', [
            'name' => 'Weighed ' . $pricePerKg,
            'unit' => 'kg',
            'selling_price' => $pricePerKg,
            'current_stock' => $stock,
        ])->assertCreated()->assertJsonPath('product.unit', 'kg')->json('product.id');

        return Product::findOrFail($id);
    }

    /** A product-based credit sale of 30.00 (3 × 10.00) through the API. */
    private function creditSale(?Product $product = null, int $quantity = 3): Invoice
    {
        $id = $this->sell($this->owner, [
            'customer_id' => $this->makeCustomer($this->store)->id,
            'items' => [['product_id' => ($product ?? $this->makeProduct($this->store))->id, 'quantity' => $quantity]],
            'paid_amount' => '0',
        ])->assertCreated()->json('data.id');

        return Invoice::with('debt')->findOrFail($id);
    }
}
