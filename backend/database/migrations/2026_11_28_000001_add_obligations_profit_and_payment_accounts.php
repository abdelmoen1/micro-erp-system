<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Net profit on Home (2026-11-28):
 * - obligations: the store's running costs (rent, electricity, salaries, anything the owner adds),
 *   each an amount per day, week, month or year; Home takes each day's share off the profit.
 * - invoice_items.unit_cost: the product's cost per piece (or kg) when the line was sold, so a
 *   later delivery at a new price never rewrites past profit. Older lines fall back to the
 *   product's current cost.
 * - payments: the transfer account a debt repayment was received on, like a transfer sale.
 * All additive: nothing existing changes.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('obligations', function (Blueprint $table) {
            $table->id();
            $table->foreignId('store_id')->constrained()->restrictOnDelete();
            $table->string('name');
            $table->decimal('amount', 12, 2);
            $table->string('frequency', 16)->default('monthly');
            $table->boolean('active')->default(true);
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignId('updated_by')->nullable()->constrained('users')->nullOnDelete();
            $table->softDeletes();
            $table->timestamps();
            $table->index(['store_id', 'active']);
        });

        Schema::table('invoice_items', function (Blueprint $table) {
            $table->decimal('unit_cost', 12, 2)->nullable()->after('unit_price');
        });

        Schema::table('payments', function (Blueprint $table) {
            $table->foreignId('receiving_account_id')->nullable()->after('method')
                ->constrained('receiving_accounts')->nullOnDelete();
            $table->string('account_snapshot_name')->nullable()->after('receiving_account_id');
            $table->string('account_snapshot_identifier')->nullable()->after('account_snapshot_name');
        });
    }

    public function down(): void
    {
        Schema::table('payments', function (Blueprint $table) {
            $table->dropConstrainedForeignId('receiving_account_id');
            $table->dropColumn(['account_snapshot_name', 'account_snapshot_identifier']);
        });

        Schema::table('invoice_items', function (Blueprint $table) {
            $table->dropColumn('unit_cost');
        });

        Schema::dropIfExists('obligations');
    }
};
