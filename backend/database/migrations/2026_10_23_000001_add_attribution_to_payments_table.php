<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * US-0703 (D-10, DEF-10): a payment names its store and customer directly, and a reversal names
 * who reversed it. The backfill takes both from the payment's own debt, the only historical link;
 * a payment whose debt cannot be resolved stops the migration instead of being guessed.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('payments', function (Blueprint $table) {
            $table->foreignId('store_id')->nullable()->after('id')->constrained('stores')->restrictOnDelete();
            $table->foreignId('customer_id')->nullable()->after('debt_id')->constrained('customers')->restrictOnDelete();
            $table->foreignId('reversed_by')->nullable()->after('reversed_at')->constrained('users')->nullOnDelete();
        });

        DB::table('payments')->update([
            'store_id' => DB::raw('(SELECT debts.store_id FROM debts WHERE debts.id = payments.debt_id)'),
            'customer_id' => DB::raw('(SELECT debts.customer_id FROM debts WHERE debts.id = payments.debt_id)'),
        ]);

        $unresolved = DB::table('payments')->whereNull('store_id')->orWhereNull('customer_id')->pluck('id');

        if ($unresolved->isNotEmpty()) {
            throw new RuntimeException('US-0703 backfill: payments without a resolvable debt: ' . $unresolved->implode(', '));
        }

        Schema::table('payments', function (Blueprint $table) {
            $table->unsignedBigInteger('store_id')->nullable(false)->change();
            $table->unsignedBigInteger('customer_id')->nullable(false)->change();
            $table->index(['store_id', 'paid_at']);
        });
    }

    public function down(): void
    {
        Schema::table('payments', function (Blueprint $table) {
            $table->dropIndex(['store_id', 'paid_at']);
            $table->dropConstrainedForeignId('reversed_by');
            $table->dropConstrainedForeignId('customer_id');
            $table->dropConstrainedForeignId('store_id');
        });
    }
};
