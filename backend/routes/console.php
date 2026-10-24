<?php

use App\Services\IdempotencyService;
use App\Services\StockService;
use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schedule;

Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote');

Artisan::command('idempotency:prune {--days=30}', function (IdempotencyService $service) {
    $days = max(30, (int) $this->option('days'));
    $deleted = $service->prune($days);
    $this->info("Pruned {$deleted} idempotency keys older than {$days} days.");
})->purpose('Delete idempotency keys older than the retention window (min 30 days)');

Schedule::command('idempotency:prune')->daily();

// US-0402 T-0402-4 (04 §stock invariant): read-only drift report; exit code 1 when any product drifts.
Artisan::command('hisbah:verify-stock {--store= : Only check this store id}', function (StockService $stock) {
    $drift = $stock->drift($this->option('store') ? (int) $this->option('store') : null);

    if ($drift === []) {
        $this->info('Stock OK: current_stock equals the sum of stock movements for every product.');

        return 0;
    }

    $this->table(['product_id', 'store_id', 'name', 'current_stock', 'movements_sum'], $drift);
    $this->error(count($drift) . ' product(s) drift from their stock movements.');

    return 1;
})->purpose('Check that products.current_stock equals the sum of their stock movements');

// US-0701 (D-10): read-only coverage report of the debts.customer_id backfill; exit code 1 on any gap.
Artisan::command('hisbah:verify-debts', function () {
    $total = DB::table('debts')->count();
    $matching = DB::table('debts')
        ->join('invoices', 'invoices.id', '=', 'debts.invoice_id')
        ->whereColumn('debts.customer_id', 'invoices.customer_id')
        ->count();
    $mismatched = DB::table('debts')
        ->join('invoices', 'invoices.id', '=', 'debts.invoice_id')
        ->whereColumn('debts.customer_id', '<>', 'invoices.customer_id')
        ->pluck('debts.id');
    $missing = DB::table('debts')->whereNull('customer_id')->pluck('id');

    $this->table(['debts', 'customer matches invoice', 'mismatched', 'without customer'], [
        [$total, $matching, $mismatched->count(), $missing->count()],
    ]);

    if ($matching === $total) {
        $this->info($total === 0 ? 'No debts to check.' : "Backfill complete: {$matching} of {$total} debts (100%).");

        return 0;
    }

    $this->error('Debts to review: ' . $mismatched->merge($missing)->unique()->implode(', '));

    return 1;
})->purpose('Report how many debts carry the same customer as their invoice (US-0701 backfill)');
