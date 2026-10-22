<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * US-0701 (D-10): every debt names its customer, may have a due date, and records the credit
 * given back by returns (`remaining = amount − return_credit − Σ live payments`, 05 §1.3 rule 5).
 *
 * The backfill takes `customer_id` from the debt's own invoice, the only historical link. A debt
 * whose invoice has no customer is never guessed: the migration stops and names it.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('debts', function (Blueprint $table) {
            $table->foreignId('customer_id')->nullable()->after('invoice_id')->constrained('customers')->restrictOnDelete();
            $table->date('due_date')->nullable()->after('remaining_amount');
            $table->decimal('return_credit', 12, 2)->default(0)->after('remaining_amount');
        });

        DB::table('debts')->update([
            'customer_id' => DB::raw('(SELECT invoices.customer_id FROM invoices WHERE invoices.id = debts.invoice_id)'),
        ]);

        $unresolved = DB::table('debts')->whereNull('customer_id')->pluck('id');

        if ($unresolved->isNotEmpty()) {
            throw new RuntimeException(
                'US-0701 backfill: debts without a customer on their invoice: ' . $unresolved->implode(', ')
            );
        }

        Schema::table('debts', function (Blueprint $table) {
            $table->unsignedBigInteger('customer_id')->nullable(false)->change();
        });
    }

    public function down(): void
    {
        Schema::table('debts', function (Blueprint $table) {
            $table->dropConstrainedForeignId('customer_id');
            $table->dropColumn(['due_date', 'return_credit']);
        });
    }
};
