<?php

use App\Support\Barcode;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Shared product catalog: `catalog_products` holds the identity of a barcoded item once for the
 * whole platform; `products` stays the store's own row (price, cost, stock, name) and is still what
 * invoice items, stock movements and returns reference, so no history moves.
 *
 * Backfill: store barcodes are normalized (App\Support\Barcode) unless that would collide inside the
 * store, and every product with a global GTIN is linked to its catalog row. When stores disagree on
 * the details, the catalog takes the oldest product's name and unit; each store keeps its own.
 * Nothing is merged or deleted.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('catalog_products', function (Blueprint $table) {
            $table->id();
            $table->string('barcode', 64)->unique();
            $table->string('name');
            $table->string('unit', 8)->default('piece');
            $table->foreignId('created_by_store_id')->nullable()->constrained('stores')->nullOnDelete();
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();

            $table->index('name');
        });

        Schema::table('products', function (Blueprint $table) {
            $table->foreignId('catalog_product_id')->nullable()->after('store_id')
                ->constrained('catalog_products')->restrictOnDelete();
            // One link per store and catalog item; NULLs (unshared products) do not collide.
            $table->unique(['store_id', 'catalog_product_id']);
        });

        $this->backfill();
    }

    private function backfill(): void
    {
        $rows = DB::table('products')->whereNotNull('barcode')->orderBy('id')
            ->get(['id', 'store_id', 'barcode', 'name', 'unit']);

        // Barcodes already in normal form keep their spelling; a variant that normalizes onto one of
        // them (or onto an earlier variant) is left exactly as it was, unlinked, for the shop to review.
        $taken = [];
        foreach ($rows as $row) {
            if (Barcode::normalize($row->barcode) === $row->barcode) {
                $taken[$row->store_id . '|' . $row->barcode] = true;
            }
        }

        $catalogIds = [];
        $now = now();

        foreach ($rows as $row) {
            $code = Barcode::normalize($row->barcode);
            if ($code === null) {
                continue;
            }

            $changes = [];
            if ($code !== $row->barcode) {
                $key = $row->store_id . '|' . $code;
                if (isset($taken[$key])) {
                    continue;
                }
                $taken[$key] = true;
                $changes['barcode'] = $code;
            }

            if (Barcode::isGlobal($code)) {
                $changes['catalog_product_id'] = $catalogIds[$code] ??= DB::table('catalog_products')->insertGetId([
                    'barcode' => $code,
                    'name' => $row->name,
                    'unit' => $row->unit,
                    'created_by_store_id' => $row->store_id,
                    'created_at' => $now,
                    'updated_at' => $now,
                ]);
            }

            if ($changes !== []) {
                DB::table('products')->where('id', $row->id)->update($changes);
            }
        }
    }

    /** Drops the catalog link; normalized store barcodes keep their normalized spelling. */
    public function down(): void
    {
        Schema::table('products', function (Blueprint $table) {
            $table->dropUnique(['store_id', 'catalog_product_id']);
            $table->dropConstrainedForeignId('catalog_product_id');
        });

        Schema::dropIfExists('catalog_products');
    }
};
