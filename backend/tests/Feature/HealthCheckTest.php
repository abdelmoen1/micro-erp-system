<?php

namespace Tests\Feature;

use Illuminate\Support\Facades\DB;
use Tests\TestCase;

/**
 * /up is the hosting health check (render.yaml): it must report a missing database as unhealthy
 * instead of only proving that Laravel boots.
 */
class HealthCheckTest extends TestCase
{
    public function test_up_is_healthy_when_the_database_answers(): void
    {
        $this->get('/up')->assertOk();
    }

    public function test_up_fails_when_the_database_is_unreachable(): void
    {
        config(['database.connections.broken' => [
            'driver' => 'sqlite',
            'database' => '/nonexistent-dir/hisbah.sqlite',
        ]]);
        config(['database.default' => 'broken']);
        DB::purge('broken');

        $this->get('/up')->assertServerError();
    }
}
