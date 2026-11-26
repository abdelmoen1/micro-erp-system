<?php

namespace App\Http\Controllers\Api;

use App\Exceptions\ApiException;
use App\Http\Controllers\Controller;
use App\Http\Requests\StoreProductRequest;
use App\Http\Requests\UpdateProductRequest;
use App\Http\Requests\VoidReasonRequest;
use App\Http\Resources\CatalogProductResource;
use App\Http\Resources\ProductResource;
use App\Http\Resources\StockMovementResource;
use App\Models\CatalogProduct;
use App\Models\Product;
use App\Models\StockMovement;
use App\Services\ProductImportService;
use App\Services\AuditService;
use App\Services\ProductService;
use App\Services\StockService;
use App\Support\Barcode;
use App\Support\Money;
use App\Support\Quantity;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

/**
 * US-0401 product catalog. A product with history is archived (deactivated, BR-04, FR-16); only a
 * product added by mistake, with no history at all, may be deleted for good.
 * Other stores' products resolve to 404 through BelongsToStore route binding.
 */
class ProductController extends Controller
{
    public function __construct(private ProductService $products)
    {
    }

    /**
     * Active products by default (the POS list); `status=inactive|all` for management screens.
     * W-08 / M-11: `stock=low` (at or under the minimum) or `stock=negative` (D-27 review).
     */
    public function index(Request $request)
    {
        $filters = $request->validate([
            'search' => ['nullable', 'string', 'max:255'],
            'status' => ['nullable', Rule::in(['active', 'inactive', 'all'])],
            'stock' => ['nullable', Rule::in(['low', 'negative'])],
            'per_page' => ['nullable', 'integer', 'min:1', 'max:50'],
        ]);
        $status = $filters['status'] ?? Product::STATUS_ACTIVE;

        $products = Product::query()
            ->forStore($request->user()->store_id)
            ->when($status !== 'all', fn($query) => $query->where('status', $status))
            ->when($filters['search'] ?? null, function ($query, string $search) {
                $query->where(fn($q) => $q->where('name', 'like', '%' . $search . '%')
                    ->orWhere('barcode', Barcode::normalize($search) ?? $search));
            })
            ->when(($filters['stock'] ?? null) === 'low', fn($query) => $query->whereColumn('current_stock', '<=', 'minimum_stock'))
            ->when(($filters['stock'] ?? null) === 'negative', fn($query) => $query->where('current_stock', '<', 0))
            ->orderBy('name')
            ->paginate($filters['per_page'] ?? 20);

        return ProductResource::collection($products);
    }

    /**
     * D-27 negative-stock review: products below zero with the sales that took them there
     * (their latest `sale` movements), so the manager can count the shelf and adjust.
     */
    public function negativeStock(Request $request)
    {
        $products = Product::query()
            ->forStore($request->user()->store_id)
            ->active()
            ->where('current_stock', '<', 0)
            ->orderBy('current_stock')
            ->limit(100)
            ->get();

        $sales = StockMovement::query()
            ->where('store_id', $request->user()->store_id)
            ->whereIn('product_id', $products->pluck('id'))
            ->where('type', StockMovement::TYPE_SALE)
            ->with('creator')
            ->orderByDesc('id')
            ->get()
            ->groupBy('product_id');

        return response()->json([
            'data' => $products->map(fn(Product $product) => [
                'product' => new ProductResource($product),
                'sales' => ($sales->get($product->id) ?? collect())->take(5)->map(fn(StockMovement $m) => [
                    'invoice_id' => $m->reference_id,
                    'quantity' => Quantity::format(Quantity::negate($m->quantity), $product->unit),
                    'balance_after' => Quantity::format($m->balance_after, $product->unit),
                    'created_at' => $m->created_at,
                    'created_by' => $m->creator?->name,
                ])->values(),
            ])->values(),
        ]);
    }

