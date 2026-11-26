<?php

namespace Tests\Feature;

use App\Models\AuditLog;
use App\Models\Debt;
use App\Models\Invoice;
use App\Models\Product;
use App\Models\PurchaseInvoice;
use App\Models\PurchaseReturn;
use App\Models\ReceivingAccount;
use App\Models\SaleReturn;
use App\Models\StockMovement;
use App\Models\Store;
use App\Models\Supplier;
use App\Models\SupplierPayment;
use App\Models\User;
use App\Services\SaleService;
use App\Services\StockService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Testing\TestResponse;
use Tests\Support\BuildsShopData;
use Tests\TestCase;

/**
 * Safe delete, archive and void (2026-11-27): unused records may be deleted, records with history
 * are archived, and posted documents are voided with a reason — their effects reversed exactly
 * once, inside one transaction, or not at all.
 */
class SafeCancelTest extends TestCase
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

    // ── Products ────────────────────────────────────────────────────────────────────────────

    /** 1. A product added by mistake (only its opening row) is deleted for good, and audited. */
    public function test_an_unused_product_is_deleted_for_good(): void
    {
        $id = $this->as($this->owner)->postJson('/api/v1/products', [
            'name' => 'منتج بالخطأ', 'selling_price' => '5.00', 'current_stock' => 7,
        ])->assertCreated()->json('product.id');

        $this->as($this->owner)->getJson("/api/v1/products/{$id}")->assertJsonPath('data.deletable', true);
        $this->as($this->owner)->deleteJson("/api/v1/products/{$id}", ['reason' => 'أضيف مرتين'])->assertOk();

        $this->assertDatabaseMissing('products', ['id' => $id]);
        $this->assertDatabaseMissing('stock_movements', ['product_id' => $id]);
        $audit = AuditLog::where('action', 'product.deleted')->sole();
        $this->assertSame('منتج بالخطأ', $audit->metadata['snapshot']['name']);
        $this->assertSame('أضيف مرتين', $audit->metadata['reason']);
    }

    /** 2. A product on a past sale is refused (409 PRODUCT_IN_USE) and nothing changes. */
    public function test_a_product_on_a_historical_invoice_cannot_be_deleted(): void
    {
        $tea = $this->makeProduct($this->store);
        $this->sale(['items' => [['product_id' => $tea->id, 'quantity' => 1]], 'paid_amount' => '10.00', 'payment_method' => 'cash']);

        $this->as($this->owner)->getJson("/api/v1/products/{$tea->id}")->assertJsonPath('data.deletable', false);
        $this->as($this->owner)->deleteJson("/api/v1/products/{$tea->id}")
            ->assertStatus(409)
            ->assertJsonPath('code', 'PRODUCT_IN_USE');

        $this->assertDatabaseHas('products', ['id' => $tea->id, 'status' => 'active']);
        $this->assertSame(2, StockMovement::where('product_id', $tea->id)->count());
    }

    /** A manual adjustment is history too: the product can only be archived. */
    public function test_a_product_with_stock_history_cannot_be_deleted(): void
    {
        $tea = $this->makeProduct($this->store);
        $this->as($this->owner)->postJson('/api/v1/stock-adjustments', ['product_id' => $tea->id, 'quantity' => 2, 'reason' => 'جرد'], $this->idem())->assertCreated();

        $this->as($this->owner)->deleteJson("/api/v1/products/{$tea->id}")->assertStatus(409);
    }

    /** 3 + 15. An archived product leaves the POS list but stays on its invoices and in reports. */
    public function test_a_referenced_product_is_archived_and_stays_on_its_invoices(): void
    {
        $tea = $this->makeProduct($this->store, ['name' => 'شاي أحمر']);
        $sale = $this->sale(['items' => [['product_id' => $tea->id, 'quantity' => 2]], 'paid_amount' => '20.00', 'payment_method' => 'cash']);

        $this->as($this->owner)->postJson("/api/v1/products/{$tea->id}/deactivate")->assertOk()->assertJsonPath('product.status', 'inactive');

        $this->as($this->owner)->getJson('/api/v1/products')->assertJsonMissing(['id' => $tea->id]);
        $this->as($this->owner)->getJson('/api/v1/products?status=all')->assertJsonFragment(['id' => $tea->id, 'status' => 'inactive']);
        $this->as($this->owner)->getJson("/api/v1/sales/{$sale->id}")
            ->assertJsonPath('data.items.0.item_name', 'شاي أحمر')
            ->assertJsonPath('data.total_amount', '20.00');
    }

    // ── Draft (held) invoices ───────────────────────────────────────────────────────────────

    /** 4. A line of a held invoice is removed: totals are worked out again and its stock freed. */
    public function test_a_line_is_removed_from_a_held_invoice_and_totals_recalculate(): void
    {
        [$held, $tea, $sugar] = $this->heldInvoice();
        $sugarLine = collect($held['items'])->firstWhere('product_id', $sugar->id);

        $this->as($this->owner)->deleteJson("/api/v1/suspended-invoices/{$held['id']}/items/{$sugarLine['id']}")
            ->assertOk()
            ->assertJsonCount(1, 'data.items')
            ->assertJsonPath('data.subtotal', '30.00')
            ->assertJsonPath('data.total_amount', '30.00');

        $this->assertDatabaseMissing('inventory_reservations', ['product_id' => $sugar->id, 'status' => 'active']);
        $this->assertDatabaseHas('suspended_invoice_events', ['suspended_invoice_id' => $held['id'], 'event' => 'item_removed']);

        // The freed sugar can now be sold; the tea stays reserved.
        $this->sale(['items' => [['product_id' => $sugar->id, 'quantity' => 10]], 'paid_amount' => '50.00', 'payment_method' => 'cash']);

        // The last line cannot go: an empty invoice could otherwise be confirmed.
        $teaLine = collect($held['items'])->firstWhere('product_id', $tea->id);
        $this->as($this->owner)->deleteJson("/api/v1/suspended-invoices/{$held['id']}/items/{$teaLine['id']}")
            ->assertStatus(422)
            ->assertJsonPath('code', 'SUSPENDED_INVOICE_LAST_LINE');
    }

    /** 5. A confirmed invoice's lines cannot be removed; a sale has no line-delete route at all. */
    public function test_lines_cannot_be_removed_from_a_confirmed_invoice(): void
    {
        [$held] = $this->heldInvoice();
        $this->as($this->owner)->postJson("/api/v1/suspended-invoices/{$held['id']}/confirm", [], $this->idem())->assertOk();

        $this->as($this->owner)->deleteJson("/api/v1/suspended-invoices/{$held['id']}/items/{$held['items'][0]['id']}")
            ->assertStatus(409)
            ->assertJsonPath('code', 'SUSPENDED_INVOICE_NOT_OPEN');
        $this->assertSame(2, \App\Models\SuspendedInvoiceItem::where('suspended_invoice_id', $held['id'])->count());

        $sale = Invoice::latest('id')->firstOrFail();
        $status = $this->as($this->owner)->deleteJson("/api/v1/sales/{$sale->id}/items/{$sale->items()->first()->id}")->status();
        $this->assertContains($status, [404, 405]);
        $this->assertSame(2, $sale->items()->count());
    }

    /** Staff may only remove lines from invoices they held themselves. */
    public function test_an_employee_cannot_remove_lines_from_someone_elses_held_invoice(): void
    {
        [$held] = $this->heldInvoice();
        $employee = $this->makeUser($this->store, 'employee');

        $this->as($employee)->deleteJson("/api/v1/suspended-invoices/{$held['id']}/items/{$held['items'][0]['id']}")->assertForbidden();
    }

    // ── Customer returns ────────────────────────────────────────────────────────────────────

    /** 6 + 8 + 9. A customer return made by mistake is cancelled: stock, debt and lines go back. */
    public function test_a_mistaken_customer_return_is_cancelled_and_every_effect_reversed(): void
    {
        $customer = $this->makeCustomer($this->store);
        $oil = $this->makeProduct($this->store, ['selling_price' => '20.00', 'current_stock' => 10]);
        $sale = $this->sale(['customer_id' => $customer->id, 'items' => [['product_id' => $oil->id, 'quantity' => 5]], 'paid_amount' => '0']);
        $return = $this->customerReturn($sale, 2);

        $this->assertSame('7.000', $oil->fresh()->current_stock);
        $this->assertSame('60.00', Debt::where('invoice_id', $sale->id)->sole()->remaining_amount);

        $this->voidSaleReturn($return)
            ->assertOk()
            ->assertJsonPath('data.status', 'voided')
            ->assertJsonPath('data.void_reason', 'سُجّل بالخطأ')
            ->assertJsonPath('data.voided_by_name', $this->owner->name);

        $debt = Debt::where('invoice_id', $sale->id)->sole();
        $this->assertSame('0.00', $debt->return_credit);
        $this->assertSame('100.00', $debt->remaining_amount);
        $this->assertSame('unpaid', $debt->status);
        $this->assertSame('5.000', $oil->fresh()->current_stock);
        $this->assertSame('0.000', $sale->items()->first()->returned_quantity);
        $this->assertDatabaseHas('stock_movements', ['product_id' => $oil->id, 'type' => 'sale_return_void', 'quantity' => -2, 'reference_type' => 'sale_return', 'reference_id' => $return->id]);
        $this->assertSame([], app(StockService::class)->drift($this->store->id));
        $this->assertSame(1, AuditLog::where('action', 'sale_return.voided')->count());

        // The customer's statement and summary: the return stays listed, with no effect.
        $this->as($this->owner)->getJson("/api/v1/customers/{$customer->id}/summary")
            ->assertJsonPath('data.returned', '0.00')
            ->assertJsonPath('data.remaining', '100.00');
        $events = collect($this->as($this->owner)->getJson("/api/v1/customers/{$customer->id}/statement")->json('data.events'));
        $this->assertTrue($events->firstWhere('type', 'return')['voided']);

        // Once its return is cancelled, the sale may be voided again.
        $this->as($this->owner)->postJson("/api/v1/sales/{$sale->id}/void", ['reason' => 'x'], $this->idem())->assertOk();
    }

    /** 10. Payments made after the return stay; the debt simply owes the returned value again. */
    public function test_cancelling_a_return_after_a_payment_reopens_only_what_is_owed(): void
    {
        $customer = $this->makeCustomer($this->store);
        $oil = $this->makeProduct($this->store, ['selling_price' => '20.00', 'current_stock' => 10]);
        $sale = $this->sale(['customer_id' => $customer->id, 'items' => [['product_id' => $oil->id, 'quantity' => 5]], 'paid_amount' => '0']);
        $return = $this->customerReturn($sale, 2);
        $debt = Debt::where('invoice_id', $sale->id)->sole();
        $this->as($this->owner)->postJson('/api/v1/payments', ['debt_id' => $debt->id, 'amount' => '60.00', 'method' => 'cash'], $this->idem())->assertCreated();
        $this->assertSame('paid', $debt->fresh()->status);

        $this->voidSaleReturn($return)->assertOk();

        $debt->refresh();
        $this->assertSame('40.00', $debt->remaining_amount);
        $this->assertSame('partially_paid', $debt->status);
        $this->assertSame(1, $debt->payments()->where('is_reversed', false)->count());
    }

    /** A cash refund given at the return is reported back as money to collect, not hidden. */
    public function test_cancelling_a_refunded_return_reports_the_refund_and_leaves_dashboard_figures(): void
    {
        $tea = $this->makeProduct($this->store, ['selling_price' => '6.50']);
        $sale = $this->sale(['items' => [['product_id' => $tea->id, 'quantity' => 3]], 'paid_amount' => '19.50', 'payment_method' => 'cash']);
        $return = $this->customerReturn($sale, 1);

        $this->as($this->owner)->getJson('/api/v1/dashboard?period=today')->assertJsonPath('data.returns.count', 1);
        $this->voidSaleReturn($return)->assertOk()->assertJsonFragment(['refund_amount' => '6.50']);

        $this->as($this->owner)->getJson('/api/v1/dashboard?period=today')
            ->assertJsonPath('data.returns.count', 0)
            ->assertJsonPath('data.collections.refunded', '0.00');
        $this->assertSame('6.50', AuditLog::where('action', 'sale_return.voided')->sole()->metadata['refund_to_collect']);
    }

    /** 11. A second cancel is refused and reverses nothing; a retried request replays the first. */
    public function test_a_return_cannot_be_cancelled_twice(): void
    {
        $tea = $this->makeProduct($this->store, ['current_stock' => 10]);
        $sale = $this->sale(['items' => [['product_id' => $tea->id, 'quantity' => 3]], 'paid_amount' => '30.00', 'payment_method' => 'cash']);
        $return = $this->customerReturn($sale, 2);
        $key = (string) \Illuminate\Support\Str::uuid();

        $first = $this->voidSaleReturn($return, $key)->assertOk();
        $this->voidSaleReturn($return, $key)->assertOk()->assertJson($first->json());
        $this->voidSaleReturn($return)->assertStatus(409)->assertJsonPath('code', 'RETURN_ALREADY_VOIDED');

        $this->assertSame('7.000', $tea->fresh()->current_stock);
        $this->assertSame(1, StockMovement::where('type', 'sale_return_void')->count());
        $this->assertSame(1, AuditLog::where('action', 'sale_return.voided')->count());
    }

    /** 12. Returned goods already sold again cannot be taken back: 409 and nothing changes. */
    public function test_cancelling_a_return_whose_goods_were_sold_again_is_blocked(): void
    {
        $customer = $this->makeCustomer($this->store);
        $tea = $this->makeProduct($this->store, ['current_stock' => 3]);
        $sale = $this->sale(['customer_id' => $customer->id, 'items' => [['product_id' => $tea->id, 'quantity' => 3]], 'paid_amount' => '0']);
        $return = $this->customerReturn($sale, 2);
        $this->sale(['items' => [['product_id' => $tea->id, 'quantity' => 2]], 'paid_amount' => '20.00', 'payment_method' => 'cash']);

        $this->voidSaleReturn($return)
            ->assertStatus(409)
            ->assertJsonPath('code', 'RETURN_STOCK_CONSUMED');

        $this->assertNull($return->fresh()->voided_at);
        $this->assertSame('0.000', $tea->fresh()->current_stock);
        $this->assertSame('20.00', Debt::where('invoice_id', $sale->id)->sole()->return_credit);
        $this->assertSame('2.000', $sale->items()->first()->returned_quantity);
        $this->assertSame(0, StockMovement::where('type', 'sale_return_void')->count());
    }

    /** 16. A shortfall on the second product rolls back the first product's movement too. */
    public function test_a_failed_cancel_leaves_no_partial_update(): void
    {
        $customer = $this->makeCustomer($this->store);
        $a = $this->makeProduct($this->store, ['current_stock' => 5]);
        $b = $this->makeProduct($this->store, ['current_stock' => 5]);
        $sale = $this->sale(['customer_id' => $customer->id, 'items' => [
            ['product_id' => $a->id, 'quantity' => 2],
            ['product_id' => $b->id, 'quantity' => 2],
        ], 'paid_amount' => '0']);
        $items = $sale->items()->orderBy('id')->get();
        $returnId = $this->as($this->owner)->postJson("/api/v1/sales/{$sale->id}/returns", [
            'items' => [['invoice_item_id' => $items[0]->id, 'quantity' => 2], ['invoice_item_id' => $items[1]->id, 'quantity' => 2]],
            'reason' => 'خطأ',
        ], $this->idem())->assertCreated()->json('data.id');
        // b's returned pieces leave the shelf again by an adjustment.
        $this->as($this->owner)->postJson('/api/v1/stock-adjustments', ['product_id' => $b->id, 'quantity' => -5, 'reason' => 'تلف'], $this->idem())->assertCreated();
        $movements = StockMovement::count();

        $this->voidSaleReturn(SaleReturn::findOrFail($returnId))->assertStatus(409);

        $this->assertSame('5.000', $a->fresh()->current_stock);
        $this->assertSame($movements, StockMovement::count());
        $this->assertSame('40.00', Debt::where('invoice_id', $sale->id)->sole()->return_credit);
        $this->assertSame(0, AuditLog::where('action', 'sale_return.voided')->count());
    }

    // ── Supplier returns and invoices ───────────────────────────────────────────────────────

    /** 7 + 8 + 9. A supplier return made by mistake: goods back on the shelf, balance owed again. */
    public function test_a_mistaken_supplier_return_is_cancelled(): void
    {
        $invoice = $this->delivery();
        $cola = $invoice->items[0];
        $returnId = $this->as($this->owner)->postJson("/api/v1/purchases/{$invoice->id}/returns", [
            'items' => [['purchase_item_id' => $cola->id, 'quantity' => 24]],
            'reason' => 'تالف',
        ], $this->idem())->assertCreated()->json('data.id');
        $this->assertSame('460.00', Supplier::sole()->balance());

        $this->as($this->owner)->postJson("/api/v1/returns/purchases/{$returnId}/void", ['reason' => 'لم يُرجع فعلًا'], $this->idem())
            ->assertOk()
            ->assertJsonPath('data.status', 'voided')
            ->assertJsonPath('balance', '520.00');

        $this->assertSame('96.000', Product::find($cola->product_id)->current_stock);
        $this->assertSame('0.000', $cola->fresh()->returned_quantity);
        $this->assertDatabaseHas('stock_movements', ['product_id' => $cola->product_id, 'type' => 'purchase_return_void', 'quantity' => 24]);
        $this->assertSame([], app(StockService::class)->drift($this->store->id));
        $this->as($this->owner)->getJson('/api/v1/suppliers')->assertJsonPath('data.0.balance', '520.00');
        $this->as($this->owner)->getJson("/api/v1/purchases/{$invoice->id}")
            ->assertJsonPath('data.returned_amount', '0.00')
            ->assertJsonPath('data.returns.0.status', 'voided')
            ->assertJsonPath('data.items.0.remaining_quantity', '96');

        $this->as($this->owner)->postJson("/api/v1/returns/purchases/{$returnId}/void", ['reason' => 'مرة أخرى'], $this->idem())
            ->assertStatus(409)->assertJsonPath('code', 'RETURN_ALREADY_VOIDED');
        $this->assertSame(1, StockMovement::where('type', 'purchase_return_void')->count());
    }

    /** A delivery recorded by mistake is voided: stock out, its payment voided, balance back. */
    public function test_a_mistaken_purchase_invoice_is_voided_with_its_payment(): void
    {
        $invoice = $this->delivery('100.00');
        $this->assertSame('420.00', Supplier::sole()->balance());

        $this->as($this->owner)->postJson("/api/v1/purchases/{$invoice->id}/void", ['reason' => 'فاتورة مكررة'], $this->idem())
            ->assertOk()
            ->assertJsonPath('data.status', 'voided')
            ->assertJsonPath('balance', '0.00');

        $this->assertSame('0.000', Product::where('name', 'كولا علبة')->sole()->current_stock);
        $this->assertNotNull(SupplierPayment::sole()->voided_at);
        $this->assertSame(2, StockMovement::where('type', 'purchase_void')->count());
        $this->as($this->owner)->getJson('/api/v1/dashboard?period=today')->assertJsonPath('data.purchases.total', '0.00');
        // The voided invoice stays in the register.
        $this->as($this->owner)->getJson('/api/v1/purchases')->assertJsonPath('data.0.status', 'voided');
        $this->as($this->owner)->postJson("/api/v1/purchases/{$invoice->id}/returns", [
            'items' => [['purchase_item_id' => $invoice->items[0]->id, 'quantity' => 1]], 'reason' => 'x',
        ], $this->idem())->assertStatus(409)->assertJsonPath('code', 'PURCHASE_VOIDED');
    }

    public function test_a_purchase_with_returns_sold_goods_or_later_payments_cannot_be_voided(): void
    {
        $invoice = $this->delivery();
        $this->as($this->owner)->postJson("/api/v1/purchases/{$invoice->id}/returns", [
            'items' => [['purchase_item_id' => $invoice->items[0]->id, 'quantity' => 1]], 'reason' => 'x',
        ], $this->idem())->assertCreated();
        $this->as($this->owner)->postJson("/api/v1/purchases/{$invoice->id}/void", ['reason' => 'x'], $this->idem())
            ->assertStatus(409)->assertJsonPath('code', 'PURCHASE_HAS_RETURNS');

        $second = $this->delivery();
        $this->sale(['items' => [['product_id' => $second->items[1]->product_id, 'quantity' => '15']], 'paid_amount' => '600.00', 'payment_method' => 'cash']);
        $this->as($this->owner)->postJson("/api/v1/purchases/{$second->id}/void", ['reason' => 'x'], $this->idem())
            ->assertStatus(409)->assertJsonPath('code', 'PURCHASE_STOCK_CONSUMED');

        $third = $this->delivery();
        $supplier = Supplier::sole();
        $this->as($this->owner)->postJson("/api/v1/suppliers/{$supplier->id}/payments", ['amount' => $supplier->balance(), 'method' => 'cash'], $this->idem())->assertCreated();
        $this->as($this->owner)->postJson("/api/v1/purchases/{$third->id}/void", ['reason' => 'x'], $this->idem())
            ->assertStatus(409)->assertJsonPath('code', 'PURCHASE_VOID_OVERPAID');

        $this->assertSame(0, PurchaseInvoice::whereNotNull('voided_at')->count());
    }

    /** A supplier payment recorded by mistake is voided once; the amount is owed again. */
    public function test_a_supplier_payment_is_voided_once(): void
    {
        $this->delivery();
        $supplier = Supplier::sole();
        $this->as($this->owner)->postJson("/api/v1/suppliers/{$supplier->id}/payments", ['amount' => '200.00', 'method' => 'cash'], $this->idem())->assertCreated();
        $payment = SupplierPayment::sole();

        $this->as($this->owner)->postJson("/api/v1/suppliers/{$supplier->id}/payments/{$payment->id}/void", ['reason' => 'مبلغ خاطئ'], $this->idem())
            ->assertOk()->assertJsonPath('data.balance', '520.00');
        $this->as($this->owner)->postJson("/api/v1/suppliers/{$supplier->id}/payments/{$payment->id}/void", ['reason' => 'مرة أخرى'], $this->idem())
            ->assertStatus(409)->assertJsonPath('code', 'PAYMENT_ALREADY_VOIDED');
        $this->as($this->owner)->getJson("/api/v1/suppliers/{$supplier->id}")
            ->assertJsonPath('data.payments.0.status', 'voided')
            ->assertJsonPath('data.payments.0.void_reason', 'مبلغ خاطئ');
    }

    /** A supplier with history is archived, never deleted; a new delivery brings it back. */
    public function test_a_supplier_with_history_is_archived_not_deleted(): void
    {
        $this->delivery();
        $supplier = Supplier::sole();

        $this->as($this->owner)->deleteJson("/api/v1/suppliers/{$supplier->id}")->assertStatus(409)->assertJsonPath('code', 'SUPPLIER_IN_USE');
        $this->as($this->owner)->postJson("/api/v1/suppliers/{$supplier->id}/archive")->assertOk()->assertJsonPath('data.status', 'archived');
        $this->as($this->owner)->getJson('/api/v1/suppliers')->assertJsonCount(0, 'data');
        $this->as($this->owner)->getJson('/api/v1/suppliers?status=all')->assertJsonPath('data.0.balance', '520.00');

        $this->delivery();
        $this->assertSame('active', $supplier->fresh()->status);

        $unused = Supplier::create(['store_id' => $this->store->id, 'name' => 'بلا فواتير']);
        $this->as($this->owner)->deleteJson("/api/v1/suppliers/{$unused->id}")->assertOk();
        $this->assertDatabaseMissing('suppliers', ['id' => $unused->id]);
    }

    // ── Stock adjustments ───────────────────────────────────────────────────────────────────

    public function test_a_stock_adjustment_is_reversed_once_and_never_below_zero(): void
    {
        $tea = $this->makeProduct($this->store, ['current_stock' => 10]);
        $movementId = $this->as($this->owner)->postJson('/api/v1/stock-adjustments', ['product_id' => $tea->id, 'quantity' => 5, 'reason' => 'جرد'], $this->idem())
            ->assertCreated()->json('movement.id');

        $this->as($this->owner)->postJson("/api/v1/stock-movements/{$movementId}/reverse", ['reason' => 'رقم خاطئ'], $this->idem())
            ->assertCreated()
            ->assertJsonPath('movement.type', 'adjustment_reversal')
            ->assertJsonPath('product.current_stock', '10');
        $this->as($this->owner)->postJson("/api/v1/stock-movements/{$movementId}/reverse", ['reason' => 'x'], $this->idem())
            ->assertStatus(409)->assertJsonPath('code', 'MOVEMENT_ALREADY_REVERSED');
        $this->as($this->owner)->getJson("/api/v1/products/{$tea->id}/movements")->assertJsonPath('data.1.reversed', true);

        // An opening row or a sale is corrected from its document, not here.
        $opening = StockMovement::where('product_id', $tea->id)->where('type', 'opening')->sole();
        $this->as($this->owner)->postJson("/api/v1/stock-movements/{$opening->id}/reverse", ['reason' => 'x'], $this->idem())
            ->assertStatus(409)->assertJsonPath('code', 'MOVEMENT_NOT_REVERSIBLE');

        // Taking back an addition whose pieces were sold since would go below zero.
        $added = $this->as($this->owner)->postJson('/api/v1/stock-adjustments', ['product_id' => $tea->id, 'quantity' => 3, 'reason' => 'جرد'], $this->idem())->json('movement.id');
        $this->sale(['items' => [['product_id' => $tea->id, 'quantity' => 12]], 'paid_amount' => '120.00', 'payment_method' => 'cash']);
        $this->as($this->owner)->postJson("/api/v1/stock-movements/{$added}/reverse", ['reason' => 'x'], $this->idem())
            ->assertStatus(409)->assertJsonPath('code', 'MOVEMENT_STOCK_CONSUMED');
        $this->assertSame('1.000', $tea->fresh()->current_stock);
    }

    // ── Permissions and store isolation ─────────────────────────────────────────────────────

    /** 13. Employees can neither delete nor void; nothing changes. */
    public function test_employees_cannot_delete_archive_or_void(): void
    {
        $employee = $this->makeUser($this->store, 'employee');
        $tea = $this->makeProduct($this->store);
        $sale = $this->sale(['items' => [['product_id' => $tea->id, 'quantity' => 3]], 'paid_amount' => '30.00', 'payment_method' => 'cash']);
        $saleReturn = $this->customerReturn($sale, 1);
        $invoice = $this->delivery('100.00');
        $supplier = Supplier::sole();
        $movement = StockMovement::where('product_id', $tea->id)->first();

        $this->as($employee)->postJson("/api/v1/returns/sales/{$saleReturn->id}/void", ['reason' => 'x'], $this->idem())->assertForbidden();
        $this->as($employee)->postJson("/api/v1/purchases/{$invoice->id}/void", ['reason' => 'x'], $this->idem())->assertForbidden();
        $this->as($employee)->postJson("/api/v1/suppliers/{$supplier->id}/payments/" . SupplierPayment::sole()->id . '/void', ['reason' => 'x'], $this->idem())->assertForbidden();
        $this->as($employee)->postJson("/api/v1/stock-movements/{$movement->id}/reverse", ['reason' => 'x'], $this->idem())->assertForbidden();
        $this->as($employee)->deleteJson("/api/v1/products/{$tea->id}")->assertForbidden();
        $this->as($employee)->deleteJson("/api/v1/suppliers/{$supplier->id}")->assertForbidden();
        $this->as($employee)->postJson("/api/v1/suppliers/{$supplier->id}/archive")->assertForbidden();

        $this->assertNull($saleReturn->fresh()->voided_at);
        $this->assertNull($invoice->fresh()->voided_at);
        $this->assertSame('active', $supplier->fresh()->status);
        $this->assertSame(0, AuditLog::where('action', 'like', '%voided')->count());
        // The detail screen hides «delete» from staff.
        $this->as($employee)->getJson("/api/v1/products/{$tea->id}")->assertJsonMissingPath('data.deletable');
    }

    /** A manager may cancel, like the sale void. */
    public function test_a_manager_may_cancel_a_return(): void
    {
        $manager = $this->makeUser($this->store, 'manager');
        $tea = $this->makeProduct($this->store);
        $sale = $this->sale(['items' => [['product_id' => $tea->id, 'quantity' => 3]], 'paid_amount' => '30.00', 'payment_method' => 'cash']);

        $this->voidSaleReturn($this->customerReturn($sale, 1), actor: $manager)->assertOk();
    }

    /** 14. Another store's records resolve to 404, for every cancel and delete. */
    public function test_another_stores_records_cannot_be_deleted_or_voided(): void
    {
        $tea = $this->makeProduct($this->store);
        $sale = $this->sale(['items' => [['product_id' => $tea->id, 'quantity' => 3]], 'paid_amount' => '30.00', 'payment_method' => 'cash']);
        $saleReturn = $this->customerReturn($sale, 1);
        $invoice = $this->delivery('100.00');
        $supplier = Supplier::sole();
        $unused = $this->makeProduct($this->store);
        $intruder = $this->makeUser($this->makeStore('Other'));

        $this->as($intruder)->postJson("/api/v1/returns/sales/{$saleReturn->id}/void", ['reason' => 'x'], $this->idem())->assertNotFound();
        $this->as($intruder)->postJson("/api/v1/purchases/{$invoice->id}/void", ['reason' => 'x'], $this->idem())->assertNotFound();
        $this->as($intruder)->postJson("/api/v1/suppliers/{$supplier->id}/payments/" . SupplierPayment::sole()->id . '/void', ['reason' => 'x'], $this->idem())->assertNotFound();
        $this->as($intruder)->deleteJson("/api/v1/products/{$unused->id}")->assertNotFound();
        $this->as($intruder)->deleteJson("/api/v1/suppliers/{$supplier->id}")->assertNotFound();
        $this->as($intruder)->postJson('/api/v1/stock-movements/' . StockMovement::first()->id . '/reverse', ['reason' => 'x'], $this->idem())->assertNotFound();

        $this->assertDatabaseHas('products', ['id' => $unused->id]);
        $this->assertNull($saleReturn->fresh()->voided_at);
        $this->assertNull($invoice->fresh()->voided_at);
    }

    /** 15. The cancelled return keeps its original amounts and lines in the registers. */
    public function test_a_cancelled_return_keeps_its_history_in_the_registers(): void
    {
        $tea = $this->makeProduct($this->store, ['name' => 'شاي']);
        $sale = $this->sale(['items' => [['product_id' => $tea->id, 'quantity' => 3]], 'paid_amount' => '30.00', 'payment_method' => 'cash']);
        $return = $this->customerReturn($sale, 2);
        $this->voidSaleReturn($return)->assertOk();

        $this->as($this->owner)->getJson('/api/v1/returns/sales')
            ->assertJsonPath('data.0.id', $return->id)
            ->assertJsonPath('data.0.status', 'voided')
            ->assertJsonPath('data.0.total_amount', '20.00')
            ->assertJsonPath('data.0.items.0.item_name', 'شاي')
            ->assertJsonPath('data.0.items.0.quantity', '2');
        $this->as($this->owner)->getJson("/api/v1/sales/{$sale->id}")
            ->assertJsonPath('data.returns.0.status', 'voided')
            ->assertJsonPath('data.returned_amount', '0.00')
            ->assertJsonPath('data.items.0.returned_quantity', '0');
        $this->assertDatabaseHas('sale_returns', ['id' => $return->id, 'total_amount' => '20.00', 'refund_amount' => '20.00']);
    }

    public function test_a_reason_is_required(): void
    {
        $tea = $this->makeProduct($this->store);
        $sale = $this->sale(['items' => [['product_id' => $tea->id, 'quantity' => 3]], 'paid_amount' => '30.00', 'payment_method' => 'cash']);

        $this->as($this->owner)->postJson('/api/v1/returns/sales/' . $this->customerReturn($sale, 1)->id . '/void', ['reason' => '  '], $this->idem())
            ->assertUnprocessable()->assertJsonValidationErrors('reason');
    }

    // ── Helpers ─────────────────────────────────────────────────────────────────────────────

    private function as(User $user): self
    {
        $this->app['auth']->forgetGuards();

        return $this->actingAs($user, 'sanctum');
    }

    private function sale(array $body): Invoice
    {
        return app(SaleService::class)->create($this->owner, $body)['invoice'];
    }

    private function customerReturn(Invoice $sale, int|string $quantity): SaleReturn
    {
        $id = $this->as($this->owner)->postJson("/api/v1/sales/{$sale->id}/returns", [
            'items' => [['invoice_item_id' => $sale->items()->first()->id, 'quantity' => $quantity]],
            'reason' => 'خطأ',
        ], $this->idem())->assertCreated()->json('data.id');

        return SaleReturn::findOrFail($id);
    }

    private function voidSaleReturn(SaleReturn $return, ?string $key = null, ?User $actor = null): TestResponse
    {
        return $this->as($actor ?? $this->owner)->postJson("/api/v1/returns/sales/{$return->id}/void", ['reason' => 'سُجّل بالخطأ'], $this->idem($key));
    }

    /** 4 cartons of 24 cola at 60.00 = 240.00 and 10 kg almonds at 28.00 = 280.00: 520.00. */
    private function delivery(string $paid = '0'): PurchaseInvoice
    {
        $this->as($this->owner)->postJson('/api/v1/purchases', [
            'supplier_name' => 'شركة الأمل',
            'paid_amount' => $paid,
            'method' => 'cash',
            'lines' => [
                ['name' => 'كولا علبة', 'barcode' => '6251234567890', 'unit' => 'piece', 'cartons' => 4, 'pack_size' => 24, 'buy_price' => '60.00', 'selling_price' => '3.50'],
                ['name' => 'لوز نيء', 'unit' => 'kg', 'quantity' => '10', 'buy_price' => '28.00', 'selling_price' => '40.00'],
            ],
        ], $this->idem())->assertCreated();

        return PurchaseInvoice::with('items')->latest('id')->firstOrFail();
    }

    /** @return array{0: array, 1: Product, 2: Product} a held transfer sale: 3 tea (30.00) + 2 sugar (10.00) */
    private function heldInvoice(): array
    {
        $tea = $this->makeProduct($this->store, ['selling_price' => '10.00', 'current_stock' => 3]);
        $sugar = $this->makeProduct($this->store, ['selling_price' => '5.00', 'current_stock' => 10]);
        $account = ReceivingAccount::create([
            'store_id' => $this->store->id, 'provider' => 'palpay', 'account_name' => 'Main',
            'account_identifier' => '0590000000', 'active' => true,
        ]);

        $held = $this->as($this->owner)->postJson('/api/v1/suspended-invoices', [
            'items' => [['product_id' => $tea->id, 'quantity' => 3], ['product_id' => $sugar->id, 'quantity' => 2]],
            'payment_method' => 'palpay',
            'receiving_account_id' => $account->id,
        ], $this->idem())->assertCreated()->json('data');

        return [$held, $tea, $sugar];
    }
}
