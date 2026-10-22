<?php

namespace App\Services;

use App\Models\Product;
use App\Models\StockMovement;
use App\Models\User;
use App\Support\Quantity;
use Illuminate\Support\Facades\DB;

class ProductService
{
    /**
     * US-0401 AC1: the product and its `opening` stock movement are created together, so
     * current_stock = Σ movements holds from the first row.
     */
    public function create(User $user, array $data): Product
    {
        return DB::transaction(function () use ($user, $data) {
            $openingStock = Quantity::of($data['current_stock'] ?? 0);

            $product = Product::create([
                ...$data,
                'store_id' => $user->store_id,
                'current_stock' => $openingStock,
                'status' => Product::STATUS_ACTIVE,
            ]);

            StockMovement::create([
                'store_id' => $user->store_id,
                'product_id' => $product->id,
                'type' => StockMovement::TYPE_OPENING,
                'quantity' => $openingStock,
                'balance_after' => $openingStock,
                'created_by' => $user->id,
            ]);

            // Reload so database defaults (minimum_stock) are in the response.
            return $product->refresh();
        });
    }
}
