<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\StoreProductRequest;
use App\Http\Requests\UpdateProductRequest;
use App\Http\Resources\ProductResource;
use App\Http\Resources\StockMovementResource;
use App\Models\Product;
use App\Models\StockMovement;
use App\Services\ProductImportService;
use App\Services\ProductService;
use App\Support\Quantity;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

/**
 * US-0401 product catalog. There is no DELETE: products are deactivated (BR-04, FR-16).
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
                    ->orWhere('barcode', $search));
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

    public function show(Product $product)
    {
        return new ProductResource($product);
    }

    public function update(UpdateProductRequest $request, Product $product)
    {
        $product->update($request->validated());

        return new ProductResource($product);
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
        $movements->getCollection()->each->setRelation('product', $product);

        return StockMovementResource::collection($movements);
    }

    /** US-0401 AC3 (FR-17): the active product with this barcode in my store, or 404. */
    public function lookup(Request $request)
    {
        $data = $request->validate(['barcode' => ['required', 'string', 'max:64']]);

        $product = Product::query()
            ->forStore($request->user()->store_id)
            ->active()
            ->where('barcode', trim($data['barcode']))
            ->firstOrFail();

        return new ProductResource($product);
    }
}
