<?php

namespace App\Services;

use App\Models\CatalogProduct;
use App\Models\Product;
use App\Models\StockMovement;
use App\Models\User;
use App\Support\Barcode;
use App\Support\Quantity;
use Closure;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class ProductService
{
    public const DUPLICATE_BARCODE = 'الباركود مستخدم لمنتج آخر في متجرك';

    /**
     * US-0401 AC1: the product and its `opening` stock movement are created together, so
     * current_stock = Σ movements holds from the first row. A global barcode links the product to
     * the shared catalog, creating the catalog item when no store has saved it yet.
     */
    public function create(User $user, array $data): Product
    {
        return $this->guardDuplicate(fn() => DB::transaction(function () use ($user, $data) {
            $openingStock = Quantity::of($data['current_stock'] ?? 0);
            $catalog = $this->catalogFor($data['barcode'] ?? null, $data, $user);

            $product = Product::create([
                ...$data,
                'store_id' => $user->store_id,
                'catalog_product_id' => $catalog?->id,
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
        }));
    }

    /**
     * Store-side edits only change this store's row; the shared catalog item is never edited here.
     * A new barcode re-links the product (or unlinks it when cleared or store-only).
     */
    public function update(User $user, Product $product, array $data): Product
    {
        return $this->guardDuplicate(fn() => DB::transaction(function () use ($user, $product, $data) {
            if (array_key_exists('barcode', $data) && $data['barcode'] !== $product->barcode) {
                $data['catalog_product_id'] = $this->catalogFor($data['barcode'], $data + $product->only('name', 'unit'), $user)?->id;
            }

            $product->update($data);

            return $product;
        }));
    }

    /**
     * The catalog item for a global barcode, inserted race-safely: concurrent first saves of the
     * same barcode from two stores both end up on the one row the unique index lets through.
     */
    private function catalogFor(?string $barcode, array $details, User $user): ?CatalogProduct
    {
        if (!Barcode::isGlobal($barcode)) {
            return null;
        }

        $existing = CatalogProduct::query()->where('barcode', $barcode)->first();
        if ($existing) {
            return $existing;
        }

        CatalogProduct::query()->insertOrIgnore([
            'barcode' => $barcode,
            'name' => $details['name'],
            'unit' => $details['unit'] ?? Quantity::UNIT_PIECE,
            'created_by_store_id' => $user->store_id,
            'created_by' => $user->id,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        // A locking read sees the winner's committed row even under repeatable read.
        return CatalogProduct::query()->where('barcode', $barcode)->sharedLock()->sole();
    }

    /**
     * The request's unique rule catches the ordinary duplicate; two simultaneous saves of one
     * barcode in one store reach the database index instead, and the loser gets the same 422
     * (its opening movement rolled back with it, so stock is never counted twice).
     */
    private function guardDuplicate(Closure $write): Product
    {
        try {
            return $write();
        } catch (UniqueConstraintViolationException) {
            throw ValidationException::withMessages(['barcode' => [self::DUPLICATE_BARCODE]]);
        }
    }
}
