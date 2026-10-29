<?php

use App\Models\User;
use App\Services\IdempotencyService;
use App\Services\StockService;
use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
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

// Platform owner dashboard: the only way to grant or revoke platform admin. It promotes an existing
// account (no account or password is ever created here), so run it on the server after signing up.
Artisan::command('hisbah:platform-admin {phone : Mobile number of an existing account} {--revoke : Remove platform admin instead}', function () {
    $phone = \App\Support\PhoneNumber::normalize($this->argument('phone'));
    $user = $phone ? User::where('phone', $phone)->first() : null;

    if (!$user) {
        $this->error('No account uses that mobile number. Register it first, then run this command again.');

        return 1;
    }

    $grant = !$this->option('revoke');

    if ($grant && !$user->isActive()) {
        $this->error('The account is deactivated; reactivate it before granting platform admin.');

        return 1;
    }

    $user->forceFill(['is_platform_admin' => $grant])->save();

    if (!$grant) {
        // Revocation takes effect at once on every device.
        $user->tokens()->delete();
    }

    Log::notice($grant ? 'Platform admin granted.' : 'Platform admin revoked.', ['user_id' => $user->id]);
    $this->info(($grant ? 'Granted' : 'Revoked') . " platform admin for user #{$user->id}.");

    return 0;
})->purpose('Grant (or --revoke) platform admin for an existing account');
