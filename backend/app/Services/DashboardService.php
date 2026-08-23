<?php

namespace App\Services;

use App\Models\Customer;
use App\Models\Debt;
use App\Models\Invoice;
use App\Models\Payment;
use Carbon\CarbonImmutable;
use Illuminate\Database\Eloquent\Builder;

class DashboardService
{
    public function dashboard(int $storeId, string $period): array
    {
        [$from, $to] = $this->periodBounds($period);

        $invoiceMetrics = $this->invoiceMetrics($storeId, $from, $to);
        $paymentMetrics = $this->paymentMetrics($storeId, $from, $to);
        $debtMetrics = $this->debtMetrics($storeId);
        $customerMetrics = $this->customerMetrics($storeId);

        return [
            'period' => [
                'key' => $period,
                'from' => $from->toISOString(),
                'to' => $to->toISOString(),
                'timezone' => config('app.timezone'),
            ],
            'summary' => [
                'total_sales' => $invoiceMetrics['total_sales'],
                'cash_sales' => $invoiceMetrics['cash_sales'],
                'credit_sales' => $invoiceMetrics['credit_sales'],
                'total_collected_payments' => $paymentMetrics['total_collected'],
                'total_remaining_debt' => $debtMetrics['total_remaining'],
                'customers_count' => $customerMetrics['total'],
                'invoices_count' => $invoiceMetrics['total'],
            ],
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
                'sales' => $this->salesChart($storeId, $from, $to, $period),
                'payments' => $this->paymentsChart($storeId, $from, $to, $period),
            ],
            'recent_invoices' => $this->recentInvoices($storeId, $from, $to),
            'recent_payments' => $this->recentPayments($storeId, $from, $to),
        ];
    }

    private function periodBounds(string $period): array
    {
        $now = CarbonImmutable::now(config('app.timezone'));

        return match ($period) {
            'today' => [$now->startOfDay(), $now->endOfDay()],
            'this_week' => [$now->startOfWeek(), $now->endOfWeek()],
            'this_year' => [$now->startOfYear(), $now->endOfYear()],
            default => [$now->startOfMonth(), $now->endOfMonth()],
        };
    }

    private function invoiceMetrics(int $storeId, CarbonImmutable $from, CarbonImmutable $to): array
    {
        $row = Invoice::query()
            ->where('store_id', $storeId)
            ->whereBetween('created_at', [$from, $to])
            ->selectRaw('COUNT(*) as total')
            ->selectRaw('SUM(CASE WHEN has_debt = 0 THEN 1 ELSE 0 END) as cash')
            ->selectRaw('SUM(CASE WHEN has_debt = 1 THEN 1 ELSE 0 END) as debt')
            ->selectRaw('COALESCE(SUM(total_amount), 0) as total_value')
            ->selectRaw("COALESCE(SUM(CASE WHEN source = 'sale' THEN total_amount ELSE 0 END), 0) as total_sales")
            ->selectRaw("COALESCE(SUM(CASE WHEN source = 'sale' AND has_debt = 0 THEN total_amount ELSE 0 END), 0) as cash_sales")
            ->selectRaw("COALESCE(SUM(CASE WHEN source = 'sale' AND has_debt = 1 THEN total_amount ELSE 0 END), 0) as credit_sales")
            ->first();

        return [
            'total' => (int) $row->total,
            'cash' => (int) $row->cash,
            'debt' => (int) $row->debt,
            'total_value' => $this->money($row->total_value),
            'total_sales' => $this->money($row->total_sales),
            'cash_sales' => $this->money($row->cash_sales),
            'credit_sales' => $this->money($row->credit_sales),
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

    private function paymentMetrics(int $storeId, CarbonImmutable $from, CarbonImmutable $to): array
    {
        $periodQuery = $this->paymentQuery($storeId)
            ->where('is_reversed', false)
            ->whereBetween('paid_at', [$from, $to]);
        $now = CarbonImmutable::now(config('app.timezone'));

        return [
            'total_collected' => $this->money((clone $periodQuery)->sum('amount')),
            'count' => (int) (clone $periodQuery)->count(),
            'today' => $this->money(
                $this->paymentQuery($storeId)->where('is_reversed', false)
                    ->whereBetween('paid_at', [$now->startOfDay(), $now->endOfDay()])->sum('amount')
            ),
            'this_month' => $this->money(
                $this->paymentQuery($storeId)->where('is_reversed', false)
                    ->whereBetween('paid_at', [$now->startOfMonth(), $now->endOfMonth()])->sum('amount')
            ),
        ];
    }

    private function debtMetrics(int $storeId): array
    {
        $query = Debt::query()->where('store_id', $storeId);
        $statuses = (clone $query)->select('status')->selectRaw('COUNT(*) as count')->groupBy('status')->pluck('count', 'status');

        return [
            'total_debt' => $this->money((clone $query)->sum('amount')),
            'total_remaining' => $this->money((clone $query)->sum('remaining_amount')),
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

    private function salesChart(int $storeId, CarbonImmutable $from, CarbonImmutable $to, string $period): array
    {
        $rows = Invoice::query()->where('store_id', $storeId)->where('source', 'sale')
            ->whereBetween('created_at', [$from, $to])
            ->selectRaw('DATE(created_at) as bucket')
            ->selectRaw('COALESCE(SUM(total_amount), 0) as amount')
            ->selectRaw('COALESCE(SUM(CASE WHEN has_debt = 0 THEN total_amount ELSE 0 END), 0) as cash_amount')
            ->selectRaw('COALESCE(SUM(CASE WHEN has_debt = 1 THEN total_amount ELSE 0 END), 0) as credit_amount')
            ->groupByRaw('DATE(created_at)')->pluck('amount', 'bucket');
        $details = Invoice::query()->where('store_id', $storeId)->where('source', 'sale')
            ->whereBetween('created_at', [$from, $to])->selectRaw('DATE(created_at) as bucket')
            ->selectRaw('COALESCE(SUM(CASE WHEN has_debt = 0 THEN total_amount ELSE 0 END), 0) as cash_amount')
            ->selectRaw('COALESCE(SUM(CASE WHEN has_debt = 1 THEN total_amount ELSE 0 END), 0) as credit_amount')
            ->groupByRaw('DATE(created_at)')->get()->keyBy('bucket');

        return $this->buckets($from, $to, $period, function (string $date) use ($rows, $details, $period): array {
            $key = $period === 'this_year' ? substr($date, 0, 7) : $date;
            $amount = $period === 'this_year' ? $rows->filter(fn($value, $bucket) => str_starts_with($bucket, $key))->sum() : ($rows[$key] ?? 0);
            $cash = $period === 'this_year' ? $details->filter(fn($row, $bucket) => str_starts_with($bucket, $key))->sum('cash_amount') : ($details[$key]->cash_amount ?? 0);
            $credit = $period === 'this_year' ? $details->filter(fn($row, $bucket) => str_starts_with($bucket, $key))->sum('credit_amount') : ($details[$key]->credit_amount ?? 0);

            return $period === 'this_year'
                ? ['month' => $key, 'amount' => $this->money($amount), 'cash_amount' => $this->money($cash), 'credit_amount' => $this->money($credit)]
                : ['date' => $key, 'amount' => $this->money($amount), 'cash_amount' => $this->money($cash), 'credit_amount' => $this->money($credit)];
        });
    }

    private function paymentsChart(int $storeId, CarbonImmutable $from, CarbonImmutable $to, string $period): array
    {
        $rows = $this->paymentQuery($storeId)->where('is_reversed', false)->whereBetween('paid_at', [$from, $to])
            ->selectRaw('DATE(paid_at) as bucket')->selectRaw('COALESCE(SUM(amount), 0) as amount')
            ->groupByRaw('DATE(paid_at)')->pluck('amount', 'bucket');

        return $this->buckets($from, $to, $period, function (string $date) use ($rows, $period): array {
            $key = $period === 'this_year' ? substr($date, 0, 7) : $date;
            $amount = $period === 'this_year' ? $rows->filter(fn($value, $bucket) => str_starts_with($bucket, $key))->sum() : ($rows[$key] ?? 0);

            return $period === 'this_year'
                ? ['month' => $key, 'amount' => $this->money($amount)]
                : ['date' => $key, 'amount' => $this->money($amount)];
        });
    }

    private function buckets(CarbonImmutable $from, CarbonImmutable $to, string $period, callable $format): array
    {
        $dates = [];
        $date = $period === 'this_year' ? $from->startOfMonth() : $from->startOfDay();
        $lastDate = $period === 'this_year' ? $to->startOfMonth() : $to->startOfDay();

        while ($date <= $lastDate) {
            $dates[] = $format($date->format('Y-m-d'));
            $date = $period === 'this_year' ? $date->addMonth() : $date->addDay();
        }

        return $dates;
    }

    private function recentInvoices(int $storeId, CarbonImmutable $from, CarbonImmutable $to): array
    {
        return Invoice::query()->where('store_id', $storeId)->whereBetween('created_at', [$from, $to])
            ->with(['customer:id,name', 'debt:id,invoice_id,status'])->latest('created_at')->limit(10)->get()
            ->map(fn(Invoice $invoice) => [
                'id' => $invoice->id,
                'customer' => $invoice->customer ? ['id' => $invoice->customer->id, 'name' => $invoice->customer->name] : null,
                'total_amount' => $this->money($invoice->total_amount),
                'type' => $invoice->has_debt ? 'credit' : 'cash',
                'source' => $invoice->source?->value ?? $invoice->source,
                'status' => $invoice->has_debt ? ($invoice->debt?->status ?? 'unpaid') : 'cash',
                'created_at' => $invoice->created_at?->toISOString(),
            ])->all();
    }

    private function recentPayments(int $storeId, CarbonImmutable $from, CarbonImmutable $to): array
    {
        return $this->paymentQuery($storeId)->whereBetween('paid_at', [$from, $to])
            ->with('debt.invoice.customer:id,name')->latest('paid_at')->limit(10)->get()
            ->map(fn(Payment $payment) => [
                'id' => $payment->id,
                'customer' => $payment->debt?->invoice?->customer ? [
                    'id' => $payment->debt->invoice->customer->id,
                    'name' => $payment->debt->invoice->customer->name,
                ] : null,
                'amount' => $this->money($payment->amount),
                'method' => $payment->method,
                'paid_at' => $payment->paid_at
                    ? CarbonImmutable::parse($payment->paid_at)->toISOString()
                    : null,
                'is_reversed' => (bool) $payment->is_reversed,
                'status' => $payment->is_reversed ? 'reversed' : 'active',
            ])->all();
    }

    private function money(mixed $value): float
    {
        return round((float) ($value ?? 0), 2);
    }
}
