<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Safe cancel (2026-11-27). Additive only: posted documents are never deleted, a mistake is voided.
 * A voided row keeps every amount it had, and records when, by whom and why it was voided; the
 * ledgers (supplier balance, customer statement, dashboard) leave voided rows out.
 *
 * - sale_returns / purchase_returns: a return created by mistake is cancelled and its effects reversed.
 * - purchase_invoices: a delivery recorded by mistake is voided (stock out, its payments voided).
 * - supplier_payments: a payment recorded by mistake is voided.
 * - suppliers.status: a supplier with history is archived (hidden from the picker), never deleted.
 */
return new class extends Migration
{
    private const VOIDABLE = ['sale_returns', 'purchase_returns', 'purchase_invoices', 'supplier_payments'];

    public function up(): void
    {
        foreach (self::VOIDABLE as $table) {
            Schema::table($table, function (Blueprint $table) {
                $table->timestamp('voided_at')->nullable();
                $table->foreignId('voided_by')->nullable()->constrained('users')->nullOnDelete();
                $table->string('void_reason', 500)->nullable();
            });
        }

        Schema::table('suppliers', function (Blueprint $table) {
            $table->string('status', 16)->default('active');
        });
    }

    public function down(): void
    {
        Schema::table('suppliers', function (Blueprint $table) {
            $table->dropColumn('status');
        });

        foreach (self::VOIDABLE as $table) {
            Schema::table($table, function (Blueprint $table) {
                $table->dropConstrainedForeignId('voided_by');
                $table->dropColumn(['voided_at', 'void_reason']);
            });
        }
    }
};
