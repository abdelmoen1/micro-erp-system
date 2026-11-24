<?php

namespace Tests\Feature;

use App\Models\InventoryReservation;
use App\Models\AuditLog;
use App\Models\Invoice;
use App\Models\PurchaseInvoice;
use App\Models\ReceivingAccount;
use App\Models\SuspendedInvoice;
use App\Models\StockMovement;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Support\BuildsShopData;
use Tests\TestCase;

class SuspendedSaleTest extends TestCase
{
    use BuildsShopData;
    use RefreshDatabase;

    public function test_suspend_multiple_reservations_confirm_once_and_reject_releases_stock(): void
    {
        $store = $this->makeStore();
        $owner = $this->makeUser($store);
        $product = $this->makeProduct($store, ['current_stock' => 5, 'selling_price' => '10.00', 'unit' => 'piece']);
        $account = ReceivingAccount::create([
            'store_id' => $store->id,
            'provider' => 'jawwal_pay',
            'account_name' => 'عبدالمعين',
            'account_identifier' => '0592288354',
            'active' => true,
            'created_by' => $owner->id,
        ]);

        $api = $this->actingAs($owner, 'sanctum');
        $first = $api->postJson('/api/v1/suspended-invoices', [
            'items' => [['product_id' => $product->id, 'quantity' => 3]],
            'payment_method' => 'jawwal_pay',
            'receiving_account_id' => $account->id,
        ], $this->idem())->assertCreated()->json('data');

        $second = $api->postJson('/api/v1/suspended-invoices', [
            'items' => [['product_id' => $product->id, 'quantity' => 2]],
            'payment_method' => 'jawwal_pay',
            'receiving_account_id' => $account->id,
        ], $this->idem())->assertCreated()->json('data');

        $this->assertDatabaseCount('suspended_invoices', 2);
        $this->assertSame(2, InventoryReservation::where('status', 'active')->count());
        $this->assertSame('5.000', (string) $product->fresh()->current_stock);
        $this->assertSame(0, Invoice::count(), 'Pending transfers are not finalized sales or revenue.');

        $api->postJson("/api/v1/suspended-invoices/{$first['id']}/confirm", [], $this->idem())
            ->assertOk();
        $this->assertDatabaseHas('suspended_invoices', ['id' => $first['id'], 'status' => 'completed']);
        $this->assertSame('2.000', (string) $product->fresh()->current_stock);

        $api->postJson("/api/v1/suspended-invoices/{$second['id']}/confirm", [], $this->idem())
            ->assertOk();
        $this->assertDatabaseHas('suspended_invoices', ['id' => $second['id'], 'status' => 'completed']);
        $this->assertSame('0.000', (string) $product->fresh()->current_stock);
    }

    public function test_reserved_stock_cannot_be_oversold_and_rejection_releases_it(): void
    {
        $store = $this->makeStore();
        $owner = $this->makeUser($store);
        $product = $this->makeProduct($store, ['current_stock' => 2, 'selling_price' => '5.00', 'unit' => 'piece']);
        $account = ReceivingAccount::create([
            'store_id' => $store->id,
            'provider' => 'palpay',
            'account_name' => 'عبدالمعين',
            'account_identifier' => '0599463694',
            'active' => true,
        ]);
        $api = $this->actingAs($owner, 'sanctum');

        $first = $api->postJson('/api/v1/suspended-invoices', [
            'items' => [['product_id' => $product->id, 'quantity' => 2]],
            'payment_method' => 'palpay',
            'receiving_account_id' => $account->id,
        ], $this->idem())->assertCreated()->json('data');

        $api->postJson('/api/v1/suspended-invoices', [
            'items' => [['product_id' => $product->id, 'quantity' => 1]],
            'payment_method' => 'palpay',
            'receiving_account_id' => $account->id,
        ], $this->idem())->assertStatus(422);

        $api->postJson("/api/v1/suspended-invoices/{$first['id']}/close", [
            'status' => 'rejected',
            'reason' => 'رفض التحويل',
        ], $this->idem())->assertOk();

        $this->assertDatabaseHas('inventory_reservations', [
            'suspended_invoice_id' => $first['id'],
            'status' => 'released',
        ]);
        $this->assertDatabaseHas('suspended_invoices', ['id' => $first['id'], 'status' => 'rejected']);
    }

