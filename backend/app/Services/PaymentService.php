<?php

namespace App\Services;

use App\Exceptions\ApiException;
use App\Models\Customer;
use App\Models\Debt;
use App\Models\Payment;
use App\Models\User;
use App\Support\Money;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

/**
 * US-0703 payments v1 (D-10, D-11, DEF-10). Every payment names its store, customer and creator;
 * a debt's balance is always re-derived from facts by DebtLedger. A payment recorded as part of a
 * group (pay-all) can only be reversed with its whole group.
 */
class PaymentService
{
    public function __construct(
        private readonly DebtLedger $ledger,
        private readonly AuditService $audit,
    ) {}

    /** One payment on one debt. */
    public function payDebt(User $actor, int $debtId, string $amount, string $method, ?string $paidAt = null, ?string $notes = null): Payment
    {
        return DB::transaction(function () use ($actor, $debtId, $amount, $method, $paidAt, $notes) {
            $debt = Debt::query()
                ->whereKey($debtId)
                ->where('store_id', $actor->store_id)
                ->lockForUpdate()
                ->firstOrFail();

            if ($debt->status === Debt::STATUS_CANCELLED || Money::isZero($debt->remaining_amount)) {
                throw ApiException::businessRule('DEBT_ALREADY_PAID', 'هذا الدين مسدد بالكامل.', [
                    'debt_id' => ['هذا الدين مسدد بالكامل.'],
                ]);
            }

            if (Money::compare($amount, $debt->remaining_amount) > 0) {
                $message = 'مبلغ الدفعة أكبر من المبلغ المتبقي: ' . Money::of($debt->remaining_amount);
                throw ApiException::businessRule('PAYMENT_EXCEEDS_REMAINING', $message, ['amount' => [$message]]);
            }

            $payment = $this->record($actor, $debt, $amount, $method, $paidAt, $notes);
            $this->ledger->recalculate($debt);

            return $payment;
        });
    }

    /**
     * US-0705 AC2 / UC-13: a customer pays at the counter. Without an amount the whole remaining
     * balance is settled (pay-all); with one, it is allocated to open debts oldest due date first
     * (debts without a due date last), the last one partially. One group id ties the payments.
     *
     * @return array{payment_group_id: string, debts_count: int, total_paid: string, remaining_after: string}
     */
    public function payCustomer(User $actor, Customer $customer, ?string $amount, string $method, ?string $paidAt = null, ?string $notes = null): array
    {
        return DB::transaction(function () use ($actor, $customer, $amount, $method, $paidAt, $notes) {
            $debts = $this->openDebts($actor->store_id, $customer->id);

            if ($debts->isEmpty()) {
                throw ApiException::businessRule('NOTHING_TO_PAY', 'لا يوجد على هذا العميل أي مبلغ متبقي.', [
                    'customer' => ['لا يوجد على هذا العميل أي مبلغ متبقي.'],
                ]);
            }

            $owed = Money::sum($debts->pluck('remaining_amount'));
            $left = $amount === null ? $owed : Money::of($amount);

            if (Money::compare($left, $owed) > 0) {
                $message = 'مبلغ الدفعة أكبر من المبلغ المتبقي: ' . $owed;
                throw ApiException::businessRule('PAYMENT_EXCEEDS_REMAINING', $message, ['amount' => [$message]]);
            }

            $groupId = (string) Str::uuid();
            $paid = '0.00';
            $count = 0;

            foreach ($debts as $debt) {
                if (!Money::isPositive($left)) {
                    break;
                }
                $share = Money::compare($left, $debt->remaining_amount) < 0 ? $left : Money::of($debt->remaining_amount);
                $this->record($actor, $debt, $share, $method, $paidAt, $notes, $groupId);
                $this->ledger->recalculate($debt);
                $paid = Money::add($paid, $share);
                $left = Money::sub($left, $share);
                $count++;
            }

            return [
                'payment_group_id' => $groupId,
                'debts_count' => $count,
                'total_paid' => $paid,
                'remaining_after' => Money::sub($owed, $paid),
            ];
        });
    }

