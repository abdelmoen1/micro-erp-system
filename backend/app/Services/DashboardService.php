<?php

namespace App\Services;

use App\Models\Customer;
use App\Models\Debt;
use App\Models\Invoice;
use App\Models\Payment;
use App\Models\Product;
use App\Models\SaleReturn;
use App\Models\Store;
use App\Support\BusinessClock;
use App\Support\Money;
use App\Support\Quantity;
use Carbon\CarbonImmutable;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Collection;

class DashboardService
{
    public function __construct(private readonly DebtService $debts) {}

    public function dashboard(Store $store, string $period): array
    {
        $storeId = $store->id;
        $clock = BusinessClock::forStore($store);
        [$from, $to] = $clock->periodBounds($period);

        $invoiceMetrics = $this->invoiceMetrics($storeId, $from, $to);
        $paymentMetrics = $this->paymentMetrics($storeId, $clock, $from, $to);
        $debtMetrics = $this->debtMetrics($storeId);
        $customerMetrics = $this->customerMetrics($storeId);
        // US-0801 AC5: debts created in the period minus those cancelled by a void in the period.
        $invoiceMetrics['new_debt'] = $this->newDebt($storeId, $from, $to);
        $insights = $this->insights($store);

        return [
            'period' => [
                'key' => $period,
                'from' => $from->toISOString(),
                'to' => $to->toISOString(),
                'timezone' => $clock->timezone(),
            ],
            'summary' => [
                'total_sales' => $invoiceMetrics['total_sales'],
                'cash_sales' => $invoiceMetrics['cash_sales'],
                'credit_sales' => $invoiceMetrics['credit_sales'],
                // D-08: money taken at the till vs. what the period's sales left on credit.
                'collected_at_sale' => $invoiceMetrics['collected_at_sale'],
                'new_debt' => $invoiceMetrics['new_debt'],
                'total_collected_payments' => $paymentMetrics['total_collected'],
                'total_remaining_debt' => $debtMetrics['total_remaining'],
                'customers_count' => $customerMetrics['total'],
                'invoices_count' => $invoiceMetrics['total'],
                'low_stock_count' => $insights['low_stock']['count'],
            ],
            // US-0801 AC1: money in at the till vs repayments of debts, and their total.
            'collections' => [
                'at_sale' => $invoiceMetrics['collected_at_sale'],
                'debt_repayments' => $paymentMetrics['total_collected'],
                'total' => Money::add($invoiceMetrics['collected_at_sale'], $paymentMetrics['total_collected']),
            ],
            // AC4: returns are their own figure; voided sales are already out of the totals.
            'returns' => $this->returnMetrics($storeId, $from, $to),
            'insights' => $insights,
            'customers' => $customerMetrics,
            'invoices' => [
                'total' => $invoiceMetrics['total'],
                'cash' => $invoiceMetrics['cash'],
                'debt' => $invoiceMetrics['debt'],
                'total_value' => $invoiceMetrics['total_value'],
            ],
            'sales' => [
                'total' => $invoiceMetrics['total_sales'],
                'cash' => $invoiceMetrics['cash_sales'],
                'credit' => $invoiceMetrics['credit_sales'],
            ],
            'payments' => [
                'total_collected' => $paymentMetrics['total_collected'],
                'count' => $paymentMetrics['count'],
                'today' => $paymentMetrics['today'],
                'this_month' => $paymentMetrics['this_month'],
            ],
            'debts' => $debtMetrics,
            'charts' => [
                'sales' => $this->salesChart($storeId, $clock, $from, $to, $period),
                'payments' => $this->paymentsChart($storeId, $clock, $from, $to, $period),
                // W-05 «اليوم حسب الساعة»: only for period=today.
                'sales_hourly' => $period === 'today' ? $this->hourlySales($storeId, $clock, $from, $to) : null,
            ],
            'recent_invoices' => $this->recentInvoices($storeId, $from, $to),
            'recent_payments' => $this->recentPayments($storeId, $from, $to),
        ];
    }

