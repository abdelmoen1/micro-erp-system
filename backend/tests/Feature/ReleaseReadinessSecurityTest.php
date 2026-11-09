<?php

namespace Tests\Feature;

use App\Models\PhoneOtp;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\Support\BuildsShopData;
use Tests\TestCase;

/**
 * Pre-launch security checks (docs/release-readiness/SECURITY_AUDIT.md): response headers, CORS,
 * sign-in limits, per-account API limit, hostile input, token revocation and store deletion.
 */
class ReleaseReadinessSecurityTest extends TestCase
{
    use BuildsShopData;
    use RefreshDatabase;

    public function test_api_responses_carry_security_headers_even_on_errors(): void
    {
        $response = $this->getJson('/api/v1/me')->assertUnauthorized();

        $response->assertHeader('X-Content-Type-Options', 'nosniff')
            ->assertHeader('X-Frame-Options', 'DENY')
            ->assertHeader('Referrer-Policy', 'no-referrer')
            ->assertHeader('Content-Security-Policy', "default-src 'none'; frame-ancestors 'none'")
            ->assertHeaderMissing('X-Powered-By');
        // HSTS only once the request is known to be HTTPS.
        $response->assertHeaderMissing('Strict-Transport-Security');

        $this->getJson('/api/v1/auth/options', ['X-Forwarded-Proto' => 'https'])
            ->assertOk()
            ->assertHeader('Strict-Transport-Security', 'max-age=31536000');
    }

    public function test_cors_allows_only_listed_origins(): void
    {
        $this->getJson('/api/v1/auth/options', ['Origin' => 'https://hisbah-web.vercel.app'])
            ->assertOk()
            ->assertHeader('Access-Control-Allow-Origin', 'https://hisbah-web.vercel.app');

        $this->getJson('/api/v1/auth/options', ['Origin' => 'https://evil.example'])
            ->assertOk()
            ->assertHeaderMissing('Access-Control-Allow-Origin');

        // A preflight from an unknown origin is not granted either.
        $this->call('OPTIONS', '/api/v1/login', [], [], [], [
            'HTTP_ORIGIN' => 'https://evil.example',
            'HTTP_ACCESS_CONTROL_REQUEST_METHOD' => 'POST',
        ])->assertHeaderMissing('Access-Control-Allow-Origin');

        $this->call('OPTIONS', '/api/v1/login', [], [], [], [
            'HTTP_ORIGIN' => 'https://hisbah-web.vercel.app',
            'HTTP_ACCESS_CONTROL_REQUEST_METHOD' => 'POST',
            'HTTP_ACCESS_CONTROL_REQUEST_HEADERS' => 'authorization,content-type,idempotency-key',
        ])->assertHeader('Access-Control-Allow-Origin', 'https://hisbah-web.vercel.app');
    }

    public function test_a_number_is_locked_after_twenty_failures_in_an_hour_from_any_address(): void
    {
        $owner = $this->makeUser($this->makeStore(), 'owner');

        // 4 failures from each of 5 addresses: never 5 a minute from one, 20 in total.
        foreach (range(1, 5) as $n) {
            for ($i = 0; $i < 4; $i++) {
                $this->withServerVariables(['REMOTE_ADDR' => "203.0.113.{$n}"])
                    ->postJson('/api/v1/login', ['login' => $owner->phone, 'password' => 'wrong'])
                    ->assertUnauthorized();
            }
        }

        // A sixth address, and even the right password, is refused for the rest of the hour.
        $this->withServerVariables(['REMOTE_ADDR' => '198.51.100.7'])
            ->postJson('/api/v1/login', ['login' => $owner->phone, 'password' => 'password'])
            ->assertStatus(429)
            ->assertJsonPath('code', 'TOO_MANY_REQUESTS');

        $this->travel(61)->minutes();
        $this->postJson('/api/v1/login', ['login' => $owner->phone, 'password' => 'password'])->assertOk();
    }

    public function test_unknown_number_and_wrong_password_get_the_same_answer(): void
    {
        $owner = $this->makeUser($this->makeStore(), 'owner');

        $wrong = $this->postJson('/api/v1/login', ['login' => $owner->phone, 'password' => 'wrong'])->assertUnauthorized();
        $unknown = $this->postJson('/api/v1/login', ['login' => '0599999999', 'password' => 'wrong'])->assertUnauthorized();

        $this->assertSame($wrong->json('code'), $unknown->json('code'));
        $this->assertSame($wrong->json('message'), $unknown->json('message'));
    }

    public function test_a_signed_in_account_is_limited_per_minute(): void
    {
        $owner = $this->makeUser($this->makeStore(), 'owner');
        $token = $owner->createToken('t')->plainTextToken;

        for ($i = 0; $i < 300; $i++) {
            $this->withToken($token)->getJson('/api/v1/me')->assertOk();
            $this->app['auth']->forgetGuards();
        }

        $this->withToken($token)->getJson('/api/v1/me')
            ->assertStatus(429)
            ->assertJsonPath('code', 'TOO_MANY_REQUESTS');

        // Another account is not affected.
        $other = $this->makeUser($this->makeStore('Other'), 'owner');
        $this->app['auth']->forgetGuards();
        $this->withToken($other->createToken('t')->plainTextToken)->getJson('/api/v1/me')->assertOk();
    }

