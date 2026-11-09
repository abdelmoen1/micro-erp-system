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

        // Signed-in API calls: a ceiling per account, far above what the till or the web uses, that
        // stops a leaked token or a runaway client from hammering the API. Keyed by user, not IP:
        // behind the hosting proxies many shops can share one address.
        RateLimiter::for('api', fn(Request $request) => $request->user()
            ? Limit::perMinute(300)->by('user:' . $request->user()->getAuthIdentifier())
            : Limit::perMinute(60)->by('ip:' . $request->ip()));
        // Behind Render (and the Vercel /api rewrite) many shops may reach Laravel from ONE address,
        // so an IP-only limit would let one abusive client block sign-up for everyone. Each limiter
        // is keyed by IP + the mobile number in the request (tight), with a looser IP-wide ceiling.
        $number = fn(Request $request) => (string) \App\Support\PhoneNumber::normalize(
            (string) ($request->input('owner_phone') ?? $request->input('phone') ?? ''),
        );
        // Account creation, invitations, password reset, public deletion (US-0104).
        RateLimiter::for('register', fn(Request $request) => [
            Limit::perMinute(5)->by('reg:' . $request->ip() . '|' . $number($request)),
            Limit::perMinute(30)->by('reg-ip:' . $request->ip()),
        ]);
        // SMS codes cost real messages: a burst limit on top of OtpService's per-number limits.
        RateLimiter::for('otp', fn(Request $request) => [
            Limit::perMinute(3)->by('otp:' . $request->ip() . '|' . $number($request)),
            Limit::perMinute(20)->by('otp-ip:' . $request->ip()),
        ]);

        // /up (hosting health check) fails when the database is unreachable, so a deploy
        // without a working database is never reported healthy.
        Event::listen(DiagnosingHealth::class, fn() => DB::connection()->getPdo());
    }
}
