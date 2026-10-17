<?php

use App\Services\IdempotencyService;
use App\Services\StockService;
use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;
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
