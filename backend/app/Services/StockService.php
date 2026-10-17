<?php

namespace App\Services;

use App\Exceptions\ApiException;
use App\Models\Product;
use App\Models\StockMovement;
use App\Models\User;
use Illuminate\Support\Facades\DB;

/**
 * The only writer of stock changes after a product is created (US-0402). Every change is a
 * movement plus the matching `current_stock` update on the locked product row, so
 * current_stock = Σ movements holds (05 §invariants, rule 7).
 */
class StockService
{
    /**
     * Applies a signed quantity to the product. Sales (US-0501), voids (US-0503) and returns
     * (US-0601) reuse this with their own type and reference.
     *
     * @throws ApiException 422 INSUFFICIENT_STOCK when the balance would go below zero
     */
    public function move(
        Product $product,
        string $type,
        int $quantity,
        User $actor,
        ?string $reason = null,
        ?string $referenceType = null,
        ?int $referenceId = null,
    ): StockMovement {
        return DB::transaction(function () use ($product, $type, $quantity, $actor, $reason, $referenceType, $referenceId) {
            $locked = Product::query()->whereKey($product->id)->lockForUpdate()->firstOrFail();
            $balance = $locked->current_stock + $quantity;

            if ($balance < 0) {
                throw ApiException::businessRule('INSUFFICIENT_STOCK', 'الكمية المتوفرة في المخزون غير كافية.', [
                    'quantity' => ["المتوفر حاليًا {$locked->current_stock} فقط."],
                ]);
            }

            $movement = StockMovement::create([
                'store_id' => $locked->store_id,
                'product_id' => $locked->id,
                'type' => $type,
                'quantity' => $quantity,
                'balance_after' => $balance,
                'reason' => $reason,
                'reference_type' => $referenceType,
                'reference_id' => $referenceId,
                'created_by' => $actor->id,
            ]);

            $locked->update(['current_stock' => $balance]);
            $product->setRawAttributes($locked->getAttributes(), true);

            return $movement;
        });
    }

    /**
     * `hisbah:verify-stock`: products whose cached current_stock differs from Σ movements.
     *
     * @return list<array{product_id: int, store_id: int, name: string, current_stock: int, movements_sum: int}>
     */
    public function drift(?int $storeId = null): array
    {
        $sums = StockMovement::query()
            ->selectRaw('product_id, SUM(quantity) as total')
            ->groupBy('product_id');

        return Product::query()
            ->leftJoinSub($sums, 'sums', 'sums.product_id', '=', 'products.id')
            ->when($storeId, fn($query) => $query->where('products.store_id', $storeId))
            ->whereRaw('products.current_stock <> COALESCE(sums.total, 0)')
            ->orderBy('products.id')
            ->get(['products.id', 'products.store_id', 'products.name', 'products.current_stock', 'sums.total'])
            ->map(fn(Product $product) => [
                'product_id' => $product->id,
                'store_id' => (int) $product->store_id,
                'name' => $product->name,
                'current_stock' => $product->current_stock,
                'movements_sum' => (int) $product->total,
            ])
            ->all();
    }
}