    public function test_ordinary_sales_and_adjustments_cannot_consume_reserved_stock(): void
    {
        $store = $this->makeStore();
        $owner = $this->makeUser($store);
        $product = $this->makeProduct($store, ['current_stock' => 2, 'selling_price' => '5.00']);
        $account = ReceivingAccount::create([
            'store_id' => $store->id,
            'provider' => 'palpay',
            'account_name' => 'Main',
            'account_identifier' => '0590000000',
            'active' => true,
        ]);
        $api = $this->actingAs($owner, 'sanctum');
        $suspended = $api->postJson('/api/v1/suspended-invoices', [
            'items' => [['product_id' => $product->id, 'quantity' => 2]],
            'payment_method' => 'palpay',
            'receiving_account_id' => $account->id,
        ], $this->idem())->assertCreated()->json('data');

        $api->postJson('/api/v1/sales', [
            'items' => [['product_id' => $product->id, 'quantity' => 1]],
            'paid_amount' => '5.00',
            'payment_method' => 'cash',
        ], $this->idem())->assertUnprocessable()->assertJsonPath('code', 'INSUFFICIENT_UNRESERVED_STOCK');

        $api->postJson('/api/v1/stock-adjustments', [
            'product_id' => $product->id,
            'quantity' => -1,
            'reason' => 'Count correction',
        ], $this->idem())->assertUnprocessable()->assertJsonPath('code', 'INSUFFICIENT_UNRESERVED_STOCK');

        $this->assertSame('2.000', $product->fresh()->current_stock);
        $this->assertSame(0, Invoice::count());
        $this->assertSame(0, StockMovement::where('type', StockMovement::TYPE_SALE)->count());
        $this->assertSame(1, InventoryReservation::where('suspended_invoice_id', $suspended['id'])->where('status', 'active')->count());
    }

    public function test_ordinary_sale_keeps_the_existing_negative_stock_policy_without_reservations(): void
    {
        $store = $this->makeStore();
        $owner = $this->makeUser($store);
        $product = $this->makeProduct($store, ['current_stock' => -1, 'selling_price' => '5.00']);

        $this->actingAs($owner, 'sanctum')->postJson('/api/v1/sales', [
            'items' => [['product_id' => $product->id, 'quantity' => 1]],
            'paid_amount' => '5.00',
            'payment_method' => 'cash',
        ], $this->idem())->assertCreated();

        $this->assertSame('-2.000', $product->fresh()->current_stock);
        $this->assertSame(0, InventoryReservation::where('product_id', $product->id)->where('status', 'active')->count());
    }

    public function test_fractional_reservations_use_exact_three_decimal_quantity_math(): void
    {
        $store = $this->makeStore();
        $owner = $this->makeUser($store);
        $product = $this->makeProduct($store, [
            'current_stock' => '0.015',
            'selling_price' => '1.00',
            'unit' => 'kg',
        ]);
        $account = ReceivingAccount::create([
            'store_id' => $store->id,
            'provider' => 'jawwal_pay',
            'account_name' => 'Main',
            'account_identifier' => '0590000000',
            'active' => true,
        ]);
        $api = $this->actingAs($owner, 'sanctum');

        $api->postJson('/api/v1/suspended-invoices', [
            'items' => [['product_id' => $product->id, 'quantity' => '0.006']],
            'payment_method' => 'jawwal_pay',
            'receiving_account_id' => $account->id,
        ], $this->idem())->assertCreated();

        $api->postJson('/api/v1/suspended-invoices', [
            'items' => [['product_id' => $product->id, 'quantity' => '0.010']],
            'payment_method' => 'jawwal_pay',
            'receiving_account_id' => $account->id,
        ], $this->idem())->assertUnprocessable();

        $api->postJson('/api/v1/suspended-invoices', [
            'items' => [['product_id' => $product->id, 'quantity' => '0.009']],
            'payment_method' => 'jawwal_pay',
            'receiving_account_id' => $account->id,
        ], $this->idem())->assertCreated();

        $this->assertSame('0.015', (string) InventoryReservation::where('product_id', $product->id)->sum('quantity'));
        $this->assertSame('0.015', $product->fresh()->current_stock);
    }

