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
    ) {
        parent::__construct($message);
    }

    public static function businessRule(string $code, string $message, array $errors = []): self
    {
        return new self(422, $code, $message, $errors);
    }
}
