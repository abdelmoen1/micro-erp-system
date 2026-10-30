<?php

namespace App\Services;

use App\Exceptions\ApiException;
use App\Models\Store;
use App\Models\User;
use Illuminate\Support\Facades\DB;

/**
 * Platform admin: permanently delete a store with everything in it (members, customers, sales, debts,
 * payments, returns, products, stock and its audit history). The schema restricts deleting a store that
 * has financial rows, so the rows are removed child-first in one transaction: all or nothing.
 * The deletion itself is audited in the admin's own store, because the deleted store's history goes with it.
 */
class StoreDeletionService
{
    public function __construct(private readonly AuditService $audit) {}

    /** @return array<string, int> rows removed per kind, as recorded in the audit entry */
    public function delete(Store $store, User $admin): array
    {
        return DB::transaction(function () use ($store, $admin) {
            $locked = Store::query()->lockForUpdate()->findOrFail($store->id);

            // A platform admin's own store holds the admin account; deleting it would lock the owner out.
            if ($locked->users()->where('is_platform_admin', true)->exists()) {
                throw ApiException::conflict('STORE_HAS_PLATFORM_ADMIN', 'لا يمكن حذف متجر فيه حساب مالك المنصة.');
            }

            $owner = $locked->owner;
            $userIds = $locked->users()->pluck('id');
            $emails = $locked->users()->pluck('email');
            $invoiceIds = DB::table('invoices')->where('store_id', $locked->id)->pluck('id');
            $debtIds = DB::table('debts')->where('store_id', $locked->id)->pluck('id');
            $returnIds = DB::table('sale_returns')->where('store_id', $locked->id)->pluck('id');

            $removed = [
                'users' => $userIds->count(),
                'customers' => DB::table('customers')->where('store_id', $locked->id)->count(),
                'products' => DB::table('products')->where('store_id', $locked->id)->count(),
                'invoices' => $invoiceIds->count(),
                'debts' => $debtIds->count(),
            ];

            DB::table('sale_return_items')->whereIn('sale_return_id', $returnIds)->delete();
            DB::table('sale_returns')->whereIn('id', $returnIds)->delete();
            DB::table('payments')
                ->where(fn($q) => $q->where('store_id', $locked->id)->orWhereIn('debt_id', $debtIds))
                ->delete();
            DB::table('debts')->whereIn('id', $debtIds)->delete();
            DB::table('supplier_payments')->where('store_id', $locked->id)->delete();
            DB::table('purchase_items')
                ->whereIn('purchase_invoice_id', DB::table('purchase_invoices')->where('store_id', $locked->id)->select('id'))
                ->delete();
            DB::table('purchase_invoices')->where('store_id', $locked->id)->delete();
            DB::table('suppliers')->where('store_id', $locked->id)->delete();
            DB::table('stock_movements')->where('store_id', $locked->id)->delete();
            DB::table('invoice_items')->whereIn('invoice_id', $invoiceIds)->delete();
            DB::table('invoices')->whereIn('id', $invoiceIds)->delete();
            DB::table('products')->where('store_id', $locked->id)->delete();
            DB::table('customers')->where('store_id', $locked->id)->delete();
            DB::table('idempotency_keys')->where('store_id', $locked->id)->delete();
            DB::table('audit_logs')->where('store_id', $locked->id)->delete();
            DB::table('store_invitations')->where('store_id', $locked->id)->delete();
            DB::table('support_tickets')->where('store_id', $locked->id)->delete();
            DB::table('personal_access_tokens')
                ->where('tokenable_type', (new User())->getMorphClass())
                ->whereIn('tokenable_id', $userIds)
                ->delete();
            DB::table('sessions')->whereIn('user_id', $userIds)->delete();
            DB::table('password_reset_tokens')->whereIn('email', $emails)->delete();
            DB::table('users')->whereIn('id', $userIds)->delete();
            $locked->delete();

            $this->audit->record(
                'platform.store_deleted',
                'Store',
                ['entity_id' => (string) $locked->id, 'name' => $locked->name, 'phone' => $locked->phone]
                    + ($owner ? ['owner' => $owner->only(['id', 'name', 'phone'])] : [])
                    + ['removed' => $removed],
                $admin,
            );

            return $removed;
        });
    }
}
