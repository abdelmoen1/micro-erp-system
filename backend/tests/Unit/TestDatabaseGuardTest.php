<?php

namespace Tests\Unit;

use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\TestCase;
use RuntimeException;
use Tests\Support\TestDatabaseGuard;

/**
 * TC-0108-03: the suite refuses to run against a non-test database.
 */
class TestDatabaseGuardTest extends TestCase
{
    public static function unsafe(): array
    {
        return [
            'real mysql db' => ['mysql', 'erp_system'],
            'mariadb prod name' => ['mariadb', 'debt_manager'],
            'test in the middle' => ['mysql', 'hisbah_test_backup'],
            'sqlite file' => ['sqlite', 'database/database.sqlite'],
        ];
    }

    #[DataProvider('unsafe')]
    public function test_non_test_databases_are_refused(string $driver, string $database): void
    {
        $this->expectException(RuntimeException::class);
        TestDatabaseGuard::assertSafe($driver, $database);
    }

    public function test_test_databases_are_allowed(): void
    {
        TestDatabaseGuard::assertSafe('mysql', 'hisbah_test');
        TestDatabaseGuard::assertSafe('mariadb', 'hisbah_test');
        TestDatabaseGuard::assertSafe('sqlite', ':memory:');
        $this->addToAssertionCount(3);
    }
}
