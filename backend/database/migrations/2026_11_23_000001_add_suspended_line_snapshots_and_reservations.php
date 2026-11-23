<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        $unmappedReservation = DB::table('inventory_reservations as reservations')
            ->leftJoin('suspended_invoice_items as items', function ($join): void {
                $join->on('items.suspended_invoice_id', '=', 'reservations.suspended_invoice_id')
                    ->on('items.product_id', '=', 'reservations.product_id');
            })
            ->select('reservations.id')
            ->groupBy('reservations.id')
            ->havingRaw('COUNT(items.id) <> 1')
            ->exists();
        $unreservedLine = DB::table('suspended_invoice_items as items')
            ->leftJoin('inventory_reservations as reservations', function ($join): void {
                $join->on('reservations.suspended_invoice_id', '=', 'items.suspended_invoice_id')
                    ->on('reservations.product_id', '=', 'items.product_id');
            })
            ->whereNull('reservations.id')
            ->exists();

        if ($unmappedReservation || $unreservedLine) {
            throw new RuntimeException(
                'Suspended invoice lines and inventory reservations do not map one-to-one; reconcile before migrating.'
            );
        }

        Schema::table('suspended_invoice_items', function (Blueprint $table) {
            $table->dropUnique(['suspended_invoice_id', 'product_id']);
            $table->decimal('base_quantity', 12, 3)->default(0);
        });

        DB::table('suspended_invoice_items')->update([
            'base_quantity' => DB::raw(
                "CASE WHEN sale_unit = 'pack' THEN quantity * COALESCE(pack_size, 1) ELSE quantity END"
            ),
        ]);

        Schema::table('inventory_reservations', function (Blueprint $table) {
            $table->foreignId('suspended_invoice_item_id')
                ->nullable()
                ->constrained('suspended_invoice_items')
                ->cascadeOnDelete();
        });

        DB::table('inventory_reservations')->orderBy('id')->chunkById(500, function ($reservations): void {
            foreach ($reservations as $reservation) {
                $itemIds = DB::table('suspended_invoice_items')
                    ->where('suspended_invoice_id', $reservation->suspended_invoice_id)
                    ->where('product_id', $reservation->product_id)
                    ->orderBy('id')
                    ->pluck('id');

                if ($itemIds->count() !== 1) {
                    throw new RuntimeException(
                        "Cannot map inventory reservation {$reservation->id} to exactly one suspended invoice item."
                    );
                }

                DB::table('inventory_reservations')
                    ->where('id', $reservation->id)
                    ->update(['suspended_invoice_item_id' => $itemIds->first()]);
            }
        });

        Schema::table('inventory_reservations', function (Blueprint $table) {
            $table->unique('suspended_invoice_item_id');
        });
    }

    public function down(): void
    {
        $hasMixedUnits = DB::table('suspended_invoice_items')
            ->select('suspended_invoice_id', 'product_id')
            ->groupBy('suspended_invoice_id', 'product_id')
            ->havingRaw('COUNT(*) > 1')
            ->exists();

        if ($hasMixedUnits) {
            throw new RuntimeException(
                'Cannot roll back suspended line identity while an invoice has multiple lines for one product.'
            );
        }

        Schema::table('inventory_reservations', function (Blueprint $table) {
            $table->dropUnique(['suspended_invoice_item_id']);
            $table->dropConstrainedForeignId('suspended_invoice_item_id');
        });

        Schema::table('suspended_invoice_items', function (Blueprint $table) {
            $table->dropColumn('base_quantity');
            $table->unique(['suspended_invoice_id', 'product_id']);
        });
    }
};
