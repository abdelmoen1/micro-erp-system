<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\PurchaseItem;
use App\Models\Supplier;
use App\Support\Money;
use App\Support\Quantity;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;

/**
 * Platform admin «الموردون» (2026-11-07): every store's suppliers, the products each one delivers and
 * the latest wholesale price from the purchase invoices. A supplier belongs to one store; nothing is
 * merged across stores. Read only.
 */
class SupplierController extends Controller
{
    /** `search` matches the supplier or a product it delivered; `store` the store name, address or area. */
    public function index(Request $request)
    {
        $filters = $request->validate([
            'search' => ['nullable', 'string', 'max:150'],
            'store' => ['nullable', 'string', 'max:255'],
            'store_id' => ['nullable', 'integer'],
            'per_page' => ['nullable', 'integer', 'min:1', 'max:50'],
        ]);

        $suppliers = Supplier::query()
            ->with('store')
            ->withBalance()
            ->withMax('invoices as last_purchase_at', 'created_at')
            ->addSelect(['products_count' => PurchaseItem::query()
                ->selectRaw('count(distinct purchase_items.product_id)')
                ->join('purchase_invoices', 'purchase_invoices.id', '=', 'purchase_items.purchase_invoice_id')
                ->whereColumn('purchase_invoices.supplier_id', 'suppliers.id')])
            ->when($filters['store_id'] ?? null, fn($query, int $id) => $query->where('suppliers.store_id', $id))
            ->when($filters['search'] ?? null, function ($query, string $search) {
                $like = '%' . $search . '%';
                $query->where(fn($q) => $q->where('suppliers.name', 'like', $like)
                    ->orWhere('suppliers.phone', 'like', $like)
                    ->orWhereHas('invoices.items.product', fn($p) => $p->where('name', 'like', $like)));
            })
            ->when($filters['store'] ?? null, function ($query, string $store) {
                $like = '%' . $store . '%';
                $query->whereHas('store', fn($s) => $s->where('name', 'like', $like)->orWhere('address', 'like', $like)->orWhere('area', 'like', $like));
            })
            ->orderByDesc('last_purchase_at')
            ->orderBy('suppliers.name')
            ->orderBy('suppliers.id')
            ->paginate($filters['per_page'] ?? 20);

        return response()->json([
            'data' => $suppliers->getCollection()->map(fn(Supplier $s) => $this->row($s))->values(),
            'meta' => [
                'current_page' => $suppliers->currentPage(),
                'last_page' => $suppliers->lastPage(),
                'per_page' => $suppliers->perPage(),
                'total' => $suppliers->total(),
            ],
        ]);
    }

    /** One supplier and each product it delivered: the latest wholesale price, the one before, how much in all. */
    public function show(int $supplier)
    {
        $supplier = Supplier::query()
            ->with('store')
            ->withBalance()
            ->withMax('invoices as last_purchase_at', 'created_at')
            ->findOrFail($supplier);

        $lines = PurchaseItem::query()
            ->whereIn('purchase_invoice_id', $supplier->invoices()->select('id'))
            ->with('product')
            ->orderByDesc('id')
            ->get();

        $products = $lines->groupBy('product_id')->map(function ($rows) {
            /** @var PurchaseItem $last */
            $last = $rows->first();
            $product = $last->product;
            $previous = $rows->first(fn(PurchaseItem $line) => Money::compare($line->buy_price, $last->buy_price) !== 0);
            $kg = $product->unit === Quantity::UNIT_KG;
            $packSize = $kg ? null : max(1, (int) $last->pack_size);

            return [
                'id' => $product->id,
                'name' => $product->name,
                'barcode' => $product->barcode,
                'unit' => $product->unit,
                'status' => $product->status,
                // Per carton of `pack_size` pieces, or per kg for a weighed product.
                'buy_price' => Money::of($last->buy_price),
                'pack_size' => $packSize,
                'piece_price' => $kg ? null : Money::of(bcdiv((string) $last->buy_price, (string) $packSize, 4)),
                'previous_buy_price' => $previous ? Money::of($previous->buy_price) : null,
                'selling_price' => Money::of($product->selling_price),
                'quantity' => Quantity::format($rows->reduce(fn(string $sum, PurchaseItem $line) => Quantity::add($sum, $line->quantity), '0'), $product->unit),
                'deliveries' => $rows->count(),
                'last_at' => $last->created_at,
            ];
        })->sortBy('name')->values();

        $supplier->products_count = $products->count();

        return response()->json(['data' => $this->row($supplier) + ['products' => $products]]);
    }

    private function row(Supplier $supplier): array
    {
        return [
            'id' => $supplier->id,
            'name' => $supplier->name,
            'phone' => $supplier->phone,
            'store' => [
                'id' => $supplier->store->id,
                'name' => $supplier->store->name,
                'area' => $supplier->store->area,
            ],
            'products_count' => (int) ($supplier->products_count ?? 0),
            'last_purchase_at' => $supplier->last_purchase_at ? Carbon::parse($supplier->last_purchase_at) : null,
            'purchased' => Money::of($supplier->purchased),
            'balance' => Money::sub(Money::sub($supplier->purchased, $supplier->paid), $supplier->returned),
        ];
    }
}
