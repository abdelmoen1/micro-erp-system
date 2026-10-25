<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Http\Requests\DeleteStoreRequest;
use App\Http\Requests\UpdateStoreStatusRequest;
use App\Http\Requests\UpdateStoreSubscriptionRequest;
use App\Http\Resources\AdminProductResource;
use App\Http\Resources\AdminStoreResource;
use App\Models\AuditLog;
use App\Models\Product;
use App\Models\Store;
use App\Services\StoreAccessService;
use App\Services\StoreDeletionService;
use App\Support\Barcode;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Validation\Rule;

/**
 * Platform admin: every store on the platform (routes behind `platform.admin`). Account access and
 * subscription have their own endpoints so one can never overwrite the other.
 */
class StoreController extends Controller
{
    public function __construct(private readonly StoreAccessService $access) {}

    /** Search by store name, phone, address or the owner's name / email. */
    public function index(Request $request)
    {
        $filters = $request->validate([
            'search' => ['nullable', 'string', 'max:255'],
            'status' => ['nullable', Rule::in([Store::STATUS_ACTIVE, Store::STATUS_SUSPENDED])],
            'subscription' => ['nullable', Rule::in([Store::SUBSCRIPTION_ACTIVE, Store::SUBSCRIPTION_TRIAL, Store::SUBSCRIPTION_EXPIRED, Store::SUBSCRIPTION_INACTIVE])],
            'sort' => ['nullable', Rule::in(['newest', 'oldest', 'name'])],
            'per_page' => ['nullable', 'integer', 'min:1', 'max:50'],
        ]);

        $stores = Store::query()
            ->with('owner')
            ->withCount(['users', 'products'])
            ->when($filters['search'] ?? null, function ($query, string $search) {
                $like = '%' . $search . '%';
                $query->where(fn($q) => $q->where('name', 'like', $like)
                    ->orWhere('phone', 'like', $like)
                    ->orWhere('address', 'like', $like)
                    ->orWhereHas('users', fn($u) => $u->where('name', 'like', $like)->orWhere('email', 'like', $like)));
            })
            ->when($filters['status'] ?? null, fn($query, string $status) => $query->where('status', $status))
            ->when($filters['subscription'] ?? null, fn($query, string $state) => $query->subscriptionState($state))
            ->when(
                $filters['sort'] ?? 'newest',
                fn($query, string $sort) => match ($sort) {
                    'oldest' => $query->orderBy('created_at')->orderBy('id'),
                    'name' => $query->orderBy('name')->orderBy('id'),
                    default => $query->orderByDesc('created_at')->orderByDesc('id'),
                },
            )
            ->paginate($filters['per_page'] ?? 20);

        return AdminStoreResource::collection($stores);
    }

    /** The store, its members and the history of access / subscription changes. */
    public function show(Store $store)
    {
        $store->load(['owner', 'statusChangedBy', 'subscriptionChangedBy'])->loadCount(['users', 'products']);

        $members = $store->users()
            ->orderBy('id')
            ->get(['id', 'name', 'email', 'phone', 'role', 'status', 'created_at'])
            ->map(fn($user) => [
                'id' => $user->id,
                'name' => $user->name,
                'email' => $user->email,
                'phone' => $user->phone,
                'role' => $user->role->value,
                'status' => $user->status ?? 'active',
                'created_at' => $user->created_at,
            ]);

        return response()->json([
            'data' => (new AdminStoreResource($store))->resolve() + [
                'members' => $members,
                'active_products_count' => $store->products()->where('status', Product::STATUS_ACTIVE)->count(),
                'history' => $this->history($store),
            ],
        ]);
    }

    /** This store's own product rows only (never another store's prices or stock). */
    public function products(Request $request, Store $store)
    {
        $filters = $request->validate([
            'search' => ['nullable', 'string', 'max:255'],
            'status' => ['nullable', Rule::in(['active', 'inactive', 'all'])],
            'per_page' => ['nullable', 'integer', 'min:1', 'max:50'],
        ]);
        $status = $filters['status'] ?? 'all';

        $products = Product::query()
            ->forStore($store->id)
            ->with('catalogProduct')
            ->when($status !== 'all', fn($query) => $query->where('status', $status))
            ->when($filters['search'] ?? null, function ($query, string $search) {
                $query->where(fn($q) => $q->where('name', 'like', '%' . $search . '%')
                    ->orWhere('barcode', Barcode::normalize($search) ?? $search));
            })
            ->orderBy('name')
            ->orderBy('id')
            ->paginate($filters['per_page'] ?? 20);

        return AdminProductResource::collection($products);
    }

    public function updateStatus(UpdateStoreStatusRequest $request, Store $store)
    {
        $data = $request->validated();
        $store = $this->access->setStatus($store, $data['status'], $data['reason'] ?? null, $request->user());

        return response()->json([
            'message' => $store->isSuspended() ? 'تم إيقاف حساب المتجر' : 'تم تفعيل حساب المتجر',
            'data' => new AdminStoreResource($store->load(['owner', 'statusChangedBy', 'subscriptionChangedBy'])),
        ]);
    }

    public function updateSubscription(UpdateStoreSubscriptionRequest $request, Store $store)
    {
        $data = $request->validated();
        $store = $this->access->setSubscription(
            $store,
            $data['status'],
            $this->expiry($data['expires_at'] ?? null, $store),
            $data['note'] ?? null,
            $request->user(),
        );

        return response()->json([
            'message' => $data['status'] === Store::SUBSCRIPTION_ACTIVE ? 'تم تفعيل الاشتراك' : 'تم إيقاف الاشتراك',
            'data' => new AdminStoreResource($store->load(['owner', 'statusChangedBy', 'subscriptionChangedBy'])),
        ]);
    }

    /** Permanent: the store and everything in it. The admin types the store name to confirm. */
    public function destroy(DeleteStoreRequest $request, Store $store, StoreDeletionService $deletion)
    {
        $removed = $deletion->delete($store, $request->user());

        return response()->json([
            'message' => 'تم حذف المتجر وكل بياناته نهائياً',
            'data' => ['id' => $store->id, 'removed' => $removed],
        ]);
    }

    /** A bare date (Y-m-d) runs to the end of that day in the store's own timezone. */
    private function expiry(?string $value, Store $store): ?Carbon
    {
        if ($value === null) {
            return null;
        }

        return preg_match('/^\d{4}-\d{2}-\d{2}$/', $value)
            ? Carbon::parse($value, $store->businessTimezone())->endOfDay()->utc()
            : Carbon::parse($value)->utc();
    }

    private function history(Store $store): array
    {
        return AuditLog::query()
            ->where('store_id', $store->id)
            ->where('entity_type', 'Store')
            ->where('entity_id', (string) $store->id)
            ->with('user:id,name')
            ->orderByDesc('id')
            ->limit(30)
            ->get()
            ->map(fn(AuditLog $log) => [
                'id' => $log->id,
                'action' => $log->action,
                'at' => $log->created_at,
                'by' => $log->user?->only(['id', 'name']),
                'metadata' => $log->metadata ?? (object) [],
            ])
            ->all();
    }
}
