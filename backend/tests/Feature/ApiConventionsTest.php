<?php

namespace Tests\Feature;

use App\Models\Store;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Log\Events\MessageLogged;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Route;
use Tests\TestCase;

/**
 * US-0106 — API v1 conventions and error envelope.
 */
class ApiConventionsTest extends TestCase
{
    use RefreshDatabase;

    private function owner(): User
    {
        $store = Store::create(['name' => 'Main']);

        return User::factory()->create([
            'store_id' => $store->id,
            'role' => 'owner',
            'email' => 'owner@example.com',
            'password' => Hash::make('password'),
        ]);
    }

    /** TC-0106-01: v1 routes serve; the old prefix returns 404. */
    public function test_v1_routes_serve_and_old_prefix_is_gone(): void
    {
        $this->owner();

        $this->getJson('/api/customers')->assertNotFound();
        $this->getJson('/api/v1/customers')->assertUnauthorized();

        $this->postJson('/api/v1/login', ['email' => 'owner@example.com', 'password' => 'password'])
            ->assertOk()
            ->assertJsonStructure(['token', 'user']);

        $this->postJson('/api/login', ['email' => 'owner@example.com', 'password' => 'password'])
            ->assertNotFound()
            ->assertJsonPath('code', 'NOT_FOUND');
    }

    /** TC-0106-02: validation, auth, policy and business errors share one envelope. */
    public function test_errors_follow_the_envelope(): void
    {
        $envelope = ['message', 'code', 'errors', 'correlation_id'];

        $this->postJson('/api/v1/login', [])
            ->assertUnprocessable()
            ->assertJsonStructure($envelope)
            ->assertJsonPath('code', 'VALIDATION_FAILED')
            ->assertJsonStructure(['errors' => ['email', 'password']]);

        $this->getJson('/api/v1/me')
            ->assertUnauthorized()
            ->assertJsonStructure($envelope)
            ->assertJsonPath('code', 'UNAUTHENTICATED');

        $this->owner();
        $this->postJson('/api/v1/login', ['email' => 'owner@example.com', 'password' => 'wrong'])
            ->assertUnauthorized()
            ->assertJsonPath('code', 'INVALID_CREDENTIALS');

        $employee = User::factory()->create(['store_id' => Store::first()->id, 'role' => 'employee']);
        $this->actingAs($employee, 'sanctum')->getJson('/api/v1/users')
            ->assertForbidden()
            ->assertJsonStructure($envelope)
            ->assertJsonPath('code', 'FORBIDDEN');

        $this->actingAs($employee, 'sanctum')->getJson('/api/v1/customers/999999')
            ->assertNotFound()
            ->assertJsonPath('code', 'NOT_FOUND');
    }

    /** TC-0106-03: an unexpected exception is a generic 500 with a correlation id, and is logged (DEF-14). */
    public function test_unexpected_exception_is_logged_and_not_leaked(): void
    {
        Route::middleware('api')->prefix('api/v1')->get('/_test/explode', function () {
            throw new \RuntimeException('secret internal detail');
        });

        $logged = [];
        Event::listen(MessageLogged::class, function (MessageLogged $event) use (&$logged) {
            $logged[] = $event;
        });

        $response = $this->withHeader('X-Correlation-ID', 'test-correlation-0001')
            ->getJson('/api/v1/_test/explode');

        $response->assertStatus(500)
            ->assertJsonPath('code', 'SERVER_ERROR')
            ->assertJsonPath('correlation_id', 'test-correlation-0001')
            ->assertHeader('X-Correlation-ID', 'test-correlation-0001');
        $this->assertStringNotContainsString('secret internal detail', $response->getContent());

        $errors = array_filter($logged, fn(MessageLogged $e) => $e->level === 'error'
            && str_contains($e->message, 'secret internal detail'));
        $this->assertCount(1, $errors, 'The exception must be reported to the log.');
        $this->assertSame('test-correlation-0001', array_values($errors)[0]->context['correlation_id'] ?? null);
    }

    public function test_every_response_carries_a_correlation_id(): void
    {
        $this->getJson('/api/v1/me')->assertHeader('X-Correlation-ID');
    }
}
