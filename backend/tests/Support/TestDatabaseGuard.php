<?php

namespace Tests\Support;

use RuntimeException;

/**
 * Refuses to run destructive test migrations against anything that is not
 * an in-memory sqlite database or a server database named "*_test" (US-0108).
 */
final class TestDatabaseGuard
{
    public static function assertSafe(string $driver, string $database): void
    {
        if ($driver === 'sqlite') {
            if ($database === ':memory:' || str_ends_with($database, '_test.sqlite')) {
                return;
            }
        } elseif (preg_match('/_test$/', $database) === 1) {
            return;
        }

        throw new RuntimeException(
            "Refusing to run tests against database [{$database}] ({$driver}). "
            . 'Use an in-memory sqlite database or a database whose name ends in "_test".'
        );
    }
}
