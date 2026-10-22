<?php

namespace App\Providers;

use App\Support\ProductionSafety;
use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Http\Request;
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
    }
}
