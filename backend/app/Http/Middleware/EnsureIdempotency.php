<?php

namespace App\Http\Middleware;

use App\Exceptions\ApiException;
use App\Services\IdempotencyService;
use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Str;
use Symfony\Component\HttpFoundation\Response;

/**
 * Requires an Idempotency-Key (UUID) on financial writes and runs the
 * request through IdempotencyService (US-0101).
 */
class EnsureIdempotency
{
    public const HEADER = 'Idempotency-Key';

    public function __construct(private readonly IdempotencyService $service) {}

    public function handle(Request $request, Closure $next): Response
    {
        $key = trim((string) $request->header(self::HEADER, ''));

        if ($key === '') {
            throw new ApiException(
                428,
                'IDEMPOTENCY_KEY_REQUIRED',
                'هذه العملية تتطلب مفتاح منع التكرار (Idempotency-Key).',
            );
        }

        if (!Str::isUuid($key)) {
            throw new ApiException(
                422,
                'IDEMPOTENCY_KEY_INVALID',
                'مفتاح منع التكرار يجب أن يكون بصيغة UUID.',
            );
        }

        $user = $request->user();
        $methodPath = $request->method() . ' /' . $request->path();

        return $this->service->run(
            (int) $user->store_id,
            $user->id,
            strtolower($key),
            self::fingerprint($methodPath, $request->all()),
            $methodPath,
            fn() => $next($request),
        );
    }

    /** Also used by the offline sync, so a queued request matches its own online attempt. */
    public static function fingerprint(string $methodPath, array $input): string
    {
        return hash('sha256', $methodPath . '|' . json_encode(self::sortKeys($input)));
    }

    private static function sortKeys(array $value): array
    {
        if (!array_is_list($value)) {
            ksort($value);
        }

        return array_map(
            fn($item) => is_array($item) ? self::sortKeys($item) : $item,
            $value,
        );
    }
}
