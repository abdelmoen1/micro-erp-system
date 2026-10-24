<?php

namespace App\Providers;

use App\Support\ProductionSafety;
use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Foundation\Events\DiagnosingHealth;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        //
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        ProductionSafety::enforce($this->app);

        // Account creation endpoints: 5 per minute per IP (US-0104).
        RateLimiter::for('register', fn(Request $request) => Limit::perMinute(5)->by($request->ip()));
        // Google sign-in: each call costs a round trip to Google.
        RateLimiter::for('sso', fn(Request $request) => Limit::perMinute(10)->by($request->ip()));

        // /up (hosting health check) fails when the database is unreachable, so a deploy
        // without a working database is never reported healthy.
        Event::listen(DiagnosingHealth::class, fn() => DB::connection()->getPdo());
    }
}
