<?php

namespace App\Services;

use App\Exceptions\ApiException;
use App\Models\InventoryReservation;
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
     * A sale may take unreserved balance below zero (D-27), but no outgoing movement can reduce
     * physical stock below active reservations. Every other change must also keep stock nonnegative.
     *
     * @throws ApiException 422 when an outgoing movement would consume a reservation or forbidden negative stock
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
        ?int $reservationId = null,
    ): StockMovement {
        $quantity = Quantity::of($quantity);

        return DB::transaction(function () use ($product, $type, $quantity, $actor, $reason, $referenceType, $referenceId, $allowNegative, $reservationId) {
            $locked = Product::query()->whereKey($product->id)->lockForUpdate()->firstOrFail();
            $balance = Quantity::add($locked->current_stock, $quantity);
            $reservations = InventoryReservation::query()
                ->where('store_id', $locked->store_id)
                ->where('product_id', $locked->id)
                ->where('status', InventoryReservation::STATUS_ACTIVE)
                ->orderBy('id')
                ->lockForUpdate()
                ->get();
            $reservationToConsume = null;
            $reservedForOthers = '0.000';

            foreach ($reservations as $reservation) {
                if ($reservationId !== null && $reservation->id === $reservationId) {
                    $reservationToConsume = $reservation;
                    continue;
                }
                $reservedForOthers = Quantity::add($reservedForOthers, $reservation->quantity);
            }

            if ($reservationId !== null) {
                if (
                    !$reservationToConsume
                    || Quantity::compare($quantity, Quantity::negate($reservationToConsume->quantity)) !== 0
                ) {
                    throw ApiException::conflict(
                        'RESERVATION_MISMATCH',
                        'حجز المخزون لا يطابق الكمية المطلوب إكمالها.'
                    );
                }
            }

            if (
                Quantity::isNegative($quantity)
                && Quantity::compare($reservedForOthers, '0') > 0
                && Quantity::compare($balance, $reservedForOthers) < 0
            ) {
                throw ApiException::businessRule(
                    'INSUFFICIENT_UNRESERVED_STOCK',
                    'لا يمكن استخدام مخزون محجوز لفاتورة معلقة.',
                    ['quantity' => ['المخزون المتاح بعد الحجوزات غير كافٍ.']]
                );
            }

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
            if ($reservationToConsume) {
                $reservationToConsume->update([
                    'status' => InventoryReservation::STATUS_DEDUCTED,
                    'deducted_at' => now(),
                ]);
            }
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