    public function test_finalization_uses_saved_pack_size_and_allows_mixed_units(): void
    {
        $store = $this->makeStore();
        $owner = $this->makeUser($store);
        $product = $this->makeProduct($store, [
            'current_stock' => 50,
            'selling_price' => '2.00',
            'pack_size' => 12,
            'pack_price' => '20.00',
        ]);
        $account = ReceivingAccount::create([
            'store_id' => $store->id,
            'provider' => 'palpay',
            'account_name' => 'Main',
            'account_identifier' => '0590000000',
            'active' => true,
        ]);
        $api = $this->actingAs($owner, 'sanctum');
        $suspendResponse = $api->postJson('/api/v1/suspended-invoices', [
            'items' => [
                ['product_id' => $product->id, 'quantity' => 1, 'sale_unit' => 'pack', 'unit_price' => '20.00'],
                ['product_id' => $product->id, 'quantity' => 3, 'unit_price' => '2.00'],
            ],
            'payment_method' => 'palpay',
            'receiving_account_id' => $account->id,
        ], $this->idem())->assertCreated();

        $this->assertSame('12.000', $suspendResponse->json('data.items.0.base_quantity'));
        $product->update([
            'pack_size' => 10,
            'selling_price' => '3.00',
            'pack_price' => '30.00',
        ]);

        $api->postJson("/api/v1/suspended-invoices/{$suspendResponse->json('data.id')}/confirm", [], $this->idem())
            ->assertOk();

        $this->assertSame('35.000', $product->fresh()->current_stock);
        $invoice = Invoice::sole();
        $this->assertCount(2, $invoice->items);
        $this->assertSame(12, $invoice->items->first()->pack_size);
        $this->assertSame('12.000', $invoice->items->first()->baseQuantity($invoice->items->first()->quantity));
        $this->assertSame('20.00', $invoice->items->first()->unit_price);
        $saleAudit = AuditLog::where('action', 'sale.created')->sole();
        $this->assertArrayNotHasKey('price_edits', $saleAudit->metadata);
        $this->assertSame(2, InventoryReservation::where('suspended_invoice_id', $suspendResponse->json('data.id'))
            ->where('status', InventoryReservation::STATUS_DEDUCTED)->count());
    }

    public function test_finalizing_with_same_idempotency_key_posts_once(): void
    {
        $store = $this->makeStore();
        $owner = $this->makeUser($store);
        $product = $this->makeProduct($store, ['current_stock' => 5]);
        $account = ReceivingAccount::create([
            'store_id' => $store->id,
            'provider' => 'bank_of_palestine',
            'account_name' => 'Main',
            'account_identifier' => '123456',
            'active' => true,
        ]);
        $api = $this->actingAs($owner, 'sanctum');
        $suspended = $api->postJson('/api/v1/suspended-invoices', [
            'items' => [['product_id' => $product->id, 'quantity' => 2]],
            'payment_method' => 'bank_of_palestine',
            'receiving_account_id' => $account->id,
        ], $this->idem())->assertCreated()->json('data');

        $key = $this->idem();
        $first = $api->postJson("/api/v1/suspended-invoices/{$suspended['id']}/confirm", [], $key)->assertOk();
        $second = $api->postJson("/api/v1/suspended-invoices/{$suspended['id']}/confirm", [], $key)->assertOk();

        $this->assertSame($first->getContent(), $second->getContent());
        $second->assertHeader('Idempotent-Replay', 'true');
        $this->assertSame('3.000', $product->fresh()->current_stock);
        $this->assertSame(1, Invoice::count());
        $this->assertSame(1, StockMovement::where('type', StockMovement::TYPE_SALE)->count());
    }

