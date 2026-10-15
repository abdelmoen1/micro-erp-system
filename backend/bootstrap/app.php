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
        $middleware->prepend(\App\Http\Middleware\AssignCorrelationId::class);

        $middleware->api(append: [
            \App\Http\Middleware\AddCurrencyMeta::class,
        ]);

        $middleware->alias([
            'store' => \App\Http\Middleware\EnsureUserHasStore::class,
            'active' => \App\Http\Middleware\EnsureUserIsActive::class,
            'idempotent' => \App\Http\Middleware\EnsureIdempotency::class,
        ]);
    })
    ->withExceptions(function (Exceptions $exceptions) {
        $exceptions->dontReport(ApiException::class);

        $exceptions->render(function (Throwable $e, Request $request) {
            if ($request->is('api/*')) {
                return ApiExceptionRenderer::render($e, $request);
            }
        });
    })->create();
