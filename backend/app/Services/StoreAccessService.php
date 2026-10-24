<?php

namespace App\Services;

use App\Models\Store;
use App\Models\User;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

/**
 * Platform admin changes to a store: account access and the subscription. Each method changes
 * only its own columns, so suspending a store never touches its subscription and the reverse.
 * Every change stamps who and when on the store and writes an audit row into that store's history,
 * in the same transaction. Re-sending the current state is a no-op (no stamp, no audit row).
 */
class StoreAccessService
{
    public function __construct(private readonly AuditService $audit) {}

    public function setStatus(Store $store, string $status, ?string $reason, User $admin): Store
    {
        return DB::transaction(function () use ($store, $status, $reason, $admin) {
            $locked = Store::query()->lockForUpdate()->findOrFail($store->id);
            $from = $locked->status ?? Store::STATUS_ACTIVE;

            if ($from === $status) {
                return $locked;
            }

            $locked->forceFill([
                'status' => $status,
                'suspension_reason' => $status === Store::STATUS_SUSPENDED ? $reason : null,
                'status_changed_at' => now(),
                'status_changed_by' => $admin->id,
            ])->save();

            $this->audit->record(
                $status === Store::STATUS_SUSPENDED ? 'store.suspended' : 'store.reactivated',
                $locked,
                array_filter(['from' => $from, 'to' => $status, 'reason' => $reason], fn($v) => $v !== null),
                $admin,
                $locked->id,
            );

            return $locked;
        });
    }

    /**
     * Manual activation after the admin verified a payment. Activating an active subscription
     * with a new expiry is a renewal: the start date is kept and the expiry moves.
     */
    public function setSubscription(Store $store, string $status, ?Carbon $expiresAt, ?string $note, User $admin): Store
    {
        return DB::transaction(function () use ($store, $status, $expiresAt, $note, $admin) {
            $locked = Store::query()->lockForUpdate()->findOrFail($store->id);
            $from = $locked->subscription_status;
            $fromExpiry = $locked->subscription_expires_at;

            $activating = $status === Store::SUBSCRIPTION_ACTIVE;
            $unchanged = $from === $status
                && (!$activating || $fromExpiry?->toIso8601String() === $expiresAt?->toIso8601String());

            if ($unchanged) {
                return $locked;
            }

            $changes = [
                'subscription_status' => $status,
                'subscription_changed_at' => now(),
                'subscription_changed_by' => $admin->id,
            ];

            if ($activating) {
                $changes['subscription_expires_at'] = $expiresAt;
                if ($from !== Store::SUBSCRIPTION_ACTIVE || !$locked->subscription_started_at) {
                    $changes['subscription_started_at'] = now();
                }
            }

            $locked->forceFill($changes)->save();

            $this->audit->record(
                $activating ? 'store.subscription_activated' : 'store.subscription_deactivated',
                $locked,
                array_filter([
                    'from' => $from,
                    'to' => $status,
                    'previous_expires_at' => $fromExpiry?->toIso8601String(),
                    'expires_at' => $activating ? $expiresAt?->toIso8601String() : null,
                    'note' => $note,
                ], fn($v) => $v !== null),
                $admin,
                $locked->id,
            );

            return $locked;
        });
    }
}
