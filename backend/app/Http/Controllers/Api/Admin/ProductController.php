<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Http\Resources\AdminProductResource;
use App\Http\Resources\CatalogProductResource;
use App\Models\CatalogProduct;
use App\Models\Product;
use App\Support\Barcode;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

/**
 * Platform admin: product rows across stores. Each row is one store's own product (price, cost,
 * stock); nothing is summed or merged across stores. Products with a global barcode share a
 * catalog item, which links the rows without combining them.
 */
class ProductController extends Controller
{
    /** `search` matches the product name or barcode; `store` matches the store name or address. */
    public function index(Request $request)
    {
        $filters = $request->validate([
            'search' => ['nullable', 'string', 'max:255'],
            'store' => ['nullable', 'string', 'max:255'],
            'store_id' => ['nullable', 'integer'],
            'catalog_product_id' => ['nullable', 'integer'],
            'status' => ['nullable', Rule::in(['active', 'inactive', 'all'])],
            'per_page' => ['nullable', 'integer', 'min:1', 'max:50'],
        ]);
        $status = $filters['status'] ?? 'all';

        $products = Product::query()
            ->with(['store', 'catalogProduct'])
            ->when($filters['store_id'] ?? null, fn($query, int $id) => $query->where('store_id', $id))
            ->when($filters['catalog_product_id'] ?? null, fn($query, int $id) => $query->where('catalog_product_id', $id))
            ->when($status !== 'all', fn($query) => $query->where('status', $status))
            ->when($filters['search'] ?? null, function ($query, string $search) {
                $query->where(fn($q) => $q->where('name', 'like', '%' . $search . '%')
                    ->orWhere('barcode', Barcode::normalize($search) ?? $search));
            })
            ->when($filters['store'] ?? null, function ($query, string $store) {
                $like = '%' . $store . '%';
                $query->whereHas('store', fn($s) => $s->where('name', 'like', $like)->orWhere('address', 'like', $like));
            })
            ->orderBy('name')
            ->orderBy('store_id')
            ->orderBy('id')
            ->paginate($filters['per_page'] ?? 20);

        return AdminProductResource::collection($products);
    }

    /** A shared catalog item and every store that carries it, each with its own price and stock. */
    public function catalog(CatalogProduct $catalogProduct)
    {
        $offers = $catalogProduct->products()
            ->with('store')
            ->orderBy('store_id')
            ->get();

        return response()->json([
            'data' => (new CatalogProductResource($catalogProduct))->resolve() + [
                'created_at' => $catalogProduct->created_at,
                'stores_count' => $offers->pluck('store_id')->unique()->count(),
                'offers' => AdminProductResource::collection($offers)->resolve(),
            ],
        ]);
    }
}
