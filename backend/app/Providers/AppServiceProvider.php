<?php

namespace App\Providers;

use App\Services\OtpService;
use App\Services\Sms\LogSmsSender;
use App\Services\Sms\SmsSender;
use App\Services\Sms\TextBeeSmsSender;
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
        // The SMS gateway for one-time codes; null switches the codes off (OtpService::enabled).
        $this->app->bind(SmsSender::class, function ($app): ?SmsSender {
            return match (config('services.sms.driver')) {
                'textbee' => config('services.textbee.key')
                    ? new TextBeeSmsSender(config('services.textbee.key'), config('services.textbee.device_id'), config('services.textbee.url'))
                    : null,
                'log' => $app->isProduction() ? null : new LogSmsSender(),
                default => null,
            };
        });
        $this->app->bind(OtpService::class, fn($app) => new OtpService($app->make(SmsSender::class)));
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
        // SMS codes cost real messages: a burst limit on top of OtpService's per-number limits.
        RateLimiter::for('otp', fn(Request $request) => Limit::perMinute(3)->by($request->ip()));

        // /up (hosting health check) fails when the database is unreachable, so a deploy
        // without a working database is never reported healthy.
        Event::listen(DiagnosingHealth::class, fn() => DB::connection()->getPdo());
    }
}
