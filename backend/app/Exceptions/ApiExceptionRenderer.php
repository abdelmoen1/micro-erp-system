<?php

namespace App\Exceptions;

use App\Http\Middleware\AssignCorrelationId;
use Illuminate\Auth\Access\AuthorizationException;
use Illuminate\Auth\AuthenticationException;
use Illuminate\Database\Eloquent\ModelNotFoundException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpKernel\Exception\HttpExceptionInterface;
use Throwable;

/**
 * Renders every API error as {message, code, errors, correlation_id}.
 * Unexpected exceptions never leak details; they are reported to the log
 * by the framework with the same correlation_id.
 */
class ApiExceptionRenderer
{
    private const STATUS_CODES = [
        400 => 'BAD_REQUEST',
        401 => 'UNAUTHENTICATED',
        403 => 'FORBIDDEN',
        404 => 'NOT_FOUND',
        405 => 'METHOD_NOT_ALLOWED',
        409 => 'CONFLICT',
        419 => 'SESSION_EXPIRED',
        422 => 'BUSINESS_RULE_VIOLATION',
        428 => 'PRECONDITION_REQUIRED',
        429 => 'TOO_MANY_REQUESTS',
    ];

    private const DEFAULT_MESSAGES = [
        401 => 'يجب تسجيل الدخول للمتابعة.',
        403 => 'غير مصرح لك بتنفيذ هذا الإجراء.',
        404 => 'العنصر المطلوب غير موجود.',
        405 => 'طريقة الطلب غير مدعومة.',
        429 => 'محاولات كثيرة، يرجى المحاولة لاحقاً.',
        500 => 'حدث خطأ غير متوقع، يرجى المحاولة لاحقاً.',
    ];

    public static function render(Throwable $e, Request $request): JsonResponse
    {
        [$status, $code, $message, $errors, $headers] = self::describe($e);

        $correlationId = AssignCorrelationId::current($request);

        $body = [
            'message' => $message,
            'code' => $code,
            'errors' => (object) $errors,
            'correlation_id' => $correlationId,
        ];

        // Optional machine-readable facts for codes that need them (e.g. the credit-limit amounts).
        if ($e instanceof ApiException && $e->details !== []) {
            $body['details'] = $e->details;
        }

        return response()->json($body, $status, $headers + [AssignCorrelationId::HEADER => $correlationId]);
    }

    private static function describe(Throwable $e): array
    {
        if ($e instanceof ApiException) {
            return [$e->status, $e->errorCode, $e->getMessage(), $e->errors, $e->headers];
        }

        if ($e instanceof ValidationException) {
            $errors = $e->errors();
            $first = collect($errors)->flatten()->first() ?? 'البيانات المدخلة غير صحيحة.';

            return [422, 'VALIDATION_FAILED', $first, $errors, []];
        }

        if ($e instanceof AuthenticationException) {
            return [401, 'UNAUTHENTICATED', self::DEFAULT_MESSAGES[401], [], []];
        }

        if ($e instanceof AuthorizationException) {
            return [403, 'FORBIDDEN', self::DEFAULT_MESSAGES[403], [], []];
        }

        if ($e instanceof ModelNotFoundException) {
            return [404, 'NOT_FOUND', self::DEFAULT_MESSAGES[404], [], []];
        }

        if ($e instanceof HttpExceptionInterface) {
            $status = $e->getStatusCode();

            if ($status >= 500) {
                return [$status, 'SERVER_ERROR', self::DEFAULT_MESSAGES[500], [], []];
            }

            // Framework exceptions (404 route, 403 policy, 429 throttle) carry
            // English or technical messages; abort(422, '...') carries ours.
            $message = $status === 422 && $e->getMessage() !== ''
                ? $e->getMessage()
                : (self::DEFAULT_MESSAGES[$status] ?? ($e->getMessage() ?: 'تعذر تنفيذ الطلب.'));

            return [$status, self::STATUS_CODES[$status] ?? 'HTTP_' . $status, $message, [], $e->getHeaders()];
        }

        return [500, 'SERVER_ERROR', self::DEFAULT_MESSAGES[500], [], []];
    }
}
