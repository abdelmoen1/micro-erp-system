<?php

namespace App\Services;

use App\Enums\UserRole;
use App\Exceptions\ApiException;
use App\Models\AccountDeletionRequest;
use App\Models\Store;
use App\Models\User;
use App\Support\PhoneNumber;
use Illuminate\Support\Facades\DB;

/**
 * Account deletion (ACCOUNT_DELETION_PLAN.md).
 *
 * - Staff (manager/employee): anonymised at once. Name, phone, password and sign-ins are removed;
 *   the shop's sales, payments and history keep pointing at an account named «حساب محذوف».
 * - Owner: the STORE is closed. Every member is signed out now; after the grace period
 *   (hisbah.deletion_grace_days) StoreDeletionService removes the store and all its business data.
 *   The owner may cancel before that date. Hisbah's own subscription orders and payments are kept
 *   (store id cleared, store name kept) as Hisbah's sales records.
 */
class AccountDeletionService
{
    public const DELETED_NAME = 'حساب محذوف';

    public function __construct(
        private readonly StoreDeletionService $stores,
        private readonly AuditService $audit,
    ) {}

    /** Staff or owner, by role. [$confirmStoreName] is required from an owner. */
    public function request(User $user, string $source, ?string $confirmStoreName = null, ?string $reason = null): AccountDeletionRequest
    {
        if ($user->isPlatformAdmin()) {
            throw ApiException::conflict('PLATFORM_ADMIN_ACCOUNT', 'حساب مالك المنصة لا يُحذف من هنا. أزل صلاحية المنصة أولاً.');
        }

        return $user->hasRole(UserRole::OWNER)
            ? $this->closeStore($user, $source, $confirmStoreName, $reason)
            : $this->deleteStaff($user, $source, $reason);
    }

    public function deleteStaff(User $user, string $source, ?string $reason = null, ?User $processedBy = null, ?AccountDeletionRequest $existing = null): AccountDeletionRequest
    {
        return DB::transaction(function () use ($user, $source, $reason, $processedBy, $existing) {
            $locked = User::query()->lockForUpdate()->findOrFail($user->id);
            $phone = $locked->phone;
            $storeId = $locked->store_id;

            $locked->tokens()->delete();
            DB::table('sessions')->where('user_id', $locked->id)->delete();
            if ($phone) {
                DB::table('phone_otps')->where('phone', $phone)->delete();
            }
            $locked->forceFill([
                'name' => self::DELETED_NAME,
                'phone' => null,
                'email' => null,
                'password' => null,
                'google_id' => null,
                'phone_verified_at' => null,
                'status' => User::STATUS_INACTIVE,
            ])->save();

            $request = $existing ?? new AccountDeletionRequest(['user_id' => $locked->id, 'store_id' => $storeId, 'type' => AccountDeletionRequest::TYPE_STAFF, 'source' => $source]);
            $request->fill([
                'status' => AccountDeletionRequest::COMPLETED,
                'phone_masked' => $request->phone_masked ?? ($phone ? PhoneNumber::masked($phone) : null),
                'reason' => $request->reason ?? $reason,
                'completed_at' => now(),
                'processed_by' => $processedBy?->id,
                'result' => ['anonymised_user_id' => $locked->id, 'business_records_kept' => true],
            ])->save();

            if ($storeId) {
                $this->audit->record('user.account_deleted', $locked, ['source' => $source, 'request' => $request->reference], $processedBy, $storeId);
            }

            return $request;
        });
    }

