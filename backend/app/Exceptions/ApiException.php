<?php

namespace App\Exceptions;

use RuntimeException;

/**
 * A business or protocol error with a stable machine-readable code.
 * Rendered as the v1 error envelope by ApiExceptionRenderer.
 */
class ApiException extends RuntimeException
{
    public function __construct(
        public readonly int $status,
        public readonly string $errorCode,
        string $message,
        public readonly array $errors = [],
        public readonly array $headers = [],
        public readonly array $details = [],
    ) {
        parent::__construct($message);
    }

    public static function businessRule(string $code, string $message, array $errors = [], array $details = []): self
    {
        return new self(422, $code, $message, $errors, details: $details);
    }

    /** 409: the request is valid but the record's current state does not allow it. */
    public static function conflict(string $code, string $message): self
    {
        return new self(409, $code, $message);
    }
}