    /** US-0408: `dry_run=1` checks the file; without it a clean file is imported atomically. */
    public function import(Request $request, ProductImportService $import)
    {
        $this->authorize('create', Product::class);
        $data = $request->validate([
            'file' => ['required', 'file', 'mimes:csv,txt', 'max:2048'],
            'dry_run' => ['nullable', 'boolean'],
        ], [
            'file.required' => 'اختر ملف CSV.',
            'file.mimes' => 'الملف يجب أن يكون CSV.',
            'file.max' => 'حجم الملف أكبر من 2 ميغابايت.',
        ]);

        $dryRun = (bool) ($data['dry_run'] ?? false);
        $result = $import->import($request->user(), $request->file('file'), $dryRun);

        return response()->json([
            'message' => $dryRun ? 'الملف سليم وجاهز للاستيراد.' : "تم استيراد {$result['imported']} منتجًا.",
            'data' => $result,
        ], $dryRun ? 200 : 201);
    }

    public function store(StoreProductRequest $request)
    {
        $product = $this->products->create($request->user(), $request->validated());

        return response()->json([
            'message' => 'تم إنشاء المنتج بنجاح',
            'product' => new ProductResource($product),
        ], 201);
    }

    public function show(Request $request, Product $product)
    {
        // The detail screen offers «حذف نهائي» only for a product nothing refers to.
        if ($request->user()->can('delete', $product)) {
            $product->setAttribute('deletable', $this->products->isDeletable($product));
        }

        return new ProductResource($product);
    }

    /**
     * DELETE /products/{id}: permanent removal of a product added by mistake (Owner / Manager).
     * A product with any history answers 409 PRODUCT_IN_USE; archive it (deactivate) instead.
     */
    public function destroy(Request $request, Product $product)
    {
        $this->authorize('delete', $product);
        $reason = $request->validate(['reason' => ['nullable', 'string', 'max:500']])['reason'] ?? null;

        $this->products->delete($request->user(), $product, $reason);

        return response()->json(['message' => 'تم حذف المنتج نهائيًا.']);
    }

    public function update(UpdateProductRequest $request, Product $product)
    {
        return new ProductResource($this->products->update($request->user(), $product, $request->validated()));
    }

    public function deactivate(Product $product)
    {
        $this->authorize('update', $product);

        $product->update(['status' => Product::STATUS_INACTIVE]);

        return response()->json([
            'message' => 'تم إيقاف المنتج',
            'product' => new ProductResource($product),
        ]);
    }

    /**
     * «قيمة البضاعة في المخزن» (2026-11-07), Owner / Manager: what the goods on the shelf cost, and
     * what they bring at today's selling prices. Only stock above zero counts; a product without a
     * cost price is left out of the cost figure and counted in `missing_cost_count`.
     */
    public function stockValue(Request $request)
    {
        $this->authorize('adjustStock', Product::class);

        $products = Product::query()
            ->forStore($request->user()->store_id)
            ->where('current_stock', '>', 0)
            ->get(['id', 'current_stock', 'cost_price', 'selling_price']);

        $costed = $products->whereNotNull('cost_price');

        return response()->json(['data' => [
            'cost_value' => Money::sum($costed->map(fn(Product $p) => Money::times($p->cost_price, $p->current_stock))),
            'selling_value' => Money::sum($products->map(fn(Product $p) => Money::times($p->selling_price, $p->current_stock))),
            'products_count' => $products->count(),
            'missing_cost_count' => $products->count() - $costed->count(),
        ]]);
    }

    /** US-0403 (FR-22, BR-11): active products at or below their threshold, lowest stock first. */
    public function lowStock(Request $request)
    {
        $products = Product::query()
            ->forStore($request->user()->store_id)
            ->active()
            ->whereColumn('current_stock', '<=', 'minimum_stock')
            ->orderBy('current_stock')
            ->orderBy('name')
            ->paginate(20);

        return ProductResource::collection($products);
    }

    /** US-0402: the stock ledger of one product, newest first (readable by every role). */
    public function movements(Product $product)
    {
        $movements = $product->movements()->orderByDesc('id')->paginate(20);
        $reversed = StockMovement::query()
            ->where('product_id', $product->id)
            ->where('type', StockMovement::TYPE_ADJUSTMENT_REVERSAL)
            ->whereIn('reference_id', $movements->getCollection()->pluck('id'))
            ->pluck('reference_id')
            ->all();
        $movements->getCollection()->each(function (StockMovement $movement) use ($product, $reversed) {
            $movement->setRelation('product', $product);
            $movement->setAttribute('reversed', in_array($movement->id, $reversed, false));
        });

        return StockMovementResource::collection($movements);
    }