    public function closeStore(User $owner, string $source, ?string $confirmStoreName, ?string $reason = null, ?User $processedBy = null, ?AccountDeletionRequest $existing = null): AccountDeletionRequest
    {
        return DB::transaction(function () use ($owner, $source, $confirmStoreName, $reason, $processedBy, $existing) {
            $store = Store::query()->lockForUpdate()->findOrFail($owner->store_id);
            if ($processedBy === null && trim((string) $confirmStoreName) !== trim($store->name)) {
                throw ApiException::businessRule('VALIDATION_FAILED', 'اكتب اسم المتجر كما هو لتأكيد الحذف.', ['confirm_store_name' => ['اسم المتجر غير مطابق.']]);
            }
            if ($store->users()->where('is_platform_admin', true)->exists()) {
                throw ApiException::conflict('STORE_HAS_PLATFORM_ADMIN', 'لا يمكن حذف متجر فيه حساب مالك المنصة.');
            }
            if ($store->isClosing()) {
                return AccountDeletionRequest::where('store_id', $store->id)->where('status', AccountDeletionRequest::SCHEDULED)->latest('id')->firstOrFail();
            }

            $when = now()->addDays(max(0, (int) config('hisbah.deletion_grace_days', 14)));
            $store->forceFill(['deletion_scheduled_for' => $when])->save();
            // Everyone is signed out now; only the owner may sign in again, to cancel.
            DB::table('personal_access_tokens')
                ->where('tokenable_type', (new User())->getMorphClass())
                ->whereIn('tokenable_id', $store->users()->pluck('id'))
                ->delete();

            $request = $existing ?? new AccountDeletionRequest(['user_id' => $owner->id, 'store_id' => $store->id, 'type' => AccountDeletionRequest::TYPE_STORE, 'source' => $source]);
            $request->fill([
                'status' => AccountDeletionRequest::SCHEDULED,
                'phone_masked' => $request->phone_masked ?? ($owner->phone ? PhoneNumber::masked($owner->phone) : null),
                'store_name' => $store->name,
                'reason' => $request->reason ?? $reason,
                'scheduled_for' => $when,
                'processed_by' => $processedBy?->id,
            ])->save();
            $this->audit->record('store.closure_scheduled', $store, ['request' => $request->reference, 'scheduled_for' => $when->toIso8601String(), 'source' => $source], $processedBy ?? $owner, $store->id);

            return $request;
        });
    }

    public function cancelClosure(User $owner): AccountDeletionRequest
    {
        return DB::transaction(function () use ($owner) {
            $store = Store::query()->lockForUpdate()->findOrFail($owner->store_id);
            $request = AccountDeletionRequest::where('store_id', $store->id)->where('status', AccountDeletionRequest::SCHEDULED)->latest('id')->first();
            if (!$store->isClosing() || !$request || !$owner->hasRole(UserRole::OWNER)) {
                throw ApiException::conflict('NO_SCHEDULED_DELETION', 'لا يوجد طلب حذف قائم لهذا المتجر.');
            }
            $store->forceFill(['deletion_scheduled_for' => null])->save();
            $request->forceFill(['status' => AccountDeletionRequest::CANCELLED])->save();
            $this->audit->record('store.closure_cancelled', $store, ['request' => $request->reference], $owner, $store->id);

            return $request;
        });
    }

    /** Scheduled job: delete every store whose grace period has ended. Returns how many. */
    public function processDue(): int
    {
        $done = 0;
        foreach (Store::whereNotNull('deletion_scheduled_for')->where('deletion_scheduled_for', '<=', now())->pluck('id') as $storeId) {
            $store = Store::find($storeId);
            $request = AccountDeletionRequest::where('store_id', $storeId)->where('status', AccountDeletionRequest::SCHEDULED)->latest('id')->first();
            $removed = $this->stores->delete($store, null);
            $request?->forceFill(['status' => AccountDeletionRequest::COMPLETED, 'completed_at' => now(), 'result' => ['removed' => $removed]])->save();
            $done++;
        }

        return $done;
    }

    /** Public form without a password: a request a platform admin verifies by hand. Same answer whether the number exists or not. */
    public function manualRequest(string $phone, ?string $reason): AccountDeletionRequest
    {
        $user = User::where('phone', $phone)->first();

        return AccountDeletionRequest::create([
            'user_id' => $user?->id,
            'store_id' => $user?->store_id,
            'type' => $user?->hasRole(UserRole::OWNER) ? AccountDeletionRequest::TYPE_STORE : AccountDeletionRequest::TYPE_STAFF,
            'source' => 'public',
            'status' => AccountDeletionRequest::PENDING_REVIEW,
            'phone_masked' => PhoneNumber::masked($phone),
            'store_name' => $user?->store?->name,
            'reason' => $reason,
        ]);
    }

    /** Platform admin completes a reviewed public request (identity verified outside the system). */
    public function approve(AccountDeletionRequest $request, User $admin): AccountDeletionRequest
    {
        if ($request->status !== AccountDeletionRequest::PENDING_REVIEW) {
            throw ApiException::conflict('REQUEST_NOT_PENDING', 'هذا الطلب ليس قيد المراجعة.');
        }
        $user = $request->user_id ? User::find($request->user_id) : null;
        if (!$user) {
            $request->forceFill(['status' => AccountDeletionRequest::REJECTED, 'processed_by' => $admin->id, 'result' => ['reason' => 'no_matching_account']])->save();

            return $request;
        }

        return $user->hasRole(UserRole::OWNER)
            ? $this->closeStore($user, 'public', null, null, $admin, $request)
            : $this->deleteStaff($user, 'public', null, $admin, $request);
    }
}
