<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\StoreStockAdjustmentRequest;
use App\Http\Resources\ProductResource;
use App\Http\Resources\StockMovementResource;
use App\Models\Product;
use App\Models\StockMovement;
use App\Services\AuditService;
use App\Services\StockService;
use App\Support\Quantity;
use Illuminate\Support\Facades\DB;

/**
 * US-0402 (FR-20, FR-21, UC-09): manual stock correction after a shelf count. Idempotent
 * (05 §2), Owner / Manager only, never below zero.
 */
class StockAdjustmentController extends Controller
{
    public function __construct(
        private readonly StockService $stock,
        private readonly AuditService $audit,
    ) {}

    public function store(StoreStockAdjustmentRequest $request)
    {
        $data = $request->validated();
        $quantity = Quantity::of((string) $data['quantity']);

        [$movement, $product] = DB::transaction(function () use ($request, $data, $quantity) {
            $product = Product::query()->forStore($request->user()->store_id)->findOrFail($data['product_id']);

            $movement = $this->stock->move(
                $product,
                Quantity::isNegative($quantity) ? StockMovement::TYPE_ADJUSTMENT_OUT : StockMovement::TYPE_ADJUSTMENT_IN,
                $quantity,
                $request->user(),
                $data['reason'],
            );

            $unit = $product->unit;
            $this->audit->record('stock.adjusted', $product, [
                'movement_id' => $movement->id,
                'quantity' => Quantity::format($quantity, $unit),
                // From the locked row inside move(), not a read taken before the lock.
                'balance_before' => Quantity::format(Quantity::sub($movement->balance_after, $quantity), $unit),
                'balance_after' => Quantity::format($movement->balance_after, $unit),
                'reason' => $data['reason'],
            ]);

            return [$movement, $product];
        });

        return response()->json([
            'message' => 'تم تعديل المخزون بنجاح',
            'movement' => new StockMovementResource($movement),
            'product' => new ProductResource($product),
        ], 201);
    }
}