    /**
     * POST /stock-movements/{movement}/reverse: takes back an adjustment entered by mistake with an
     * opposite `adjustment_reversal` movement (the ledger is append-only). Owner / Manager, a reason,
     * once per adjustment, and never below zero stock.
     */
    public function reverseMovement(VoidReasonRequest $request, StockMovement $movement, StockService $stock, AuditService $audit)
    {
        $reason = $request->validated('reason');

        $reversal = DB::transaction(function () use ($request, $movement, $stock, $audit, $reason) {
            $actor = $request->user();
            // The product lock serialises two reversals of the same adjustment (double click, retry).
            $product = Product::query()->forStore($actor->store_id)->whereKey($movement->product_id)->lockForUpdate()->firstOrFail();

            if (!in_array($movement->type, [StockMovement::TYPE_ADJUSTMENT_IN, StockMovement::TYPE_ADJUSTMENT_OUT], true)) {
                throw ApiException::conflict('MOVEMENT_NOT_REVERSIBLE', 'هذه الحركة ناتجة عن مستند (بيع أو شراء أو مرتجع)؛ صحّحها من المستند نفسه.');
            }

            $done = StockMovement::query()
                ->where('product_id', $product->id)
                ->where('type', StockMovement::TYPE_ADJUSTMENT_REVERSAL)
                ->where('reference_type', 'stock_movement')
                ->where('reference_id', $movement->id)
                ->exists();
            if ($done) {
                throw ApiException::conflict('MOVEMENT_ALREADY_REVERSED', 'تم التراجع عن هذا التعديل مسبقًا.');
            }

            $quantity = Quantity::negate($movement->quantity);
            try {
                $reversal = $stock->move($product, StockMovement::TYPE_ADJUSTMENT_REVERSAL, $quantity, $actor, $reason, 'stock_movement', $movement->id);
            } catch (ApiException $e) {
                $available = Quantity::format($product->current_stock, $product->unit);
                throw new ApiException(409, 'MOVEMENT_STOCK_CONSUMED',
                    "لا يمكن التراجع عن هذا التعديل: المخزون الحالي ({$available}) لا يكفي لإخراج الكمية التي أُضيفت.",
                    details: ['cause' => $e->errorCode],
                );
            }

            $audit->record('stock.adjustment_reversed', $product, [
                'movement_id' => $movement->id,
                'reversal_id' => $reversal->id,
                'quantity' => Quantity::format($quantity, $product->unit),
                'balance_after' => Quantity::format($reversal->balance_after, $product->unit),
                'reason' => $reason,
            ], $actor);

            return $reversal;
        });

        return response()->json([
            'message' => 'تم التراجع عن تعديل المخزون.',
            'movement' => new StockMovementResource($reversal),
            'product' => new ProductResource($reversal->product),
        ], 201);
    }

    /** US-0401 AC3 (FR-17): the active product with this barcode in my store, or 404. */
    public function lookup(Request $request)
    {
        $data = $request->validate(['barcode' => ['required', 'string', 'max:64']]);

        $product = Product::query()
            ->forStore($request->user()->store_id)
            ->active()
            ->where('barcode', Barcode::normalize($data['barcode']))
            ->firstOrFail();

        return new ProductResource($product);
    }

    /**
     * Shared catalog, before adding a product: my store's product with this barcode (any status,
     * so the form can say «already in your store»), and the platform-wide catalog item that any
     * store saved first (its name and unit prefill the form). Either may be null.
     */
    public function catalogLookup(Request $request)
    {
        $data = $request->validate(['barcode' => ['required', 'string', 'max:64']]);
        $barcode = Barcode::normalize($data['barcode']);

        $product = Product::query()->forStore($request->user()->store_id)->where('barcode', $barcode)->first();
        $catalog = $product?->catalogProduct ?? CatalogProduct::query()->where('barcode', $barcode)->first();

        return response()->json(['data' => [
            'barcode' => $barcode,
            'product' => $product ? new ProductResource($product) : null,
            'catalog_product' => $catalog ? new CatalogProductResource($catalog) : null,
        ]]);
    }
}
