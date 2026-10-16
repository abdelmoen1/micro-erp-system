<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\StoreProductRequest;
use App\Http\Requests\UpdateProductRequest;
use App\Http\Resources\ProductResource;
use App\Models\Product;
use App\Services\ProductService;
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

    /** Active products by default (the POS list); `status=inactive|all` for management screens. */
    public function index(Request $request)
    {
        $filters = $request->validate([
            'search' => ['nullable', 'string', 'max:255'],
            'status' => ['nullable', Rule::in(['active', 'inactive', 'all'])],
        ]);
        $status = $filters['status'] ?? Product::STATUS_ACTIVE;

        $products = Product::query()
            ->forStore($request->user()->store_id)
            ->when($status !== 'all', fn($query) => $query->where('status', $status))
            ->when($filters['search'] ?? null, function ($query, string $search) {
                $query->where(fn($q) => $q->where('name', 'like', '%' . $search . '%')
                    ->orWhere('barcode', $search));
            })
            ->orderBy('name')
            ->paginate(20);

        return ProductResource::collection($products);
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
