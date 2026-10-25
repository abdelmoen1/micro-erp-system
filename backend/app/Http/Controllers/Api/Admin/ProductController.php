<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Http\Resources\AdminCatalogProductResource;
use App\Http\Resources\AdminProductResource;
use App\Http\Resources\CatalogProductResource;
use App\Models\CatalogProduct;
use App\Models\Product;
use App\Support\Barcode;
use App\Support\Money;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

/**
 * Platform admin: product rows across stores. Each row is one store's own product (price, cost,
 * stock); nothing is summed or merged across stores. Products with a global barcode share a
 * catalog item, which links the rows without combining them.
 */
class ProductController extends Controller
{
    /** `search` matches the product name or barcode; `store` matches the store name, address or area. */
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
                $query->whereHas('store', fn($s) => $s->where('name', 'like', $like)->orWhere('address', 'like', $like)->orWhere('area', 'like', $like));
            })
            ->orderBy('name')
            ->orderBy('store_id')
            ->orderBy('id')
            ->paginate($filters['per_page'] ?? 20);

        return AdminProductResource::collection($products);
    }

    /**
     * The shared catalog: one row per barcode, how many stores carry it and the range of their
     * active selling prices. `search` matches the name or the barcode. Most widely carried first.
     */
    public function catalogIndex(Request $request)
    {
        $filters = $request->validate([
            'search' => ['nullable', 'string', 'max:255'],
            'per_page' => ['nullable', 'integer', 'min:1', 'max:50'],
        ]);
        $active = fn($query) => $query->where('status', Product::STATUS_ACTIVE);

        $items = CatalogProduct::query()
            ->withCount(['products as stores_count', 'products as active_stores_count' => $active])
            ->withMin(['products as price_min' => $active], 'selling_price')
            ->withMax(['products as price_max' => $active], 'selling_price')
            ->when($filters['search'] ?? null, function ($query, string $search) {
                $query->where(fn($q) => $q->where('name', 'like', '%' . $search . '%')
                    ->orWhere('barcode', Barcode::normalize($search) ?? $search));
            })
            ->orderByDesc('stores_count')
            ->orderBy('name')
            ->orderBy('id')
            ->paginate($filters['per_page'] ?? 20);

        return AdminCatalogProductResource::collection($items);
    }

    /**
     * A shared catalog item and every store that carries it, each with its own price and stock, plus
     * the price comparison across the stores that sell it now (active rows).
     */
    public function catalog(CatalogProduct $catalogProduct)
    {
        $offers = $catalogProduct->products()
            ->with('store')
            ->orderBy('selling_price')
            ->orderBy('store_id')
            ->get();
        $prices = $offers->where('status', Product::STATUS_ACTIVE)->pluck('selling_price')
            ->sort(fn($a, $b) => Money::compare($a, $b))->values();

        return response()->json([
            'data' => (new CatalogProductResource($catalogProduct))->resolve() + [
                'created_at' => $catalogProduct->created_at,
                'stores_count' => $offers->pluck('store_id')->unique()->count(),
                'comparison' => [
                    'active_stores_count' => $prices->count(),
                    'price_min' => $prices->isEmpty() ? null : Money::of($prices->first()),
                    'price_max' => $prices->isEmpty() ? null : Money::of($prices->last()),
                    'price_spread' => $prices->isEmpty() ? null : Money::sub($prices->last(), $prices->first()),
                ],
                'offers' => AdminProductResource::collection($offers)->resolve(),
            ],
        ]);
    }
}