    private function newDebt(int $storeId, CarbonImmutable $from, CarbonImmutable $to): string
    {
        $range = BusinessClock::toUtc($from, $to);
        $created = Debt::query()->where('store_id', $storeId)->whereBetween('created_at', $range)->pluck('amount');
        $cancelled = Debt::query()
            ->where('store_id', $storeId)
            ->where('status', Debt::STATUS_CANCELLED)
            ->whereHas('invoice', fn(Builder $q) => $q->whereBetween('voided_at', $range))
            ->pluck('amount');

        return Money::sub(Money::sum($created), Money::sum($cancelled));
    }

    /** @return array{count: int, total: string, debt_reduction: string, refunded: string} */
    private function returnMetrics(int $storeId, CarbonImmutable $from, CarbonImmutable $to): array
    {
        $returns = SaleReturn::query()
            ->where('store_id', $storeId)
            ->whereBetween('created_at', BusinessClock::toUtc($from, $to))
            ->get(['total_amount', 'debt_reduction', 'refund_amount']);

        return [
            'count' => $returns->count(),
            'total' => Money::sum($returns->pluck('total_amount')),
            'debt_reduction' => Money::sum($returns->pluck('debt_reduction')),
            'refunded' => Money::sum($returns->pluck('refund_amount')),
        ];
    }

    /** US-0801 AC2–AC3: the cards that tell the owner what needs attention now. */
    private function insights(Store $store): array
    {
        $overdue = $this->debts->query($store, 'overdue');
        $dueToday = $this->debts->query($store, 'due_today');
        $low = Product::query()->forStore($store->id)->active()->whereColumn('current_stock', '<=', 'minimum_stock');

        return [
            'overdue' => ['count' => (clone $overdue)->count(), 'amount' => Money::sum((clone $overdue)->pluck('remaining_amount'))],
            'due_today' => ['count' => (clone $dueToday)->count(), 'amount' => Money::sum((clone $dueToday)->pluck('remaining_amount'))],
            'low_stock' => [
                'count' => (clone $low)->count(),
                'items' => (clone $low)->orderBy('current_stock')->orderBy('name')->limit(5)->get()
                    ->map(fn(Product $p) => [
                        'id' => $p->id,
                        'name' => $p->name,
                        'unit' => $p->unit,
                        'current_stock' => Quantity::format($p->current_stock, $p->unit),
                        'minimum_stock' => Quantity::format($p->minimum_stock, $p->unit),
                    ])->values(),
            ],
            'negative_stock' => ['count' => Product::query()->forStore($store->id)->active()->where('current_stock', '<', 0)->count()],
            'top_balances' => $this->debts->balances($store, 5),
        ];
    }

    private function invoicesBetween(int $storeId, CarbonImmutable $from, CarbonImmutable $to): Builder
    {
        // A voided sale never happened for the numbers (US-0503).
        return Invoice::query()
            ->where('store_id', $storeId)
            ->where('status', Invoice::STATUS_ACTIVE)
            ->whereBetween('created_at', BusinessClock::toUtc($from, $to));
    }

    private function invoiceMetrics(int $storeId, CarbonImmutable $from, CarbonImmutable $to): array
    {
        $invoices = $this->invoicesBetween($storeId, $from, $to)
            ->get(['total_amount', 'paid_amount', 'has_debt', 'source']);

        $sales = $invoices->filter(fn(Invoice $invoice) => $invoice->source?->value === 'sale');
        $collected = Money::sum($sales->pluck('paid_amount'));

        return [
            'collected_at_sale' => $collected,
            'new_debt' => Money::sub(Money::sum($sales->pluck('total_amount')), $collected),
            'total' => $invoices->count(),
            'cash' => $invoices->where('has_debt', false)->count(),
            'debt' => $invoices->where('has_debt', true)->count(),
            'total_value' => Money::sum($invoices->pluck('total_amount')),
            'total_sales' => Money::sum($sales->pluck('total_amount')),
            'cash_sales' => Money::sum($sales->where('has_debt', false)->pluck('total_amount')),
            'credit_sales' => Money::sum($sales->where('has_debt', true)->pluck('total_amount')),
        ];
    }

