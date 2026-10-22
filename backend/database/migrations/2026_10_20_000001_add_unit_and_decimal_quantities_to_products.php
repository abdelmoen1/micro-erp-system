<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * CR-13 (modified 2026-10-19, doc 15 §4): products are sold by the `piece` or by the `kg`.
 * Quantities become DECIMAL(12,3) so 0.750 kg is exact; existing integer values are kept as-is.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('products', function (Blueprint $table) {
            $table->string('unit', 8)->default('piece')->after('barcode');
            $table->decimal('current_stock', 12, 3)->default(0)->change();
            $table->decimal('minimum_stock', 12, 3)->default(5)->change();
        });

        Schema::table('stock_movements', function (Blueprint $table) {
            $table->decimal('quantity', 12, 3)->change();
            $table->decimal('balance_after', 12, 3)->change();
        });
    }

    /** Only safe while every quantity is whole; refuses to truncate weighed stock. */
    public function down(): void
    {
        $fractional = DB::table('products')->where('unit', 'kg')->exists();

        if ($fractional) {
            throw new RuntimeException('Weighed products exist; rolling back would truncate their stock.');
        }

        Schema::table('stock_movements', function (Blueprint $table) {
            $table->integer('quantity')->change();
            $table->integer('balance_after')->change();
        });

        Schema::table('products', function (Blueprint $table) {
            $table->integer('current_stock')->default(0)->change();
            $table->integer('minimum_stock')->default(5)->change();
            $table->dropColumn('unit');
        });
    }
};
