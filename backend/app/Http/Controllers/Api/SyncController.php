<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\ResolveSyncConflictRequest;
use App\Http\Requests\SyncBatchRequest;
use App\Http\Resources\CustomerResource;
use App\Http\Resources\ProductResource;
use App\Http\Resources\SyncConflictResource;
use App\Models\Customer;
use App\Models\Product;
use App\Models\SyncConflict;
use App\Services\SyncService;
use App\Support\BusinessClock;
use Carbon\CarbonImmutable;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

/**
 * R2 offline sync (US-1101, US-1102, US-1106; doc 16 §3, §6): the phone's catalog and customer
 * cache (down), its queued sales and payments (up), and the manager's review list.
 */
class SyncController extends Controller
{
    public const PAGE = 1000;

    public function __construct(private readonly SyncService $sync) {}

    /**
     * GET /sync/bootstrap?entity=products|customers&since=&after_id=: one page of rows by id. With
     * `since`, only rows changed from then on; a customer changes when one of their debts does,
     * because that is what moves the balance. The device keeps the first page's `server_time` as
     * its next `since`, so its own clock never matters.
     */
    public function bootstrap(Request $request)
    {
        $filters = $request->validate([
            'entity' => ['required', Rule::in(['products', 'customers'])],
            'since' => ['nullable', 'date'],
            'after_id' => ['nullable', 'integer', 'min:0'],
            'limit' => ['nullable', 'integer', 'min:1', 'max:' . self::PAGE],
        ]);

        $user = $request->user();
        $serverTime = now();
        $since = isset($filters['since']) ? CarbonImmutable::parse($filters['since'])->utc() : null;
        $limit = (int) ($filters['limit'] ?? self::PAGE);
        $afterId = (int) ($filters['after_id'] ?? 0);

        if ($filters['entity'] === 'products') {
            $rows = Product::query()
                ->forStore($user->store_id)
                ->when($since, fn($q) => $q->where('updated_at', '>=', $since))
                ->where('id', '>', $afterId)
                ->orderBy('id')
                ->limit($limit + 1)
                ->get();
            $data = $rows->take($limit)->map(fn(Product $p) => (new ProductResource($p))->resolve($request))->values();
        } else {
            $today = BusinessClock::forStore($user->store)->now()->toDateString();
            $rows = Customer::withTrashed()
                ->where('customers.store_id', $user->store_id)
                ->when($since, fn($q) => $q->where(fn($w) => $w
                    ->where('updated_at', '>=', $since)
                    ->orWhere('deleted_at', '>=', $since)
                    ->orWhereHas('ledgerDebts', fn($d) => $d->where('updated_at', '>=', $since))))
                ->where('id', '>', $afterId)
                ->withSum('ledgerDebts as balance', 'remaining_amount')
                ->withSum(['ledgerDebts as overdue' => fn($q) => $q
                    ->where('status', '<>', 'cancelled')
                    ->where('remaining_amount', '>', 0)
                    ->whereDate('due_date', '<', $today)], 'remaining_amount')
                ->orderBy('id')
                ->limit($limit + 1)
                ->get();
            $data = $rows->take($limit)
                ->map(fn(Customer $c) => (new CustomerResource($c))->resolve($request) + ['deleted' => $c->trashed()])
                ->values();
        }

        return response()->json([
            'data' => $data,
            'next_after_id' => $rows->count() > $limit ? $data->last()['id'] : null,
            'server_time' => $serverTime->toIso8601String(),
        ]);
    }

    /** POST /sync/batch: up to 50 queued items, in `seq` order, one result each (05 §4.2). */
    public function batch(SyncBatchRequest $request)
    {
        $outcome = $this->sync->batch($request->user(), $request->validated('device_id'), $request->orderedItems());

        return response()->json($outcome);
    }

    /** GET /sync/conflicts (SCR-W-18): open items first, newest first; `open_count` for the badge. */
    public function conflicts(Request $request)
    {
        $this->authorize('viewAny', SyncConflict::class);

        $filters = $request->validate([
            'status' => ['nullable', Rule::in([SyncConflict::STATUS_OPEN, SyncConflict::STATUS_RESOLVED, 'all'])],
            'kind' => ['nullable', Rule::in([SyncConflict::KIND_FLAGGED, SyncConflict::KIND_CONFLICT, SyncConflict::KIND_REJECTED])],
            'per_page' => ['nullable', 'integer', 'min:1', 'max:50'],
        ]);

        $storeId = $request->user()->store_id;
        $status = $filters['status'] ?? SyncConflict::STATUS_OPEN;

        $page = SyncConflict::query()
            ->forStore($storeId)
            ->with(['user', 'customer', 'resolver'])
            ->when($status !== 'all', fn($q) => $q->where('status', $status))
            ->when($filters['kind'] ?? null, fn($q, $kind) => $q->where('kind', $kind))
            ->orderByRaw("CASE WHEN status = 'open' THEN 0 ELSE 1 END")
            ->latest()
            ->orderByDesc('id')
            ->paginate($filters['per_page'] ?? 20);

        return SyncConflictResource::collection($page)->additional([
            'open_count' => SyncConflict::query()->forStore($storeId)->where('status', SyncConflict::STATUS_OPEN)->count(),
        ]);
    }

    /** POST /sync/conflicts/{conflict}/resolve (US-1106). */
    public function resolve(ResolveSyncConflictRequest $request, SyncConflict $conflict)
    {
        $resolved = $this->sync->resolve(
            $request->user(),
            $conflict,
            $request->validated('resolution'),
            $request->validated('note'),
        );

        return response()->json([
            'message' => 'تمت معالجة البند.',
            'data' => new SyncConflictResource($resolved),
        ]);
    }
}
