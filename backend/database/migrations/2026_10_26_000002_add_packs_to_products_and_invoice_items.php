<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Wholesale cartons. Stock stays in the product's base unit (`unit`: piece or kg); a piece product
 * may also be sold or received by the carton: `pack_size` pieces for `pack_price`.
 *
 * An invoice line keeps a snapshot of the carton size it was sold with: `quantity` and
 * `unit_price` are then per carton, and stock moved by quantity × pack_size. Every existing line
 * has no snapshot (NULL = sold in the base unit), so its meaning is unchanged; nothing is
 * backfilled or rewritten.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('products', function (Blueprint $table) {
            $table->unsignedInteger('pack_size')->nullable()->after('cost_price');
            $table->decimal('pack_price', 12, 2)->nullable()->after('pack_size');
        });

        Schema::table('invoice_items', function (Blueprint $table) {
            $table->unsignedInteger('pack_size')->nullable()->after('quantity');
        });
    }

    /** Refuses once a carton was sold: without the snapshot, "2 cartons" would read as 2 pieces. */
    public function down(): void
    {
        if (DB::table('invoice_items')->whereNotNull('pack_size')->exists()) {
            throw new RuntimeException('Carton sales exist; rolling back would change their quantities.');
        }

        Schema::table('invoice_items', function (Blueprint $table) {
            $table->dropColumn('pack_size');
        });

        Schema::table('products', function (Blueprint $table) {
            $table->dropColumn(['pack_size', 'pack_price']);
        });
    }
};
