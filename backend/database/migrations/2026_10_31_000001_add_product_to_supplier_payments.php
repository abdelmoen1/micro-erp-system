<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Payments now belong to a product of the supplier, as each product has its own invoices and
 * balance. Payments made before this are split across that supplier's lines, oldest first.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('supplier_payments', function (Blueprint $table) {
            $table->foreignId('product_id')->nullable()->after('purchase_invoice_id')->constrained()->nullOnDelete();
            $table->index(['supplier_id', 'product_id']);
        });

        foreach (DB::table('supplier_payments')->distinct()->pluck('supplier_id') as $supplierId) {
            $this->spread($supplierId);
        }
    }

    private function spread(int $supplierId): void
    {
        $lines = DB::table('purchase_items')
            ->join('purchase_invoices', 'purchase_invoices.id', '=', 'purchase_items.purchase_invoice_id')
            ->where('purchase_invoices.supplier_id', $supplierId)
            ->orderBy('purchase_items.id')
            ->get(['purchase_items.product_id', 'purchase_items.line_total'])
            ->map(fn($line) => ['product_id' => $line->product_id, 'left' => (string) $line->line_total])
            ->all();

        foreach (DB::table('supplier_payments')->where('supplier_id', $supplierId)->orderBy('id')->get() as $payment) {
            $amount = (string) $payment->amount;
            $first = true;

            foreach ($lines as &$line) {
                if (bccomp($amount, '0', 2) <= 0) {
                    break;
                }
                if (bccomp($line['left'], '0', 2) <= 0) {
                    continue;
                }
                $part = bccomp($amount, $line['left'], 2) > 0 ? $line['left'] : $amount;
                $line['left'] = bcsub($line['left'], $part, 2);
                $amount = bcsub($amount, $part, 2);

                $row = ['product_id' => $line['product_id'], 'amount' => $part];
                if ($first) {
                    DB::table('supplier_payments')->where('id', $payment->id)->update($row);
                    $first = false;
                } else {
                    $copy = array_diff_key((array) $payment, ['id' => true]);
                    DB::table('supplier_payments')->insert(array_merge($copy, $row));
                }
            }
            unset($line);
        }
    }

    public function down(): void
    {
        Schema::table('supplier_payments', function (Blueprint $table) {
            $table->dropIndex(['supplier_id', 'product_id']);
            $table->dropConstrainedForeignId('product_id');
        });
    }
};
