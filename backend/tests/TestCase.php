<?php

namespace Tests;

use Illuminate\Foundation\Testing\TestCase as BaseTestCase;
use Illuminate\Support\Str;
use Tests\Support\TestDatabaseGuard;

abstract class TestCase extends BaseTestCase
{
    protected function setUpTraits()
    {
        $connection = config('database.default');

        TestDatabaseGuard::assertSafe(
            (string) config("database.connections.{$connection}.driver"),
            (string) config("database.connections.{$connection}.database"),
        );

        return parent::setUpTraits();
    }

    /**
     * Headers carrying a fresh Idempotency-Key, for one financial request.
     */
    protected function idem(?string $key = null): array
    {
        return ['Idempotency-Key' => $key ?? (string) Str::uuid()];
    }
}
