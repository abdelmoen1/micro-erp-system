<?php

namespace App\Services;

use App\Exceptions\ApiException;
use App\Models\Store;
use App\Models\SubscriptionOrder;
use App\Models\SubscriptionOrderEvent;
use App\Models\SubscriptionPayment;
use App\Models\SubscriptionPlan;
use App\Models\User;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

/**
 * Subscription orders and their only way to activation: a confirmed payment (an admin who verified
 * the money arrived, or a provider notification whose signature was verified). Every step is
 * recorded in append-only order events. See SUBSCRIPTION_ARCHITECTURE.md.
 */
class SubscriptionService
{
    /** Open orders a store may hold at once (stops request spam). */
    public const MAX_OPEN_ORDERS = 3;

    public function __construct(private readonly AuditService $audit) {}

    /** A new order at the plan's current server price. A store re-asking for the same plan gets its open order back. */
    public function createOrder(Store $store, User $user, SubscriptionPlan $plan, string $channel, ?string $provider = null): SubscriptionOrder
    {
        if (!$plan->isOrderable()) {
            throw ApiException::conflict('PLAN_UNAVAILABLE', 'هذه الباقة غير متاحة للشراء حالياً.');
        }

        return DB::transaction(function () use ($store, $user, $plan, $channel, $provider) {
            Store::query()->lockForUpdate()->findOrFail($store->id);
            $open = SubscriptionOrder::where('store_id', $store->id)->whereIn('status', SubscriptionOrder::OPEN);

            $same = (clone $open)->where('subscription_plan_id', $plan->id)->where('channel', $channel)
                ->where('amount', $plan->price)->where('currency', $plan->currency)->latest('id')->first();
            if ($same) {
                return $same;
            }
            if ((clone $open)->count() >= self::MAX_OPEN_ORDERS) {
                throw ApiException::conflict('TOO_MANY_OPEN_ORDERS', 'لديك طلبات اشتراك مفتوحة. انتظر مراجعتها أو اطلب إلغاءها.');
            }

            $order = SubscriptionOrder::create([
                'store_id' => $store->id,
                'store_name' => $store->name,
                'requested_by' => $user->id,
                'subscription_plan_id' => $plan->id,
                'plan_snapshot' => $plan->snapshot(),
                'duration_months' => $plan->duration_months,
                'amount' => $plan->price,
                'currency' => $plan->currency,
                'channel' => $channel,
                'provider' => $provider,
                'status' => SubscriptionOrder::PENDING_CONTACT,
            ]);
            $this->event($order, $user, 'created', null, $order->status);
            $this->audit->record('subscription.order_created', $order, ['reference' => $order->reference, 'plan' => $plan->code, 'channel' => $channel], $user, $store->id);

            return $order;
        });
    }

    /** An admin moves a manual order along (never to `paid`: that needs confirmPayment). */
    public function transition(SubscriptionOrder $order, string $to, User $admin, ?string $note = null): SubscriptionOrder
    {
        return DB::transaction(function () use ($order, $to, $admin, $note) {
            $locked = SubscriptionOrder::query()->lockForUpdate()->findOrFail($order->id);
            $allowed = SubscriptionOrder::MANUAL_TRANSITIONS[$locked->status] ?? [];
            if (!in_array($to, $allowed, true)) {
                throw ApiException::conflict('INVALID_ORDER_TRANSITION', 'لا يمكن نقل الطلب من حالته الحالية إلى هذه الحالة.');
            }
            $from = $locked->status;
            $locked->forceFill(['status' => $to, 'reviewed_by' => $admin->id, 'reviewed_at' => now()])->save();
            $this->event($locked, $admin, 'status', $from, $to, $note);

            return $locked;
        });
    }

    public function addNote(SubscriptionOrder $order, User $admin, string $note): SubscriptionOrderEvent
    {
        return $this->event($order, $admin, 'note', null, null, $note);
    }

    /**
     * The admin independently verified that the money arrived. The amount and currency must match
     * the order exactly; the order must still be open. Activates the store's subscription.
     */
    public function confirmManualPayment(SubscriptionOrder $order, User $admin, array $data): SubscriptionOrder
    {
        return DB::transaction(function () use ($order, $admin, $data) {
            $locked = SubscriptionOrder::query()->lockForUpdate()->findOrFail($order->id);
            $this->assertPayable($locked, (string) $data['amount'], (string) $data['currency']);

            SubscriptionPayment::create([
                'subscription_order_id' => $locked->id,
                'kind' => SubscriptionPayment::KIND_PAYMENT,
                'source' => SubscriptionPayment::SOURCE_MANUAL,
                'amount' => $data['amount'],
                'currency' => $data['currency'],
                'method' => $data['payment_method'],
                'transaction_reference' => $data['transaction_reference'],
                'recorded_by' => $admin->id,
                'paid_at' => $data['paid_at'] ?? now(),
            ]);
            $this->event($locked, $admin, 'payment', $locked->status, null, $data['note'] ?? null, [
                'method' => $data['payment_method'],
                'transaction_reference' => $data['transaction_reference'],
                'amount' => (string) $data['amount'],
                'currency' => $data['currency'],
            ]);

            return $this->activate($locked, $admin, Carbon::parse($data['paid_at'] ?? now()));
        });
    }

