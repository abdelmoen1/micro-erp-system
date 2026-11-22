<?php

namespace Tests\Feature;

use App\Models\InventoryReservation;
use App\Models\ReceivingAccount;
use App\Models\SuspendedInvoice;
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

        $this->actingAs($owner, 'sanctum')
            ->patchJson("/api/v1/receiving-accounts/{$account->id}", ['active' => false])
            ->assertOk();
        $this->assertDatabaseHas('receiving_accounts', ['id' => $account->id, 'active' => false]);
    }
}