    private function paymentQuery(int $storeId): Builder
    {
        return Payment::query()->whereHas(
            'debt',
            fn(Builder $query) =>
            $query->where('store_id', $storeId)
        );
    }

    private function collectedBetween(int $storeId, CarbonImmutable $from, CarbonImmutable $to): Builder
    {
        return $this->paymentQuery($storeId)
            ->where('is_reversed', false)
            ->whereBetween('paid_at', BusinessClock::toUtc($from, $to));
    }

    private function paymentMetrics(int $storeId, BusinessClock $clock, CarbonImmutable $from, CarbonImmutable $to): array
    {
        $now = $clock->now();
        $period = $this->collectedBetween($storeId, $from, $to)->pluck('amount');

        return [
            'total_collected' => Money::sum($period),
            'count' => $period->count(),
            'today' => Money::sum(
                $this->collectedBetween($storeId, $now->startOfDay(), $now->endOfDay())->pluck('amount')
            ),
            'this_month' => Money::sum(
                $this->collectedBetween($storeId, $now->startOfMonth(), $now->endOfMonth())->pluck('amount')
            ),
        ];
    }

    private function debtMetrics(int $storeId): array
    {
        $query = Debt::query()->where('store_id', $storeId)->where('status', '<>', Debt::STATUS_CANCELLED);
        $statuses = (clone $query)->select('status')->selectRaw('COUNT(*) as count')->groupBy('status')->pluck('count', 'status');

        return [
            'total_debt' => Money::sum((clone $query)->pluck('amount')),
            'total_remaining' => Money::sum((clone $query)->pluck('remaining_amount')),
            'paid_count' => (int) ($statuses['paid'] ?? 0),
            'partially_paid_count' => (int) ($statuses['partially_paid'] ?? 0),
            'unpaid_count' => (int) ($statuses['unpaid'] ?? 0),
        ];
    }

    private function customerMetrics(int $storeId): array
    {
        $customers = Customer::query()->where('store_id', $storeId);

        return [
            'total' => (int) (clone $customers)->count(),
            'with_outstanding_debts' => (int) (clone $customers)->whereHas(
                'invoices.debt',
                fn(Builder $query) =>
                $query->where('store_id', $storeId)->where('remaining_amount', '>', 0)
            )->count(),
        ];
    }

    /**
     * Sales per local day (or month for this_year), bucketed in the store timezone.
     */
    private function salesChart(int $storeId, BusinessClock $clock, CarbonImmutable $from, CarbonImmutable $to, string $period): array
    {
        $rows = $this->invoicesBetween($storeId, $from, $to)
            ->where('source', 'sale')
            ->toBase()
            ->get(['created_at', 'total_amount', 'has_debt']);

        $byBucket = $this->groupByLocalBucket($rows, $clock, 'created_at', $period);

        return $this->buckets($from, $to, $period, function (string $key, string $label) use ($byBucket): array {
            $bucket = $byBucket->get($key, collect());

            return [
                $label => $key,
                'amount' => Money::sum($bucket->pluck('total_amount')),
                'cash_amount' => Money::sum($bucket->filter(fn($row) => !(bool) $row->has_debt)->pluck('total_amount')),
                'credit_amount' => Money::sum($bucket->filter(fn($row) => (bool) $row->has_debt)->pluck('total_amount')),
            ];
        });
    }