    public function test_employee_cannot_manage_accounts_but_can_select_active_store_account(): void
    {
        $store = $this->makeStore();
        $owner = $this->makeUser($store);
        $employee = $this->makeUser($store, 'employee');
        $otherStore = $this->makeStore('Other');
        $account = ReceivingAccount::create([
            'store_id' => $store->id,
            'provider' => 'bank_of_palestine',
            'account_name' => 'علاء',
            'account_identifier' => '0593898334',
            'active' => true,
        ]);
        ReceivingAccount::create([
            'store_id' => $otherStore->id,
            'provider' => 'bank_of_palestine',
            'account_name' => 'Other',
            'account_identifier' => '0000',
            'active' => true,
        ]);

        $this->actingAs($employee, 'sanctum')
            ->postJson('/api/v1/receiving-accounts', [
                'provider' => 'jawwal_pay',
                'account_name' => 'غير مسموح',
                'account_identifier' => '123',
            ], $this->idem())->assertForbidden();

        $this->actingAs($employee, 'sanctum')
            ->getJson('/api/v1/receiving-accounts?provider=bank_of_palestine')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.account_identifier', '0593898334');

        $this->actingAs($employee, 'sanctum')
            ->getJson('/api/v1/receiving-accounts?include_inactive=1')
            ->assertForbidden();

        $this->actingAs($owner, 'sanctum')
            ->postJson('/api/v1/receiving-accounts', [
                'provider' => 'cash',
                'account_name' => 'Not a transfer account',
                'account_identifier' => 'cash',
            ], $this->idem())
            ->assertUnprocessable()
            ->assertJsonValidationErrors('provider');

        $this->actingAs($owner, 'sanctum')
            ->patchJson("/api/v1/receiving-accounts/{$account->id}", ['active' => false])
            ->assertOk();
        $this->assertDatabaseHas('receiving_accounts', ['id' => $account->id, 'active' => false]);
    }

    public function test_only_managers_can_cancel_and_cancellation_requires_reason(): void
    {
        $store = $this->makeStore();
        $owner = $this->makeUser($store);
        $employee = $this->makeUser($store, 'employee');
        $product = $this->makeProduct($store, ['current_stock' => 3]);
        $account = ReceivingAccount::create([
            'store_id' => $store->id,
            'provider' => 'palpay',
            'account_name' => 'Main',
            'account_identifier' => '0590000000',
            'active' => true,
        ]);
        $suspended = $this->actingAs($owner, 'sanctum')->postJson('/api/v1/suspended-invoices', [
            'items' => [['product_id' => $product->id, 'quantity' => 2]],
            'payment_method' => 'palpay',
            'receiving_account_id' => $account->id,
        ], $this->idem())->assertCreated()->json('data');

        $this->actingAs($employee, 'sanctum')
            ->postJson("/api/v1/suspended-invoices/{$suspended['id']}/close", [
                'status' => 'cancelled',
                'reason' => 'Duplicate',
            ], $this->idem())->assertForbidden();

        $this->actingAs($owner, 'sanctum')
            ->postJson("/api/v1/suspended-invoices/{$suspended['id']}/close", [
                'status' => 'cancelled',
            ], $this->idem())->assertUnprocessable()->assertJsonValidationErrors('reason');

        $this->actingAs($owner, 'sanctum')
            ->postJson("/api/v1/suspended-invoices/{$suspended['id']}/close", [
                'status' => 'cancelled',
                'reason' => 'Duplicate entry',
            ], $this->idem())->assertOk();

        $this->assertSame(0, InventoryReservation::where('suspended_invoice_id', $suspended['id'])
            ->where('status', InventoryReservation::STATUS_ACTIVE)->count());
        $this->assertDatabaseHas('suspended_invoice_events', [
            'suspended_invoice_id' => $suspended['id'],
            'event' => 'cancelled',
        ]);
        $this->assertSame('3.000', $product->fresh()->current_stock);
    }

