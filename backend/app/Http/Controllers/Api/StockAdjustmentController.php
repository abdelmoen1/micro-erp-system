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
        $quantity = (int) $data['quantity'];

        [$movement, $product] = DB::transaction(function () use ($request, $data, $quantity) {
            $product = Product::query()->forStore($request->user()->store_id)->findOrFail($data['product_id']);

            $movement = $this->stock->move(
                $product,
                $quantity > 0 ? StockMovement::TYPE_ADJUSTMENT_IN : StockMovement::TYPE_ADJUSTMENT_OUT,
                $quantity,
                $request->user(),
                $data['reason'],
            );

            $this->audit->record('stock.adjusted', $product, [
                'movement_id' => $movement->id,
                'quantity' => $quantity,
                // From the locked row inside move(), not a read taken before the lock.
                'balance_before' => $movement->balance_after - $quantity,
                'balance_after' => $movement->balance_after,
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
