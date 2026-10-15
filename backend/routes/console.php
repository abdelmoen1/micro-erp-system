<?php

use App\Services\IdempotencyService;
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