    /** D-11: a single payment of a group is never reversed alone (DEF-10). */
    public function reverse(User $actor, Payment $payment, string $reason): Payment
    {
        return DB::transaction(function () use ($actor, $payment, $reason) {
            $locked = Payment::query()->whereKey($payment->id)->lockForUpdate()->firstOrFail();

            if ($locked->payment_group_id !== null
                && Payment::query()->where('payment_group_id', $locked->payment_group_id)->count() > 1) {
                throw ApiException::businessRule(
                    'REVERSE_GROUP_REQUIRED',
                    'هذه الدفعة جزء من عملية سداد جماعية؛ اعكس العملية كاملة.',
                    ['payment' => ['هذه الدفعة جزء من عملية سداد جماعية؛ اعكس العملية كاملة.']],
                    ['payment_group_id' => $locked->payment_group_id],
                );
            }

            if ($locked->is_reversed) {
                throw ApiException::businessRule('PAYMENT_ALREADY_REVERSED', 'هذه الدفعة ملغاة بالفعل.', [
                    'payment' => ['هذه الدفعة ملغاة بالفعل.'],
                ]);
            }

            $debt = Debt::query()->whereKey($locked->debt_id)->lockForUpdate()->firstOrFail();
            $this->markReversed($actor, $locked, $reason);
            $this->ledger->recalculate($debt);

            $this->audit->record('payment.reversed', $locked, [
                'amount' => Money::of($locked->amount),
                'debt_id' => $debt->id,
                'customer_id' => $locked->customer_id,
                'reason' => $reason,
            ], $actor);

            return $locked;
        });
    }

    /** @return array{payment_group_id: string, debts_count: int, total_reversed: string} */
    public function reverseGroup(User $actor, string $groupId, string $reason): array
    {
        return DB::transaction(function () use ($actor, $groupId, $reason) {
            $group = Payment::query()
                ->where('payment_group_id', $groupId)
                ->where('store_id', $actor->store_id)
                ->lockForUpdate()
                ->get();

            // Unknown or another store's group: never reveal existence.
            abort_if($group->isEmpty(), 404);

            $live = $group->where('is_reversed', false);

            if ($live->isEmpty()) {
                throw ApiException::businessRule('PAYMENT_ALREADY_REVERSED', 'تم إلغاء عملية السداد هذه بالفعل.', [
                    'payment_group_id' => ['تم إلغاء عملية السداد هذه بالفعل.'],
                ]);
            }

            $debts = Debt::query()
                ->whereIn('id', $live->pluck('debt_id'))
                ->where('store_id', $actor->store_id)
                ->orderBy('id')
                ->lockForUpdate()
                ->get();

            foreach ($live as $payment) {
                $this->markReversed($actor, $payment, $reason);
            }

            foreach ($debts as $debt) {
                $this->ledger->recalculate($debt);
            }

            $total = Money::sum($live->pluck('amount'));

            $this->audit->record('payment_group.reversed', 'PaymentGroup', [
                'entity_id' => $groupId,
                'payments_count' => $live->count(),
                'total_reversed' => $total,
                'reason' => $reason,
            ], $actor);

            return [
                'payment_group_id' => $groupId,
                'debts_count' => $debts->count(),
                'total_reversed' => $total,
            ];
        });
    }

    /** @return Collection<int, Debt> open debts of the customer, locked, oldest due first */
    private function openDebts(int $storeId, int $customerId): Collection
    {
        return Debt::query()
            ->where('store_id', $storeId)
            ->where('customer_id', $customerId)
            ->where('status', '<>', Debt::STATUS_CANCELLED)
            ->where('remaining_amount', '>', 0)
            ->orderByRaw('CASE WHEN due_date IS NULL THEN 1 ELSE 0 END')
            ->orderBy('due_date')
            ->orderBy('id')
            ->lockForUpdate()
            ->get();
    }

    private function record(User $actor, Debt $debt, string $amount, string $method, ?string $paidAt, ?string $notes, ?string $groupId = null): Payment
    {
        return $debt->payments()->create([
            'store_id' => $debt->store_id,
            'customer_id' => $debt->customer_id,
            'amount' => Money::of($amount),
            'method' => $method,
            'paid_at' => $paidAt ?? now(),
            'notes' => $notes,
            'created_by' => $actor->id,
            'payment_group_id' => $groupId,
        ]);
    }

    private function markReversed(User $actor, Payment $payment, string $reason): void
    {
        $payment->update([
            'is_reversed' => true,
            'reversed_at' => now(),
            'reversed_by' => $actor->id,
            'reversal_reason' => $reason,
        ]);
    }
}