    /**
     * A verified provider notification that the order was paid. Idempotent: the same provider
     * transaction twice changes nothing; a second transaction for an already paid order is refused.
     */
    public function confirmProviderPayment(SubscriptionOrder $order, string $provider, string $transactionId, string $amount, string $currency, Carbon $paidAt): SubscriptionOrder
    {
        return DB::transaction(function () use ($order, $provider, $transactionId, $amount, $currency, $paidAt) {
            $locked = SubscriptionOrder::query()->lockForUpdate()->findOrFail($order->id);

            $already = SubscriptionPayment::where('source', SubscriptionPayment::SOURCE_PROVIDER)
                ->where('provider', $provider)->where('transaction_reference', $transactionId)
                ->where('kind', SubscriptionPayment::KIND_PAYMENT)->exists();
            if ($already) {
                return $locked;
            }
            if ($locked->channel !== SubscriptionOrder::CHANNEL_ONLINE || $locked->provider !== $provider) {
                throw ApiException::conflict('ORDER_PROVIDER_MISMATCH', 'Order does not belong to this provider.');
            }
            $this->assertPayable($locked, $amount, $currency);

            SubscriptionPayment::create([
                'subscription_order_id' => $locked->id,
                'kind' => SubscriptionPayment::KIND_PAYMENT,
                'source' => SubscriptionPayment::SOURCE_PROVIDER,
                'amount' => $amount,
                'currency' => $currency,
                'method' => $provider,
                'transaction_reference' => $transactionId,
                'provider' => $provider,
                'paid_at' => $paidAt,
            ]);
            $this->event($locked, null, 'payment', $locked->status, null, null, ['provider' => $provider, 'transaction_reference' => $transactionId]);

            return $this->activate($locked, null, $paidAt);
        });
    }

    /** A provider reported a failed/cancelled payment for an open online order. */
    public function markProviderFailed(SubscriptionOrder $order, string $provider, ?string $reason): void
    {
        DB::transaction(function () use ($order, $provider, $reason) {
            $locked = SubscriptionOrder::query()->lockForUpdate()->findOrFail($order->id);
            if (!$locked->isOpen() || $locked->provider !== $provider) {
                return;
            }
            $from = $locked->status;
            $locked->forceFill(['status' => SubscriptionOrder::FAILED])->save();
            $this->event($locked, null, 'provider_event', $from, SubscriptionOrder::FAILED, $reason);
        });
    }

    /**
     * The new paid period: from the later of now (the confirmed activation), the current paid
     * expiry and the end of a running trial, for the order's duration. Must run inside the
     * transaction that holds the order lock.
     */
    private function activate(SubscriptionOrder $order, ?User $actor, Carbon $paidAt): SubscriptionOrder
    {
        if ($order->status === SubscriptionOrder::PAID || $order->activated_at) {
            throw ApiException::conflict('ORDER_ALREADY_ACTIVATED', 'تم تفعيل هذا الطلب من قبل.');
        }
        $store = Store::query()->lockForUpdate()->find($order->store_id);
        if (!$store) {
            throw ApiException::conflict('ORDER_STORE_DELETED', 'المتجر صاحب الطلب لم يعد موجوداً.');
        }

        $start = now();
        if ($store->hasPaidSubscription() && $store->subscription_expires_at?->gt($start)) {
            $start = $store->subscription_expires_at->copy();
        } elseif ($store->inTrial()) {
            $start = $store->trial_ends_at->copy();
        }
        $end = $start->copy()->addMonthsNoOverflow($order->duration_months);
        $from = $store->subscription_status;

        $store->forceFill([
            'subscription_status' => Store::SUBSCRIPTION_ACTIVE,
            'subscription_plan_id' => $order->subscription_plan_id,
            'subscription_started_at' => $store->hasPaidSubscription() ? ($store->subscription_started_at ?? now()) : now(),
            'subscription_expires_at' => $end,
            'subscription_changed_at' => now(),
            'subscription_changed_by' => $actor?->id,
        ])->save();

        $order->forceFill([
            'status' => SubscriptionOrder::PAID,
            'paid_at' => $paidAt,
            'activated_at' => now(),
            'period_starts_at' => $start,
            'period_ends_at' => $end,
            'reviewed_by' => $actor?->id ?? $order->reviewed_by,
            'reviewed_at' => $actor ? now() : $order->reviewed_at,
        ])->save();

        $this->event($order, $actor, 'activated', null, SubscriptionOrder::PAID, null, [
            'period_starts_at' => $start->toIso8601String(),
            'period_ends_at' => $end->toIso8601String(),
        ]);
        $this->audit->record('store.subscription_activated', $store, [
            'from' => $from,
            'to' => Store::SUBSCRIPTION_ACTIVE,
            'expires_at' => $end->toIso8601String(),
            'order' => $order->reference,
        ], $actor, $store->id);

        return $order;
    }

    private function assertPayable(SubscriptionOrder $order, string $amount, string $currency): void
    {
        if ($order->status === SubscriptionOrder::PAID) {
            throw ApiException::conflict('ORDER_ALREADY_ACTIVATED', 'تم تفعيل هذا الطلب من قبل.');
        }
        if (!$order->isOpen()) {
            throw ApiException::conflict('ORDER_NOT_OPEN', 'هذا الطلب مغلق ولا يقبل دفعة.');
        }
        if (bccomp($amount, (string) $order->amount, 2) !== 0 || strtoupper($currency) !== $order->currency) {
            throw ApiException::conflict('PAYMENT_AMOUNT_MISMATCH', 'المبلغ أو العملة لا يطابق الطلب.');
        }
    }

    private function event(SubscriptionOrder $order, ?User $actor, string $type, ?string $from, ?string $to, ?string $note = null, ?array $data = null): SubscriptionOrderEvent
    {
        return SubscriptionOrderEvent::create([
            'subscription_order_id' => $order->id,
            'actor_id' => $actor?->id,
            'type' => $type,
            'from_status' => $from,
            'to_status' => $to,
            'note' => $note,
            'data' => $data,
        ]);
    }
}
