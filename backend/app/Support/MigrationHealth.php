<?php

namespace App\Support;

use Illuminate\Database\Migrations\Migrator;
use RuntimeException;

/**
 * Part of /up: the code must not serve a database that lacks its migrations. Render switches traffic
 * to a new deploy only after /up answers 200, so a deploy that reaches production before its
 * migrations stays unhealthy while the previous version keeps serving (the 2026-11-25 outage: the
 * code read `inventory_reservations` a day before the table existed).
 */
class MigrationHealth
{
    /** Once every migration has run in this process, they stay run: later checks are skipped. */
    private static bool $current = false;

    public static function assertCurrent(Migrator $migrator): void
    {
        if (self::$current || !config('hisbah.health_requires_migrations', true)) {
            return;
        }

        $files = $migrator->getMigrationFiles(array_merge([database_path('migrations')], $migrator->paths()));
        $ran = $migrator->repositoryExists() ? $migrator->getRepository()->getRan() : [];
        $pending = array_values(array_diff(array_keys($files), $ran));

        if ($pending !== []) {
            throw new RuntimeException(count($pending) . ' pending migration(s), first: ' . $pending[0]);
        }

        self::$current = true;
    }

    /** Tests only: forget the cached result. */
    public static function reset(): void
    {
        self::$current = false;
    }
}
