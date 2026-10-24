<?php

namespace App\Services;

use App\Enums\InvoiceSource;
use App\Models\Customer;
use App\Models\Debt;
use App\Models\Invoice;
use App\Models\Payment;
use App\Models\SaleReturn;
use App\Support\BusinessClock;
use App\Support\Money;
use Carbon\CarbonImmutable;
use Illuminate\Support\Collection;

/**
 * US-0302 (FR-12–14, UC-06, D-10): a customer's financial history as one dated list of events with
 * a running balance. Debits raise what the customer owes (credit sales, opening debts, payment
 * reversals); credits lower it (payments, the debt part of returns). A voided sale stays in the
 * list with no effect, and a refund paid in cash never touches the balance.
 *
 * The summary is computed from the same events, so it always equals the statement (AC2).
 */
class StatementService
{
    private const CAUSAL_ORDER = ['opening_debt' => 0, 'sale' => 0, 'payment' => 1, 'return' => 2, 'payment_reversal' => 3];

    /**
     * @return array{opening_balance: string, closing_balance: string, events: list<array<string, mixed>>}
     */
    public function statement(Customer $customer, ?string $from = null, ?string $to = null): array
    {
        $timezone = BusinessClock::forStore($customer->store)->timezone();
        $start = $from ? CarbonImmutable::parse($from, $timezone)->startOfDay()->utc() : null;
        $end = $to ? CarbonImmutable::parse($to, $timezone)->endOfDay()->utc() : null;

        $opening = '0.00';
        $balance = '0.00';
        $rows = [];

        foreach ($this->events($customer) as $event) {
            $effect = Money::sub($event['debit'], $event['credit']);
            if ($start && $event['at']->lt($start)) {
                $opening = Money::add($opening, $effect);
                $balance = $opening;
                continue;
            }
            if ($end && $event['at']->gt($end)) {
                break;
            }
            $balance = Money::add($balance, $effect);
            $rows[] = [...array_diff_key($event, ['order' => 0, 'seq' => 0]), 'at' => $event['at']->toISOString(), 'balance' => $balance];
        }

        return [
            'opening_balance' => $opening,
            'closing_balance' => $balance,
            'events' => $rows,
        ];
    }

    /** @return array<string, mixed> AC1 of US-0303: total, paid, returned, remaining, overdue */
    public function summary(Customer $customer): array
    {
        $events = $this->events($customer);
        $sum = fn(string $type, string $side) => Money::sum($events->where('type', $type)->pluck($side));

        $totalDebt = Money::add($sum('sale', 'debit'), $sum('opening_debt', 'debit'));
        $paid = Money::sub($sum('payment', 'credit'), $sum('payment_reversal', 'debit'));
        $returned = $sum('return', 'credit');
        $today = BusinessClock::forStore($customer->store)->now()->toDateString();

        $open = Debt::query()
            ->where('store_id', $customer->store_id)
            ->where('customer_id', $customer->id)
            ->where('status', '<>', Debt::STATUS_CANCELLED)
            ->where('remaining_amount', '>', 0);

        return [
            'customer_id' => $customer->id,
            'total_debt' => $totalDebt,
            'paid' => $paid,
            'returned' => $returned,
            'remaining' => Money::sub(Money::sub($totalDebt, $paid), $returned),
            'overdue' => Money::sum((clone $open)->whereDate('due_date', '<', $today)->pluck('remaining_amount')),
            'open_debts_count' => (clone $open)->count(),
            'credit_limit' => $customer->credit_limit === null ? null : Money::of($customer->credit_limit),
            'last_activity_at' => $events->last()['at']?->toISOString(),
        ];
    }

    /** @return Collection<int, array<string, mixed>> every event, oldest first */
    private function events(Customer $customer): Collection
    {
        $events = collect();

        $invoices = Invoice::query()
            ->where('store_id', $customer->store_id)
            ->where('customer_id', $customer->id)
            ->with(['debt', 'creator'])
            ->get();

        foreach ($invoices as $invoice) {
            $opening = $invoice->source === InvoiceSource::OPENING_DEBT;
            $voided = $invoice->isVoided();
            $owed = $invoice->debt ? Money::of($invoice->debt->amount) : '0.00';
            $events->push($this->event(
                $invoice->created_at,
                $opening ? 'opening_debt' : 'sale',
                $voided ? '0.00' : $owed,
                '0.00',
                [
                    'invoice_id' => $invoice->id,
                    'total_amount' => Money::of($invoice->total_amount),
                    'paid_at_sale' => Money::of($invoice->paid_amount),
                    'due_date' => $invoice->debt?->due_date?->toDateString(),
                    'voided' => $voided,
                    'void_reason' => $invoice->void_reason,
                    'by' => $invoice->creator?->name,
                ],
            ));
        }

        $payments = Payment::query()
            ->where('store_id', $customer->store_id)
            ->where('customer_id', $customer->id)
            ->with(['debt', 'creator', 'reverser'])
            ->get()
            ->groupBy(fn(Payment $payment) => $payment->payment_group_id ?? 'single_' . $payment->id);

        foreach ($payments as $group) {
            $first = $group->first();
            $amount = Money::sum($group->pluck('amount'));
            $meta = [
                'payment_id' => $first->id,
                'payment_group_id' => $first->payment_group_id,
                'method' => $first->method,
                'invoice_ids' => $group->map(fn(Payment $p) => $p->debt?->invoice_id)->filter()->unique()->values()->all(),
            ];
            $events->push($this->event($first->paid_at, 'payment', '0.00', $amount, $meta + ['by' => $first->creator?->name]));

            if ($group->every(fn(Payment $p) => $p->is_reversed)) {
                $events->push($this->event($group->max('reversed_at'), 'payment_reversal', $amount, '0.00', $meta + [
                    'reason' => $first->reversal_reason,
                    'by' => $first->reverser?->name,
                ]));
            }
        }

        $returns = SaleReturn::query()
            ->where('store_id', $customer->store_id)
            ->where('customer_id', $customer->id)
            ->with('creator')
            ->get();

        foreach ($returns as $return) {
            $events->push($this->event($return->created_at, 'return', '0.00', Money::of($return->debt_reduction), [
                'sale_return_id' => $return->id,
                'invoice_id' => $return->invoice_id,
                'total_amount' => Money::of($return->total_amount),
                'refund_amount' => Money::of($return->refund_amount),
                'reason' => $return->reason,
                'by' => $return->creator?->name,
            ]));
        }

        // Same second: causal order (a payment follows its sale, a reversal its payment).
        return $events
            ->sortBy([['at', 'asc'], ['order', 'asc'], ['seq', 'asc']])
            ->values();
    }

    private function event($at, string $type, string $debit, string $credit, array $meta): array
    {
        static $seq = 0;

        return [
            'at' => CarbonImmutable::parse($at)->utc(),
            'type' => $type,
            'debit' => $debit,
            'credit' => $credit,
            'order' => self::CAUSAL_ORDER[$type],
            'seq' => ++$seq,
            ...$meta,
        ];
    }
}
