<?php

namespace Tests\Feature;

use App\Models\Debt;
use App\Models\Store;
use App\Models\User;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use RuntimeException;
use Tests\Support\BuildsShopData;
use Tests\TestCase;

/**
 * US-0701 (D-10): debts.customer_id (backfilled), due_date and return_credit.
 */
class DebtSchemaExtensionTest extends TestCase
{
    use BuildsShopData;
    use RefreshDatabase;

    private const MIGRATION = 'database/migrations/2026_10_20_000004_add_customer_due_date_and_return_credit_to_debts_table.php';

    private Store $store;
    private User $owner;

    protected function setUp(): void
    {
        parent::setUp();
        $this->store = $this->makeStore();
        $this->owner = $this->makeUser($this->store);
    }

    /** TC-0701-01: every legacy debt gets its invoice's customer; the report shows 100 %. */
    public function test_backfill_matches_every_debt_to_its_invoice_customer(): void
    {
        $migration = $this->migration();
        $migration->down();
        $this->assertFalse(Schema::hasColumn('debts', 'customer_id'), 'down() removes the columns (rollback is tested).');

        $other = $this->makeStore('Other');
        $legacy = [];
        foreach ([[$this->store, '100.00'], [$this->store, '45.50'], [$other, '12.00']] as [$store, $total]) {
            $customer = $this->makeCustomer($store);
            $legacy[$this->legacyCreditInvoice($store, $customer->id, $total)] = $customer->id;
        }

        $migration->up();

        $this->assertSame(3, Debt::count());
        foreach ($legacy as $debtId => $customerId) {
            $this->assertSame($customerId, Debt::find($debtId)->customer_id);
        }
        $this->assertNull(Debt::first()->due_date);
        $this->assertSame('0.00', Debt::first()->return_credit);

        $this->artisan('hisbah:verify-debts')
            ->expectsOutputToContain('Backfill complete: 3 of 3 debts (100%).')
            ->assertExitCode(0);
    }

    /** A debt whose invoice has no customer is never guessed: the migration stops and names it. */
    public function test_backfill_refuses_to_guess_a_missing_customer(): void
    {
        $migration = $this->migration();
        $migration->down();
        $orphan = $this->legacyCreditInvoice($this->store, null, '30.00');

        try {
            $migration->up();
            $this->fail('The migration must stop on an unresolved debt.');
        } catch (RuntimeException $e) {
            $this->assertStringContainsString("debts without a customer on their invoice: {$orphan}", $e->getMessage());
        }
    }

    /** TC-0701-02: an opening debt keeps its due date; a past date is allowed for legacy debts. */
    public function test_opening_debt_stores_due_date_and_customer(): void
    {
        $customer = $this->makeCustomer($this->store);
        $past = now()->subMonth()->toDateString();

        $this->actingAs($this->owner, 'sanctum')
            ->postJson('/api/v1/debts', ['customer_id' => $customer->id, 'amount' => '80.00', 'due_date' => $past], $this->idem())
            ->assertCreated()
            ->assertJsonPath('data.debt.due_date', $past)
            ->assertJsonPath('data.debt.customer_id', $customer->id);

        $this->actingAs($this->owner, 'sanctum')
            ->postJson('/api/v1/debts', ['customer_id' => $customer->id, 'amount' => '5.00', 'due_date' => '20-10-2026'], $this->idem())
            ->assertUnprocessable()->assertJsonValidationErrors('due_date');
    }

    /** TC-0701-03: the debt resource carries every field the statement and lists need. */
    public function test_debt_details_fields(): void
    {
        $customer = $this->makeCustomer($this->store);
        $debt = $this->makeCreditInvoice($this->store, $customer, '100.00')->debt;
        $debt->update(['due_date' => '2026-11-30']);
        $debt->payments()->create(['amount' => '40.00', 'method' => 'cash', 'paid_at' => now()]);
        app(\App\Services\DebtLedger::class)->recalculate($debt);

        $this->actingAs($this->owner, 'sanctum')->getJson("/api/v1/debts/{$debt->id}")->assertOk()
            ->assertJsonPath('data.amount', '100.00')
            ->assertJsonPath('data.total_payments', '40.00')
            ->assertJsonPath('data.return_credit', '0.00')
            ->assertJsonPath('data.remaining_amount', '60.00')
            ->assertJsonPath('data.customer_id', $customer->id)
            ->assertJsonPath('data.customer.id', $customer->id)
            ->assertJsonPath('data.invoice_id', $debt->invoice_id)
            ->assertJsonPath('data.due_date', '2026-11-30')
            ->assertJsonPath('data.status', 'partially_paid')
            ->assertJsonStructure(['data' => ['created_at']]);
    }

    /** Rule 5 (05 §1.3): remaining = amount − return_credit − Σ live payments. */
    public function test_ledger_subtracts_return_credit(): void
    {
        $debt = $this->makeCreditInvoice($this->store, $this->makeCustomer($this->store), '100.00')->debt;
        $debt->update(['return_credit' => '30.00']);
        $debt->payments()->create(['amount' => '20.00', 'method' => 'cash', 'paid_at' => now()]);

        app(\App\Services\DebtLedger::class)->recalculate($debt);

        $this->assertSame('50.00', $debt->fresh()->remaining_amount);
        $this->assertSame('partially_paid', $debt->fresh()->status);
    }

    private function migration(): Migration
    {
        return require base_path(self::MIGRATION);
    }

    /** A pre-US-0701 credit invoice and debt, written the way the old code did. Returns the debt id. */
    private function legacyCreditInvoice(Store $store, ?int $customerId, string $total): int
    {
        $invoiceId = DB::table('invoices')->insertGetId([
            'store_id' => $store->id, 'customer_id' => $customerId, 'total_amount' => $total,
            'has_debt' => true, 'source' => 'sale', 'created_at' => now(), 'updated_at' => now(),
        ]);

        return DB::table('debts')->insertGetId([
            'store_id' => $store->id, 'invoice_id' => $invoiceId, 'amount' => $total,
            'remaining_amount' => $total, 'status' => 'unpaid', 'created_at' => now(), 'updated_at' => now(),
        ]);
    }
}
