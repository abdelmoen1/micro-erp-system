<?php

namespace App\Http\Middleware;

use App\Support\Money;
use Closure;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Adds meta.currency = "ILS" to every successful JSON object response, so
 * clients never have to guess the currency of string money values (US-0102).
 */
class AddCurrencyMeta
{
    public function handle(Request $request, Closure $next): Response
    {
        $response = $next($request);

        if (!$response->isSuccessful()
            || !str_contains((string) $response->headers->get('Content-Type'), 'json')) {
            return $response;
        }

        $data = json_decode((string) $response->getContent());

        if (!$data instanceof \stdClass) {
            return $response;
        }

        $data->meta = (object) ((array) ($data->meta ?? []) + ['currency' => Money::CURRENCY]);

        $options = $response instanceof JsonResponse ? $response->getEncodingOptions() : 0;
        $response->setContent(json_encode($data, $options));

        return $response;
    }
}
