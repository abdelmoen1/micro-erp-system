<?php

namespace App\Services;

use App\Models\Customer;
use App\Models\Debt;
use App\Models\Store;
use App\Support\BusinessClock;
use App\Support\Money;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Collection;

/**
 * US-0702 (FR-37, FR-41, FR-42, UC-15): the follow-up lists. "Today" is the store's local date;
 * a paid or cancelled debt is never due or overdue because only `remaining > 0` qualifies.
 */
class DebtService
{
    public const BUCKETS = ['due_today', 'this_week', 'overdue', 'open', 'all'];

    public function query(Store $store, string $bucket = 'all', ?int $customerId = null): Builder
    {
        $clock = BusinessClock::forStore($store);
        $today = $clock->now()->toDateString();
        [$weekStart, $weekEnd] = $clock->periodBounds('this_week');

        $open = fn(Builder $q) => $q
            ->where('status', '<>', Debt::STATUS_CANCELLED)
            ->where('remaining_amount', '>', 0);

        return Debt::query()
            ->where('store_id', $store->id)
            ->when($customerId, fn(Builder $q) => $q->where('customer_id', $customerId))
            ->when($bucket === 'open', $open)
            ->when($bucket === 'due_today', fn(Builder $q) => $open($q)->whereDate('due_date', $today))
            ->when($bucket === 'this_week', fn(Builder $q) => $open($q)
                ->whereDate('due_date', '>=', max($today, $weekStart->toDateString()))
                ->whereDate('due_date', '<=', $weekEnd->toDateString()))
            ->when($bucket === 'overdue', fn(Builder $q) => $open($q)->whereDate('due_date', '<', $today));
    }

    /** @return array<string, int> how many open debts fall in each bucket (tab counters) */
    public function counts(Store $store): array
    {
        $counts = [];
        foreach (self::BUCKETS as $bucket) {
            $counts[$bucket] = $this->query($store, $bucket)->count();
        }

        return $counts;
    }

    /**
     * AC3: customers ordered by total remaining, highest first, with how many debts are open and
     * the oldest due date among them.
     *
     * @return Collection<int, array<string, mixed>>
     */
    public function balances(Store $store, int $limit = 50): Collection
    {
        $rows = $this->query($store, 'open')
            ->selectRaw('customer_id, COUNT(*) AS open_count, MIN(due_date) AS oldest_due, SUM(remaining_amount) AS total_remaining')
            ->groupBy('customer_id')
            ->orderByDesc('total_remaining')
            ->orderBy('customer_id')
            ->limit($limit)
            ->get();

        $customers = Customer::query()->whereIn('id', $rows->pluck('customer_id'))->get()->keyBy('id');

        return $rows->map(fn($row) => [
            'customer' => [
                'id' => (int) $row->customer_id,
                'name' => $customers->get($row->customer_id)?->name,
                'phone' => $customers->get($row->customer_id)?->phone,
            ],
            'open_count' => (int) $row->open_count,
            'oldest_due' => $row->oldest_due ? substr((string) $row->oldest_due, 0, 10) : null,
            'total_remaining' => Money::of($row->total_remaining),
        ])->values();
    }
}
