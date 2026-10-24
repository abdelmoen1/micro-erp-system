<?php

namespace App\Services;

use App\Exceptions\ApiException;
use App\Models\Product;
use App\Models\StockMovement;
use App\Models\User;
use App\Support\Quantity;
use Illuminate\Support\Facades\DB;

/**
 * The only writer of stock changes after a product is created (US-0402). Every change is a
 * movement plus the matching `current_stock` update on the locked product row, so
 * current_stock = Σ movements holds (05 §invariants, rule 7). Quantities are exact decimals
 * (CR-13: whole for pieces, up to 3 decimals for kg).
 */
class StockService
{
    /**
     * Applies a signed quantity to the product. Sales (US-0501), voids (US-0503) and returns
     * (US-0601) reuse this with their own type and reference.
     *
     * A sale may take the balance below zero (D-27: allowed with a warning and a NEGATIVE_STOCK
     * flag; the caller reads `balance_after`). Every other change must keep it at zero or above.
     *
     * @throws ApiException 422 INSUFFICIENT_STOCK when a non-sale change would go below zero
     */
    public function move(
        Product $product,
        string $type,
        int|string $quantity,
        User $actor,
        ?string $reason = null,
        ?string $referenceType = null,
        ?int $referenceId = null,
        bool $allowNegative = false,
    ): StockMovement {
        $quantity = Quantity::of($quantity);

        return DB::transaction(function () use ($product, $type, $quantity, $actor, $reason, $referenceType, $referenceId, $allowNegative) {
            $locked = Product::query()->whereKey($product->id)->lockForUpdate()->firstOrFail();
            $balance = Quantity::add($locked->current_stock, $quantity);

            if (!$allowNegative && Quantity::isNegative($balance)) {
                $available = Quantity::format($locked->current_stock, $locked->unit);

                throw ApiException::businessRule('INSUFFICIENT_STOCK', 'الكمية المتوفرة في المخزون غير كافية.', [
                    'quantity' => ["المتوفر حاليًا {$available} فقط."],
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
            $movement->setRelation('product', $locked);

            return $movement;
        });
    }

    /**
     * `hisbah:verify-stock`: products whose cached current_stock differs from Σ movements.
     * Compared to the gram, so sqlite's floating-point sums do not report false drift.
     *
     * @return list<array{product_id: int, store_id: int, name: string, current_stock: string, movements_sum: string}>
     */
    public function drift(?int $storeId = null): array
    {
        $sums = StockMovement::query()
            ->selectRaw('product_id, SUM(quantity) as total')
            ->groupBy('product_id');

        return Product::query()
            ->leftJoinSub($sums, 'sums', 'sums.product_id', '=', 'products.id')
            ->when($storeId, fn($query) => $query->where('products.store_id', $storeId))
            ->whereRaw('ROUND(products.current_stock - COALESCE(sums.total, 0), 3) <> 0')
            ->orderBy('products.id')
            ->get(['products.id', 'products.store_id', 'products.name', 'products.current_stock', 'sums.total'])
            ->map(fn(Product $product) => [
                'product_id' => $product->id,
                'store_id' => (int) $product->store_id,
                'name' => $product->name,
                'current_stock' => Quantity::of($product->current_stock),
                'movements_sum' => Quantity::of(round((float) $product->total, Quantity::SCALE)),
            ])
            ->all();
    }
}