    public function test_supplier_return_cannot_consume_reserved_stock(): void
    {
        $store = $this->makeStore();
        $owner = $this->makeUser($store);
        $api = $this->actingAs($owner, 'sanctum');
        $api->postJson('/api/v1/purchases', [
            'supplier_name' => 'Supplier',
            'lines' => [[
                'name' => 'Reserved product',
                'barcode' => '6251234567890',
                'unit' => 'piece',
                'cartons' => 1,
                'pack_size' => 2,
                'buy_price' => '1.00',
                'selling_price' => '5.00',
            ]],
        ], $this->idem())->assertCreated();
        $purchase = PurchaseInvoice::with('items')->sole();
        $product = $purchase->items->first()->product;
        $account = ReceivingAccount::create([
            'store_id' => $store->id,
            'provider' => 'palpay',
            'account_name' => 'Main',
            'account_identifier' => '0590000000',
            'active' => true,
        ]);
        $suspended = $api->postJson('/api/v1/suspended-invoices', [
            'items' => [['product_id' => $product->id, 'quantity' => 2]],
            'payment_method' => 'palpay',
            'receiving_account_id' => $account->id,
        ], $this->idem())->assertCreated()->json('data');

        $api->postJson("/api/v1/purchases/{$purchase->id}/returns", [
            'items' => [['purchase_item_id' => $purchase->items->first()->id, 'quantity' => 1]],
            'reason' => 'Return while reserved',
        ], $this->idem())->assertUnprocessable()
            ->assertJsonPath('code', 'INSUFFICIENT_UNRESERVED_STOCK');

        $this->assertSame('2.000', $product->fresh()->current_stock);
        $this->assertSame(0, \App\Models\PurchaseReturn::count());
        $this->assertSame(1, InventoryReservation::where('suspended_invoice_id', $suspended['id'])
            ->where('status', InventoryReservation::STATUS_ACTIVE)->count());
    }

    public function test_account_edits_preserve_invoice_snapshot_and_pending_invoice_is_store_scoped(): void
    {
        $store = $this->makeStore();
        $owner = $this->makeUser($store);
        $otherStoreUser = $this->makeUser($this->makeStore('Other'));
        $product = $this->makeProduct($store, ['current_stock' => 2]);
        $account = ReceivingAccount::create([
            'store_id' => $store->id,
            'provider' => 'palpay',
            'account_name' => 'Original name',
            'account_identifier' => '0590000000',
            'active' => true,
        ]);
        $api = $this->actingAs($owner, 'sanctum');
        $suspended = $api->postJson('/api/v1/suspended-invoices', [
            'items' => [['product_id' => $product->id, 'quantity' => 1]],
            'payment_method' => 'palpay',
            'receiving_account_id' => $account->id,
        ], $this->idem())->assertCreated()->json('data');

        $api->patchJson("/api/v1/receiving-accounts/{$account->id}", [
            'account_name' => 'Updated name',
            'account_identifier' => '0591111111',
            'provider' => 'jawwal_pay',
        ])->assertOk();

        $api->getJson("/api/v1/suspended-invoices/{$suspended['id']}")
            ->assertOk()
            ->assertJsonPath('data.account_snapshot_name', 'Original name')
            ->assertJsonPath('data.account_snapshot_provider', 'palpay')
            ->assertJsonPath('data.account_snapshot_identifier', '0590000000');

        $this->actingAs($otherStoreUser, 'sanctum')
            ->getJson("/api/v1/suspended-invoices/{$suspended['id']}")
            ->assertNotFound();
        $this->actingAs($otherStoreUser, 'sanctum')
            ->postJson("/api/v1/suspended-invoices/{$suspended['id']}/confirm", [], $this->idem())
            ->assertNotFound();
    }

