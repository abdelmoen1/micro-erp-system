<?php

namespace Tests\Feature;

use App\Support\ProductionSafety;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Log\Events\MessageLogged;
use Illuminate\Support\Facades\Event;
use Tests\Support\BuildsShopData;
use Tests\TestCase;

/**
 * US-0104 — authentication hardening (regression for DEF-08 and DEF-15).
 */
class AuthHardeningTest extends TestCase
{
    use BuildsShopData;
    use RefreshDatabase;

    /** TC-0104-01: the 6th failed login for one email + IP within a minute is throttled. */
    public function test_login_is_throttled_after_five_failures(): void
    {
        $user = $this->makeUser($this->makeStore(), 'owner', ['email' => 'owner@example.com']);

        for ($i = 0; $i < 5; $i++) {
            $this->postJson('/api/v1/login', ['login' => $this->phoneOf('owner@example.com'), 'password' => 'wrong'])
                ->assertUnauthorized()
                ->assertJsonPath('code', 'INVALID_CREDENTIALS');
        }

        $throttled = $this->postJson('/api/v1/login', ['login' => $this->phoneOf('owner@example.com'), 'password' => 'password'])
            ->assertStatus(429)
            ->assertJsonPath('code', 'TOO_MANY_REQUESTS')
            ->assertHeader('Retry-After');
        $this->assertGreaterThan(0, (int) $throttled->headers->get('Retry-After'));

        // Another account from the same IP is not blocked.
        $this->makeUser($user->store, 'employee', ['email' => 'staff@example.com']);
        $this->postJson('/api/v1/login', ['login' => $this->phoneOf('staff@example.com'), 'password' => 'password'])->assertOk();

        // After the window passes, the right password works again.
        $this->travel(61)->seconds();
        $this->postJson('/api/v1/login', ['login' => $this->phoneOf('owner@example.com'), 'password' => 'password'])->assertOk();
    }

    public function test_registration_is_rate_limited_per_ip(): void
    {
        for ($i = 0; $i < 5; $i++) {
            $this->postJson('/api/v1/register', [])->assertUnprocessable();
        }

        $this->postJson('/api/v1/register', [])
            ->assertStatus(429)
            ->assertJsonPath('code', 'TOO_MANY_REQUESTS')
            ->assertHeader('Retry-After');
    }

    /** TC-0104-02: a token older than 30 days is rejected with 401. */
    public function test_tokens_expire_after_thirty_days(): void
    {
        $this->makeUser($this->makeStore(), 'owner', ['email' => 'owner@example.com']);

        $token = $this->postJson('/api/v1/login', ['login' => $this->phoneOf('owner@example.com'), 'password' => 'password'])
            ->assertOk()
            ->json('token');

        $this->travel(29)->days();
        $this->withToken($token)->getJson('/api/v1/me')->assertOk();
        $this->app['auth']->forgetGuards();

        $this->travel(2)->days();
        $this->withToken($token)->getJson('/api/v1/me')
            ->assertUnauthorized()
            ->assertJsonPath('code', 'UNAUTHENTICATED');
    }

    /** TC-0104-03: production never runs with debug enabled. */
    public function test_debug_is_forced_off_in_production(): void
    {
        $logged = [];
        Event::listen(MessageLogged::class, function (MessageLogged $event) use (&$logged) {
            $logged[] = $event;
        });

        $this->app['env'] = 'production';
        config(['app.debug' => true]);

        ProductionSafety::enforce($this->app);

        $this->assertFalse(config('app.debug'));
        $this->assertCount(1, array_filter($logged, fn(MessageLogged $e) => $e->level === 'critical'));

        $this->app['env'] = 'testing';
        config(['app.debug' => true]);
        ProductionSafety::enforce($this->app);
        $this->assertTrue(config('app.debug'), 'Non-production environments keep their setting.');
    }
}
