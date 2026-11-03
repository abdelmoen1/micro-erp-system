<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * A sale's discount at the till: `total_amount` stays what the customer owes (lines − discount), so
 * every figure that reads it is unchanged, and the lines' own sum is total + discount. A delivery
 * line can bring loose pieces from an opened carton next to its whole cartons.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('invoices', function (Blueprint $table) {
            $table->decimal('discount_amount', 12, 2)->default(0)->after('total_amount');
        });

        Schema::table('purchase_items', function (Blueprint $table) {
            $table->unsignedInteger('loose_pieces')->default(0)->after('pack_size');
        });
    }

    public function down(): void
    {
        Schema::table('purchase_items', function (Blueprint $table) {
            $table->dropColumn('loose_pieces');
        });

        Schema::table('invoices', function (Blueprint $table) {
            $table->dropColumn('discount_amount');
        });
    }
};
