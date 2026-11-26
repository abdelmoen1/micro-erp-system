<?php

namespace Tests\Feature;

use App\Support\MigrationHealth;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

/**
 * /up also fails while one of this code's migrations has not run. Render routes traffic to a new
 * deploy only once /up answers 200, so code that reaches production before its migrations stays
 * out of service while the previous version keeps serving.
 */
class MigrationHealthCheckTest extends TestCase
{
    use RefreshDatabase;

    /** The table the 2026-11-25 outage was missing: the code read it a day before it existed. */
    private const RESERVATIONS = '2026_11_23_000001_add_suspended_line_snapshots_and_reservations';

    protected function setUp(): void
    {
        parent::setUp();
        MigrationHealth::reset();
    }

    protected function tearDown(): void
    {
        MigrationHealth::reset();
        parent::tearDown();
    }

    public function test_up_is_healthy_when_every_migration_ran(): void
    {
        $this->get('/up')->assertOk();
    }

    public function test_up_fails_while_a_migration_has_not_run(): void
    {
        DB::table('migrations')->where('migration', self::RESERVATIONS)->delete();

        $this->get('/up')->assertServerError();
    }

    public function test_the_check_can_be_switched_off_for_a_deliberate_rollback(): void
    {
        config(['hisbah.health_requires_migrations' => false]);
        DB::table('migrations')->where('migration', self::RESERVATIONS)->delete();

        $this->get('/up')->assertOk();
    }

    public function test_a_healthy_result_is_kept_for_the_process(): void
    {
        $this->get('/up')->assertOk();
        DB::table('migrations')->delete();

        // Migrations never un-run in production, so the check is not repeated once it passed.
        $this->get('/up')->assertOk();
    }

    public function test_version_reports_the_deployed_commit_without_signing_in(): void
    {
        config(['hisbah.commit' => 'e88e424c9158b655489cf50c0285a59ac91860a4']);

        $this->getJson('/api/v1/version')
            ->assertOk()
            ->assertJsonPath('data.commit', 'e88e424c9158b655489cf50c0285a59ac91860a4');
    }
}
