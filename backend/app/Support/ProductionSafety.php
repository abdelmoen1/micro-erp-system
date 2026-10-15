<?php

namespace App\Support;

use Illuminate\Contracts\Foundation\Application;
use Illuminate\Support\Facades\Log;

/**
 * Never serve production with debug output enabled (US-0104 AC3, DEF-15).
 * Debug is forced off and a critical log entry flags the misconfiguration.
 */
final class ProductionSafety
{
    public static function enforce(Application $app): void
    {
        if (!$app->environment('production') || !config('app.debug')) {
            return;
        }

        config(['app.debug' => false]);

        Log::critical('APP_DEBUG=true in production was overridden to false. Fix the environment file.');
    }
}
