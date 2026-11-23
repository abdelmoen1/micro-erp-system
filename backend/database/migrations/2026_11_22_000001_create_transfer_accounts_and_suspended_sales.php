<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('receiving_accounts', function (Blueprint $table) {
            $table->id();
            $table->foreignId('store_id')->constrained()->restrictOnDelete();
            $table->string('provider');
            $table->string('account_name');
            $table->string('account_identifier');
            $table->boolean('active')->default(true);
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignId('updated_by')->nullable()->constrained('users')->nullOnDelete();
            $table->softDeletes();
            $table->timestamps();
            $table->index(['store_id', 'provider', 'active']);
        });

        Schema::create('suspended_invoices', function (Blueprint $table) {
            $table->id();
            $table->foreignId('store_id')->constrained()->restrictOnDelete();
            $table->string('reference')->unique();
            $table->foreignId('customer_id')->nullable()->constrained()->nullOnDelete();
            $table->foreignId('cashier_id')->constrained('users')->restrictOnDelete();
            $table->string('status')->default('draft')->index();
            $table->decimal('subtotal', 10, 2);
            $table->decimal('discount_amount', 10, 2)->default(0);
            $table->decimal('total_amount', 10, 2);
            $table->string('payment_method')->nullable();
            $table->foreignId('receiving_account_id')->nullable()->constrained('receiving_accounts')->nullOnDelete();
            $table->string('account_snapshot_name')->nullable();
            $table->string('account_snapshot_provider')->nullable();
            $table->string('account_snapshot_identifier')->nullable();
            $table->foreignId('final_invoice_id')->nullable()->constrained('invoices')->nullOnDelete();
            $table->string('idempotency_key')->nullable()->index();
            $table->text('notes')->nullable();
            $table->text('cancellation_reason')->nullable();
            $table->foreignId('closed_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('closed_at')->nullable();
            $table->timestamps();
            $table->index(['store_id', 'cashier_id', 'status']);
        });

        Schema::create('suspended_invoice_items', function (Blueprint $table) {
            $table->id();
            $table->foreignId('suspended_invoice_id')->constrained()->restrictOnDelete();
            $table->foreignId('product_id')->constrained()->restrictOnDelete();
            $table->string('item_name');
            $table->string('unit');
            $table->decimal('quantity', 12, 3);
            $table->string('sale_unit')->nullable();
            $table->unsignedInteger('pack_size')->nullable();
            $table->decimal('unit_price', 10, 2);
            $table->decimal('total', 10, 2);
            $table->timestamps();
            $table->unique(['suspended_invoice_id', 'product_id']);
        });

        Schema::create('inventory_reservations', function (Blueprint $table) {
            $table->id();
            $table->foreignId('store_id')->constrained()->restrictOnDelete();
            $table->foreignId('product_id')->constrained()->restrictOnDelete();
            $table->foreignId('suspended_invoice_id')->constrained()->restrictOnDelete();
            $table->decimal('quantity', 12, 3);
            $table->string('status')->default('active')->index();
            $table->timestamp('released_at')->nullable();
            $table->timestamp('deducted_at')->nullable();
            $table->timestamps();
            $table->index(['store_id', 'product_id', 'status']);
        });

        Schema::create('suspended_invoice_events', function (Blueprint $table) {
            $table->id();
            $table->foreignId('store_id')->constrained()->restrictOnDelete();
            $table->foreignId('suspended_invoice_id')->constrained()->restrictOnDelete();
            $table->foreignId('user_id')->constrained()->restrictOnDelete();
            $table->string('from_status')->nullable();
            $table->string('to_status');
            $table->string('event');
            $table->json('metadata')->nullable();
            $table->timestamps();
            $table->index(['suspended_invoice_id', 'created_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('suspended_invoice_events');
        Schema::dropIfExists('inventory_reservations');
        Schema::dropIfExists('suspended_invoice_items');
        Schema::dropIfExists('suspended_invoices');
        Schema::dropIfExists('receiving_accounts');
    }
};
