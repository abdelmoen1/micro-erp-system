<?php

use App\Exceptions\ApiException;
use App\Exceptions\ApiExceptionRenderer;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Request;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__ . '/../routes/web.php',
        api: __DIR__ . '/../routes/api.php',
        commands: __DIR__ . '/../routes/console.php',
        health: '/up',
        apiPrefix: 'api/v1',
    )
    ->withMiddleware(function (Middleware $middleware) {
        // Render, Railway and similar hosts terminate HTTPS at their edge and forward plain HTTP.
        // Trust the forwarded scheme/host/port so generated URLs (e.g. Vite assets) are https.
        // X-Forwarded-For is deliberately NOT trusted: the login throttle keys on the client IP,
        // and trusting it from any proxy would let a client spoof it.
        $middleware->trustProxies(
            at: '*',
            headers: Request::HEADER_X_FORWARDED_HOST
                | Request::HEADER_X_FORWARDED_PORT
                | Request::HEADER_X_FORWARDED_PROTO,
        );

        // There is no `login` web route: API guests get the 401 JSON envelope even without an
        // `Accept: application/json` header, instead of a failed redirect (500).
        $middleware->redirectGuestsTo(fn (Request $request) => $request->is('api/*') ? null : '/');

        $middleware->prepend(\App\Http\Middleware\AssignCorrelationId::class);

        $middleware->api(append: [
            \App\Http\Middleware\AddCurrencyMeta::class,
        ]);

        $middleware->alias([
            'store' => \App\Http\Middleware\EnsureUserHasStore::class,
            'active' => \App\Http\Middleware\EnsureUserIsActive::class,
            'idempotent' => \App\Http\Middleware\EnsureIdempotency::class,
            'platform.admin' => \App\Http\Middleware\EnsurePlatformAdmin::class,
            'subscribed' => \App\Http\Middleware\EnsureStoreSubscription::class,
        ]);

        // Admin routes refuse non-admins before {store} is resolved: no 404/403 difference to probe ids with.
        $middleware->prependToPriorityList(
            \Illuminate\Routing\Middleware\SubstituteBindings::class,
            \App\Http\Middleware\EnsurePlatformAdmin::class,
        );
    })
    ->withExceptions(function (Exceptions $exceptions) {
        $exceptions->dontReport(ApiException::class);

        $exceptions->render(function (Throwable $e, Request $request) {
            if ($request->is('api/*')) {
                return ApiExceptionRenderer::render($e, $request);
            }
        });
    })->create();