    public function test_cancel_retry_releases_reservation_and_audits_once(): void
    {
        $store = $this->makeStore();
        $owner = $this->makeUser($store);
        $product = $this->makeProduct($store, ['current_stock' => 3]);
        $account = ReceivingAccount::create([
            'store_id' => $store->id,
            'provider' => 'palpay',
            'account_name' => 'Main',
            'account_identifier' => '0590000000',
            'active' => true,
        ]);
        $api = $this->actingAs($owner, 'sanctum');
        $suspended = $api->postJson('/api/v1/suspended-invoices', [
            'items' => [['product_id' => $product->id, 'quantity' => 2]],
            'payment_method' => 'palpay',
            'receiving_account_id' => $account->id,
        ], $this->idem())->assertCreated()->json('data');
        $body = ['status' => 'cancelled', 'reason' => 'Transfer was not received'];
        $key = $this->idem();

        $first = $api->postJson("/api/v1/suspended-invoices/{$suspended['id']}/close", $body, $key)->assertOk();
        $retry = $api->postJson("/api/v1/suspended-invoices/{$suspended['id']}/close", $body, $key)->assertOk();

        $this->assertSame($first->getContent(), $retry->getContent());
        $retry->assertHeader('Idempotent-Replay', 'true');
        $this->assertSame(1, SuspendedInvoice::findOrFail($suspended['id'])->events()->where('event', 'cancelled')->count());
        $this->assertSame(1, InventoryReservation::where('suspended_invoice_id', $suspended['id'])
            ->where('status', InventoryReservation::STATUS_RELEASED)->count());
        $this->assertSame('3.000', $product->fresh()->current_stock);
    }

    public function test_receiving_account_rejects_empty_provider_and_blank_fields_on_create_and_update(): void
    {
        $store = $this->makeStore();
        $owner = $this->makeUser($store);
        $api = $this->actingAs($owner, 'sanctum');

        $api->postJson('/api/v1/receiving-accounts', [
            'provider' => '',
            'account_name' => '   ',
            'account_identifier' => '',
        ], $this->idem())
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['provider', 'account_name', 'account_identifier']);

        $account = ReceivingAccount::create([
            'store_id' => $store->id,
            'provider' => 'palpay',
            'account_name' => 'Main',
            'account_identifier' => '0590000000',
            'active' => true,
        ]);

        $api->patchJson("/api/v1/receiving-accounts/{$account->id}", [
            'provider' => '',
            'account_name' => '',
            'account_identifier' => '',
        ])
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['provider', 'account_name', 'account_identifier']);
    }

    public function test_double_confirm_with_distinct_idempotency_keys_finalizes_once_and_preserves_stock(): void
    {
        $store = $this->makeStore();
        $owner = $this->makeUser($store);
        $product = $this->makeProduct($store, ['current_stock' => 5]);
        $account = ReceivingAccount::create([
            'store_id' => $store->id,
            'provider' => 'palpay',
            'account_name' => 'Main',
            'account_identifier' => '0590000000',
            'active' => true,
        ]);
        $api = $this->actingAs($owner, 'sanctum');
        $suspended = $api->postJson('/api/v1/suspended-invoices', [
            'items' => [['product_id' => $product->id, 'quantity' => 3]],
            'payment_method' => 'palpay',
            'receiving_account_id' => $account->id,
        ], $this->idem())->assertCreated()->json('data');

        $first = $api->postJson("/api/v1/suspended-invoices/{$suspended['id']}/confirm", [], $this->idem())
            ->assertOk()
            ->assertJsonPath('already_completed', false);
        $second = $api->postJson("/api/v1/suspended-invoices/{$suspended['id']}/confirm", [], $this->idem())
            ->assertOk()
            ->assertJsonPath('already_completed', true);

        $this->assertSame($first->json('final_invoice.id'), $second->json('final_invoice.id'));
        $this->assertSame('2.000', $product->fresh()->current_stock);
        $this->assertSame(1, Invoice::count());
        $this->assertSame(1, StockMovement::where('type', StockMovement::TYPE_SALE)->count());
    }
}