    /** Sales per local hour of today (24 buckets, "00"–"23"), in the store timezone. */
    private function hourlySales(int $storeId, BusinessClock $clock, CarbonImmutable $from, CarbonImmutable $to): array
    {
        $byHour = $this->invoicesBetween($storeId, $from, $to)
            ->where('source', 'sale')
            ->toBase()
            ->get(['created_at', 'total_amount'])
            ->groupBy(fn($row) => CarbonImmutable::parse($row->created_at, 'UTC')->setTimezone($clock->timezone())->format('H'));

        return array_map(fn(int $hour) => [
            'hour' => sprintf('%02d', $hour),
            'amount' => Money::sum($byHour->get(sprintf('%02d', $hour), collect())->pluck('total_amount')),
        ], range(0, 23));
    }

    private function paymentsChart(int $storeId, BusinessClock $clock, CarbonImmutable $from, CarbonImmutable $to, string $period): array
    {
        $rows = $this->collectedBetween($storeId, $from, $to)
            ->toBase()
            ->get(['paid_at', 'amount']);

        $byBucket = $this->groupByLocalBucket($rows, $clock, 'paid_at', $period);

        return $this->buckets($from, $to, $period, fn(string $key, string $label): array => [
            $label => $key,
            'amount' => Money::sum($byBucket->get($key, collect())->pluck('amount')),
        ]);
    }

    private function groupByLocalBucket(Collection $rows, BusinessClock $clock, string $column, string $period): Collection
    {
        return $rows->groupBy(function ($row) use ($clock, $column, $period) {
            $date = $clock->localDate($row->{$column});

            return $period === 'this_year' ? substr($date, 0, 7) : $date;
        });
    }

    private function buckets(CarbonImmutable $from, CarbonImmutable $to, string $period, callable $format): array
    {
        $dates = [];
        $yearly = $period === 'this_year';
        $date = $yearly ? $from->startOfMonth() : $from->startOfDay();
        $lastDate = $yearly ? $to->startOfMonth() : $to->startOfDay();

        while ($date <= $lastDate) {
            $dates[] = $yearly
                ? $format($date->format('Y-m'), 'month')
                : $format($date->format('Y-m-d'), 'date');
            $date = $yearly ? $date->addMonth() : $date->addDay();
        }

        return $dates;
    }

    private function recentInvoices(int $storeId, CarbonImmutable $from, CarbonImmutable $to): array
    {
        return $this->invoicesBetween($storeId, $from, $to)
            ->with(['customer:id,name', 'debt:id,invoice_id,status'])->latest('created_at')->limit(10)->get()
            ->map(fn(Invoice $invoice) => [
                'id' => $invoice->id,
                'customer' => $invoice->customer ? ['id' => $invoice->customer->id, 'name' => $invoice->customer->name] : null,
                'total_amount' => Money::of($invoice->total_amount),
                'type' => $invoice->has_debt ? 'credit' : 'cash',
                'source' => $invoice->source?->value ?? $invoice->source,
                'status' => $invoice->has_debt ? ($invoice->debt?->status ?? 'unpaid') : 'cash',
                'created_at' => $invoice->created_at?->toISOString(),
            ])->all();
    }

    private function recentPayments(int $storeId, CarbonImmutable $from, CarbonImmutable $to): array
    {
        return $this->paymentQuery($storeId)->whereBetween('paid_at', BusinessClock::toUtc($from, $to))
            ->with('debt.invoice.customer:id,name')->latest('paid_at')->limit(10)->get()
            ->map(fn(Payment $payment) => [
                'id' => $payment->id,
                'customer' => $payment->debt?->invoice?->customer ? [
                    'id' => $payment->debt->invoice->customer->id,
                    'name' => $payment->debt->invoice->customer->name,
                ] : null,
                'amount' => Money::of($payment->amount),
                'method' => $payment->method,
                'paid_at' => $payment->paid_at?->toISOString(),
                'is_reversed' => (bool) $payment->is_reversed,
                'status' => $payment->is_reversed ? 'reversed' : 'active',
            ])->all();
    }
}
