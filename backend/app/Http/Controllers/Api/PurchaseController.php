<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\ReturnPurchaseRequest;
use App\Http\Resources\PurchaseInvoiceResource;
use App\Http\Resources\PurchaseReturnResource;
use App\Http\Resources\SaleReturnResource;
use App\Models\Product;
use App\Models\PurchaseInvoice;
use App\Models\PurchaseReturn;
use App\Models\SaleReturn;
use App\Services\PurchaseReturnService;
use App\Support\BusinessClock;
use Carbon\CarbonImmutable;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Gate;

/**
 * The purchases register and both return registers. Purchases hold costs, so they stay Owner /
 * Manager like the suppliers; sale returns are open to whoever sees the sales.
 */
class PurchaseController extends Controller
{
    public function __construct(private readonly PurchaseReturnService $returns) {}

    /** GET /purchases: date range in the store timezone, and one supplier when asked. */
    public function index(Request $request)
    {
        Gate::authorize('adjustStock', Product::class);
        $filters = $this->filters($request, ['supplier_id' => ['nullable', 'integer']]);

        $purchases = PurchaseInvoice::query()
            ->forStore($request->user()->store_id)
            ->with(['supplier', 'creator'])
            ->withCount('items')
            ->withSum('returns as returned_amount', 'total_amount')
            ->when($filters['supplier_id'] ?? null, fn($q, $id) => $q->where('supplier_id', $id));

        return PurchaseInvoiceResource::collection($this->page($purchases, $request, $filters));
    }

    /** GET /purchases/{id}: the invoice with its lines and what went back. */
    public function show(PurchaseInvoice $purchaseInvoice)
    {
        Gate::authorize('adjustStock', Product::class);

        return new PurchaseInvoiceResource($purchaseInvoice->load([
            'supplier',
            'creator',
            'items.product',
            'returns.items.purchaseItem.product',
            'returns.creator',
        ]));
    }

    /** POST /purchases/{id}/returns: the server computes the split; the client only previews. */
    public function storeReturn(ReturnPurchaseRequest $request, PurchaseInvoice $purchaseInvoice)
    {
        $validated = $request->validated();
        $return = $this->returns->create($request->user(), $purchaseInvoice, $validated['items'], $validated['reason']);

        return response()->json([
            'message' => 'تم تسجيل المرتجع على حساب المورد.',
            'data' => new PurchaseReturnResource($return),
            'balance' => $purchaseInvoice->supplier->balance(),
        ], 201);
    }

    /** GET /returns/purchases */
    public function purchaseReturns(Request $request)
    {
        Gate::authorize('adjustStock', Product::class);
        $filters = $this->filters($request, ['supplier_id' => ['nullable', 'integer']]);

        $returns = PurchaseReturn::query()
            ->forStore($request->user()->store_id)
            ->with(['supplier', 'creator', 'items.purchaseItem.product'])
            ->when($filters['supplier_id'] ?? null, fn($q, $id) => $q->where('supplier_id', $id));

        return PurchaseReturnResource::collection($this->page($returns, $request, $filters));
    }

    /** GET /returns/sales */
    public function saleReturns(Request $request)
    {
        $filters = $this->filters($request);

        $returns = SaleReturn::query()
            ->forStore($request->user()->store_id)
            ->with(['customer', 'creator', 'items.invoiceItem']);

        return SaleReturnResource::collection($this->page($returns, $request, $filters));
    }

    private function filters(Request $request, array $extra = []): array
    {
        return $request->validate([
            'from' => ['nullable', 'date_format:Y-m-d'],
            'to' => ['nullable', 'date_format:Y-m-d'],
            'per_page' => ['nullable', 'integer', 'min:1', 'max:50'],
        ] + $extra);
    }

    private function page(Builder $query, Request $request, array $filters)
    {
        $timezone = BusinessClock::forStore($request->user()->store)->timezone();

        return $query
            ->when($filters['from'] ?? null, fn($q, $day) => $q->where('created_at', '>=', CarbonImmutable::parse($day, $timezone)->startOfDay()->utc()))
            ->when($filters['to'] ?? null, fn($q, $day) => $q->where('created_at', '<=', CarbonImmutable::parse($day, $timezone)->endOfDay()->utc()))
            ->latest()
            ->orderByDesc('id')
            ->paginate($filters['per_page'] ?? 20);
    }
}
