<?php

namespace App\Services;

use App\Exceptions\ApiException;
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
     * Rows that make a product part of the store's history. Any one of them means the product can
     * only be archived (status inactive), so invoices, returns and reports keep showing it.
     */
    private const HISTORY_TABLES = [
        'invoice_items' => 'product_id',
        'purchase_items' => 'product_id',
        'sale_return_items' => 'product_id',
        'purchase_return_items' => 'product_id',
        'suspended_invoice_items' => 'product_id',
        'inventory_reservations' => 'product_id',
        'supplier_payments' => 'product_id',
    ];

    public function __construct(private readonly AuditService $audit) {}

    /**
     * Can the product be removed for good? Only a product added by mistake: no sale, purchase,
     * return, held invoice or payment names it, and its stock ledger holds nothing but the opening
     * row written when it was created.
     */
    public function isDeletable(Product $product): bool
    {
        foreach (self::HISTORY_TABLES as $table => $column) {
            if (DB::table($table)->where($column, $product->id)->exists()) {
                return false;
            }
        }

        return !StockMovement::query()
            ->where('product_id', $product->id)
            ->where('type', '<>', StockMovement::TYPE_OPENING)
            ->exists();
    }

    /**
     * Permanent delete of an unused product (see isDeletable). Anything with history is refused
     * with 409 PRODUCT_IN_USE so the caller offers archiving instead. The product's opening row is
     * the only stock row removed: it records the product's creation, not a business operation, and
     * the audit entry keeps a snapshot of both. The shared catalog item is never touched.
     */
    public function delete(User $actor, Product $product, ?string $reason = null): void
    {
        DB::transaction(function () use ($actor, $product, $reason) {
            $locked = Product::query()->forStore($actor->store_id)->whereKey($product->id)->lockForUpdate()->firstOrFail();

            if (!$this->isDeletable($locked)) {
                throw ApiException::conflict(
                    'PRODUCT_IN_USE',
                    'لا يمكن حذف المنتج نهائيًا لأن له حركات أو فواتير مسجلة. يمكنك أرشفته (إيقافه) ليختفي من البيع ويبقى في السجلات.'
                );
            }

            $this->audit->record('product.deleted', $locked, [
                'reason' => $reason,
                'snapshot' => $locked->only(['name', 'barcode', 'unit', 'selling_price', 'cost_price', 'current_stock', 'status', 'catalog_product_id']),
                'opening_movements' => StockMovement::query()->where('product_id', $locked->id)->get(['id', 'quantity', 'created_at'])->toArray(),
            ], $actor);

            // The ledger model refuses deletes; this is the one sanctioned removal (opening rows only).
            DB::table('stock_movements')
                ->where('product_id', $locked->id)
                ->where('type', StockMovement::TYPE_OPENING)
                ->delete();
            $locked->delete();
        });
    }

    /** Plan limit `max_products`: active products the store may have (create, import). */
    public static function ensureProductRoom(\App\Models\Store $store, int $adding = 1): void
    {
        $max = $store->limit('max_products');
        if ($max !== null && $store->products()->where('status', Product::STATUS_ACTIVE)->count() + $adding > $max) {
            throw \App\Support\SubscriptionAccess::limitReached('max_products', $max);
        }
    }

    /**
     * US-0401 AC1: the product and its `opening` stock movement are created together, so
     * current_stock = Σ movements holds from the first row. A global barcode links the product to
     * the shared catalog, creating the catalog item when no store has saved it yet.
     */
    public function create(User $user, array $data): Product
    {
        self::ensureProductRoom($user->store);

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
