<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * US-0401 (FR-15, FR-16, BR-04): store products. Quantities are integers (CR-13).
 * `current_stock` is a cache of Σ stock_movements.quantity (05 §invariants, rule 7).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('products', function (Blueprint $table) {
            $table->id();
            $table->foreignId('store_id')->constrained('stores')->restrictOnDelete();
            $table->string('name');
            $table->string('barcode', 64)->nullable();
            $table->decimal('selling_price', 12, 2);
            $table->decimal('cost_price', 12, 2)->nullable();
            $table->integer('current_stock')->default(0);
            $table->integer('minimum_stock')->default(5);
            $table->string('status', 16)->default('active');
            $table->timestamps();

            // Barcodes are unique per store; NULL barcodes do not collide.
            $table->unique(['store_id', 'barcode']);
            $table->index(['store_id', 'name']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('products');
    }
};
