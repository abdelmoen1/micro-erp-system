<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Goods sent back to a supplier, the mirror of a sale return: `balance_reduction` lowers what the
 * store owes the supplier and `refund_amount` is what the supplier paid back; together they equal
 * `total_amount`. A line with `from_stock` false was already off the shelf (a customer returned it
 * damaged), so it moves no stock. A sale return line marked `damaged` never goes back on the shelf.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('sale_return_items', function (Blueprint $table) {
            $table->boolean('damaged')->default(false)->after('total');
        });

        Schema::table('purchase_items', function (Blueprint $table) {
            $table->decimal('returned_quantity', 12, 3)->default(0)->after('quantity');
        });

        Schema::create('purchase_returns', function (Blueprint $table) {
            $table->id();
            $table->foreignId('store_id')->constrained()->restrictOnDelete();
            $table->foreignId('supplier_id')->constrained()->restrictOnDelete();
            $table->foreignId('purchase_invoice_id')->constrained()->restrictOnDelete();
            $table->decimal('total_amount', 12, 2);
            $table->decimal('balance_reduction', 12, 2)->default(0);
            $table->decimal('refund_amount', 12, 2)->default(0);
            $table->text('reason');
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();

            $table->index(['store_id', 'created_at']);
            $table->index(['supplier_id', 'created_at']);
        });

        Schema::create('purchase_return_items', function (Blueprint $table) {
            $table->id();
            $table->foreignId('purchase_return_id')->constrained()->cascadeOnDelete();
            $table->foreignId('purchase_item_id')->constrained()->restrictOnDelete();
            $table->foreignId('product_id')->nullable()->constrained()->nullOnDelete();
            // In the product's unit (pieces or kg), like purchase_items.quantity.
            $table->decimal('quantity', 12, 3);
            $table->decimal('total', 12, 2);
            $table->boolean('from_stock')->default(true);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('purchase_return_items');
        Schema::dropIfExists('purchase_returns');

        Schema::table('purchase_items', function (Blueprint $table) {
            $table->dropColumn('returned_quantity');
        });

        Schema::table('sale_return_items', function (Blueprint $table) {
            $table->dropColumn('damaged');
        });
    }
};
