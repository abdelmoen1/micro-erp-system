<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * US-0501 (05 §1.1, doc 15 §4): a sale line points at its product and snapshots the unit;
 * quantities are DECIMAL(12,3). `returned_quantity` is filled by returns (US-0601) and blocks a void.
 * Legacy lines keep `product_id = null`: they never moved stock.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('invoice_items', function (Blueprint $table) {
            $table->foreignId('product_id')->nullable()->after('invoice_id')->constrained('products')->restrictOnDelete();
            $table->string('unit', 8)->default('piece')->after('item_name');
            $table->decimal('quantity', 12, 3)->change();
            $table->decimal('returned_quantity', 12, 3)->default(0)->after('quantity');
        });
    }

    public function down(): void
    {
        if (DB::table('invoice_items')->where('unit', 'kg')->exists()) {
            throw new RuntimeException('Weighed sale lines exist; rolling back would truncate their quantities.');
        }

        Schema::table('invoice_items', function (Blueprint $table) {
            $table->dropConstrainedForeignId('product_id');
            $table->dropColumn(['unit', 'returned_quantity']);
            $table->unsignedInteger('quantity')->change();
        });
    }
};