    public function test_logout_revokes_the_token_and_other_devices_keep_theirs(): void
    {
        $owner = $this->makeUser($this->makeStore(), 'owner');
        $phone = $owner->createToken('phone')->plainTextToken;
        $web = $owner->createToken('web')->plainTextToken;

        $this->withToken($phone)->postJson('/api/v1/logout')->assertOk();
        $this->app['auth']->forgetGuards();

        $this->withToken($phone)->getJson('/api/v1/me')->assertUnauthorized();
        $this->app['auth']->forgetGuards();
        $this->withToken($web)->getJson('/api/v1/me')->assertOk();
    }

    public function test_registration_ignores_privileged_fields(): void
    {
        $other = $this->makeStore('Someone else');

        $response = $this->postJson('/api/v1/register', [
            'store_name' => 'متجر جديد',
            'owner_name' => 'Owner',
            'owner_phone' => '0599111222',
            'password' => 'secret-pass-1',
            'password_confirmation' => 'secret-pass-1',
            // Hostile extras: none may stick.
            'store_id' => $other->id,
            'role' => 'manager',
            'is_platform_admin' => true,
            'status' => 'active',
            'subscription_status' => 'active',
            'subscription_expires_at' => '2099-01-01',
        ])->assertCreated();

        $user = User::findOrFail($response->json('user.id'));
        $this->assertNotSame($other->id, $user->store_id);
        $this->assertSame('owner', $user->role->value ?? $user->role);
        $this->assertFalse((bool) $user->is_platform_admin);
        $this->assertNotSame('active', $user->store->subscription_status);
        $this->assertTrue(Hash::check('secret-pass-1', $user->password));
        $this->assertNotSame('secret-pass-1', $user->getAttributes()['password'], 'passwords are stored hashed');
        $this->assertArrayNotHasKey('password', $response->json('user'));
    }

    public function test_hostile_text_is_stored_as_data_and_returned_as_json(): void
    {
        $owner = $this->makeUser($this->makeStore(), 'owner');
        $payload = "<script>alert(1)</script>'; DROP TABLE customers; --";

        $id = $this->actingAs($owner, 'sanctum')
            ->postJson('/api/v1/customers', ['name' => $payload, 'phone' => '0599123456'])
            ->assertCreated()
            ->json('customer.id');
        $this->assertNotNull($id);

        $this->actingAs($owner, 'sanctum')
            ->getJson("/api/v1/customers/{$id}")
            ->assertOk()
            ->assertHeader('Content-Type', 'application/json')
            ->assertJsonPath('data.name', $payload);

        // The same text as a search term is a value, not SQL.
        $this->actingAs($owner, 'sanctum')
            ->getJson('/api/v1/customers?search=' . urlencode("' OR 1=1 --"))
            ->assertOk()
            ->assertJsonCount(0, 'data');
        $this->actingAs($owner, 'sanctum')
            ->getJson('/api/v1/products?search=' . urlencode("%' UNION SELECT password FROM users --"))
            ->assertOk();
        $this->assertDatabaseCount('customers', 1);
    }

    public function test_oversized_and_wrong_type_input_is_refused(): void
    {
        $owner = $this->makeUser($this->makeStore(), 'owner');

        $this->actingAs($owner, 'sanctum')
            ->postJson('/api/v1/customers', ['name' => str_repeat('a', 5000), 'phone' => '0599123456'])
            ->assertUnprocessable();
        $this->actingAs($owner, 'sanctum')
            ->postJson('/api/v1/customers', ['name' => ['nested' => 'array'], 'phone' => '0599123456'])
            ->assertUnprocessable();
        $this->actingAs($owner, 'sanctum')
            ->getJson('/api/v1/customers?per_page=100000')
            ->assertUnprocessable();
    }

    public function test_deleting_a_store_also_removes_its_members_pending_sms_codes(): void
    {
        $adminStore = $this->makeStore('Platform');
        $admin = $this->makeUser($adminStore, 'owner');
        $admin->forceFill(['is_platform_admin' => true])->save();

        $store = $this->makeStore('Shop');
        $owner = $this->makeUser($store, 'owner');
        $stranger = $this->makeUser($this->makeStore('Stranger'), 'owner');

        foreach ([$owner->phone, $stranger->phone] as $phone) {
            PhoneOtp::create([
                'phone' => $phone,
                'purpose' => PhoneOtp::PURPOSE_RESET,
                'code_hash' => Hash::make('123456'),
                'expires_at' => now()->addMinutes(10),
            ]);
        }

        $this->actingAs($admin, 'sanctum')
            ->deleteJson("/api/v1/admin/stores/{$store->id}", ['confirm_name' => 'Shop'])
            ->assertOk();

        $this->assertDatabaseMissing('users', ['id' => $owner->id]);
        $this->assertSame(0, PhoneOtp::where('phone', $owner->phone)->count());
        $this->assertSame(1, PhoneOtp::where('phone', $stranger->phone)->count(), 'other accounts keep theirs');
    }
}
