<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * US-0501 / US-0503 (05 §1.1):
 * - `paid_amount` is the money received at the till (D-08);
 * - `customer_id` is optional for fully paid sales (D-07);
 * - an invoice is final at creation and corrected only by a void (D-06), so it gets a status
 *   and void attribution; `notes` stay editable.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('invoices', function (Blueprint $table) {
            $table->decimal('paid_amount', 12, 2)->default(0)->after('total_amount');
            $table->string('status', 16)->default('active')->after('paid_amount');
            $table->text('notes')->nullable();
            $table->foreignId('created_by')->nullable()->constrained('users')->restrictOnDelete();
            $table->timestamp('voided_at')->nullable();
            $table->foreignId('voided_by')->nullable()->constrained('users')->restrictOnDelete();
            $table->string('void_reason', 500)->nullable();
            $table->unsignedBigInteger('customer_id')->nullable()->change();
        });

        // Backfill (05 §1.1): before this change a cash invoice was paid in full at the till and a
        // credit invoice received nothing; the debt rows hold everything paid later.
        DB::table('invoices')->where('has_debt', false)->update(['paid_amount' => DB::raw('total_amount')]);
        DB::table('invoices')->where('has_debt', true)->update(['paid_amount' => 0]);
    }

    public function down(): void
    {
        if (DB::table('invoices')->whereNull('customer_id')->exists()) {
            throw new RuntimeException('Walk-in sales exist; customer_id cannot become required again.');
        }

        Schema::table('invoices', function (Blueprint $table) {
            $table->dropConstrainedForeignId('created_by');
            $table->dropConstrainedForeignId('voided_by');
            $table->dropColumn(['paid_amount', 'status', 'notes', 'voided_at', 'void_reason']);
            $table->unsignedBigInteger('customer_id')->nullable(false)->change();
        });
    }
};
