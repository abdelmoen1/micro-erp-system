<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;
use Symfony\Component\HttpFoundation\Response;

/**
 * Gives every request a correlation id (client-supplied if well-formed),
 * shares it with the log context and echoes it in the response header.
 */
class AssignCorrelationId
{
    public const HEADER = 'X-Correlation-ID';

    private const ATTRIBUTE = 'correlation_id';

    public function handle(Request $request, Closure $next): Response
    {
        $id = self::current($request);

        Log::shareContext(['correlation_id' => $id]);

        $response = $next($request);
        $response->headers->set(self::HEADER, $id);

        return $response;
    }

    public static function current(Request $request): string
    {
        $id = $request->attributes->get(self::ATTRIBUTE);

        if (!$id) {
            $incoming = (string) $request->headers->get(self::HEADER, '');
            $id = preg_match('/^[A-Za-z0-9\-]{8,64}$/', $incoming) ? $incoming : (string) Str::ulid();
            $request->attributes->set(self::ATTRIBUTE, $id);
        }

        return $id;
    }
}
