<?php

namespace Tests\Feature;

use App\Models\User;
use App\Services\GoogleIdTokenVerifier;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
use Tests\Support\BuildsShopData;
use Tests\TestCase;

/**
 * Google sign-in (web SSO) and the onboarding that creates the store for a new Google user.
 * Google's tokeninfo endpoint is faked; the claims mirror a real ID token.
 */
class GoogleSignInTest extends TestCase
{
    use BuildsShopData;
    use RefreshDatabase;

    private const CLIENT_ID = 'test-client.apps.googleusercontent.com';

    protected function setUp(): void
    {
        parent::setUp();
        config(['services.google.client_id' => self::CLIENT_ID]);
    }

    private function fakeGoogle(array $claims = [], int $status = 200): void
    {
        Http::fake([
            GoogleIdTokenVerifier::TOKENINFO_URL . '*' => Http::response([
                'iss' => 'https://accounts.google.com',
                'aud' => self::CLIENT_ID,
                'sub' => '1098765432101234567890',
                'email' => 'Owner@Example.com',
                'email_verified' => 'true',
                'name' => 'علي أحمد',
                'exp' => (string) now()->addHour()->getTimestamp(),
                ...$claims,
            ], $status),
        ]);
    }

    private function startOnboarding(): string
    {
        return $this->postJson('/api/v1/auth/google', ['credential' => 'id-token'])
            ->assertOk()
            ->assertJsonMissingPath('token')
            ->assertJsonPath('onboarding.email', 'owner@example.com')
            ->assertJsonPath('onboarding.name', 'علي أحمد')
            ->json('onboarding.token');
    }

    public function test_a_new_google_user_onboards_and_gets_a_store(): void
    {
        $this->fakeGoogle();
        $onboarding = $this->startOnboarding();
        $this->assertDatabaseCount('users', 0);

        $this->postJson('/api/v1/register/google', [
            'onboarding_token' => $onboarding,
            'store_name' => 'بقالة النور',
            'phone' => '0599000000',
            'owner_name' => 'علي أحمد',
            'owner_phone' => '0599111111',
        ])
            ->assertCreated()
            ->assertJsonPath('user.email', 'owner@example.com')
            ->assertJsonPath('user.role', 'owner')
            ->assertJsonPath('user.phone', '0599111111')
            ->assertJsonPath('user.store.name', 'بقالة النور')
            ->assertJsonMissingPath('user.google_id')
            ->assertJsonStructure(['token']);

        $owner = User::firstWhere('email', 'owner@example.com');
        $this->assertSame('1098765432101234567890', $owner->google_id);
        $this->assertNull($owner->password);

        // A Google-only account cannot be opened with a password.
        $this->postJson('/api/v1/login', ['email' => 'owner@example.com', 'password' => ''])->assertUnprocessable();
        $this->postJson('/api/v1/login', ['email' => 'owner@example.com', 'password' => 'anything'])
            ->assertUnauthorized()
            ->assertJsonPath('code', 'INVALID_CREDENTIALS');

        // Next time Google signs straight in.
        $this->postJson('/api/v1/auth/google', ['credential' => 'id-token'])
            ->assertOk()
            ->assertJsonPath('user.id', $owner->id)
            ->assertJsonStructure(['token']);
    }

    public function test_an_existing_email_account_is_linked_on_first_google_sign_in(): void
    {
        $user = $this->makeUser($this->makeStore(), 'manager', ['email' => 'owner@example.com']);
        $this->fakeGoogle();

        $this->postJson('/api/v1/auth/google', ['credential' => 'id-token'])
            ->assertOk()
            ->assertJsonPath('user.id', $user->id)
            ->assertJsonStructure(['token']);

        $this->assertSame('1098765432101234567890', $user->fresh()->google_id);
        // The password still works.
        $this->postJson('/api/v1/login', ['email' => 'owner@example.com', 'password' => 'password'])->assertOk();
    }

    public function test_a_deactivated_user_gets_no_token(): void
    {
        $this->makeUser($this->makeStore(), 'employee', ['email' => 'owner@example.com', 'status' => User::STATUS_INACTIVE]);
        $this->fakeGoogle();

        $this->postJson('/api/v1/auth/google', ['credential' => 'id-token'])
            ->assertForbidden()
            ->assertJsonPath('code', 'USER_INACTIVE');
    }

    public function test_tokens_for_another_client_unverified_or_rejected_are_refused(): void
    {
        foreach ([
            ['aud' => 'someone-else.apps.googleusercontent.com'],
            ['email_verified' => 'false'],
            ['iss' => 'https://evil.example.com'],
            ['exp' => (string) now()->subMinute()->getTimestamp()],
        ] as $claims) {
            $this->fakeGoogle($claims);
            $this->postJson('/api/v1/auth/google', ['credential' => 'id-token'])
                ->assertUnauthorized()
                ->assertJsonPath('code', 'GOOGLE_TOKEN_INVALID');
        }

        $this->fakeGoogle(['error_description' => 'Invalid Value'], 400);
        $this->postJson('/api/v1/auth/google', ['credential' => 'id-token'])
            ->assertUnauthorized()
            ->assertJsonPath('code', 'GOOGLE_TOKEN_INVALID');

        $this->assertDatabaseCount('users', 0);
    }

    public function test_sign_in_is_unavailable_without_a_client_id(): void
    {
        config(['services.google.client_id' => null]);
        Http::fake();

        $this->postJson('/api/v1/auth/google', ['credential' => 'id-token'])
            ->assertStatus(503)
            ->assertJsonPath('code', 'SSO_UNAVAILABLE');
        Http::assertNothingSent();
    }

    public function test_onboarding_rejects_a_forged_expired_or_reused_token(): void
    {
        $form = ['store_name' => 'بقالة النور', 'owner_name' => 'علي أحمد'];

        $this->postJson('/api/v1/register/google', ['onboarding_token' => 'forged'] + $form)
            ->assertUnprocessable()
            ->assertJsonValidationErrors('onboarding_token');

        $this->fakeGoogle();
        $onboarding = $this->startOnboarding();

        $this->travel(31)->minutes();
        $this->postJson('/api/v1/register/google', ['onboarding_token' => $onboarding] + $form)
            ->assertUnprocessable()
            ->assertJsonValidationErrors('onboarding_token');
        $this->travelBack();

        $onboarding = $this->startOnboarding();
        $this->postJson('/api/v1/register/google', ['onboarding_token' => $onboarding] + $form)->assertCreated();
        $this->postJson('/api/v1/register/google', ['onboarding_token' => $onboarding] + $form)
            ->assertUnprocessable()
            ->assertJsonValidationErrors('email');

        $this->assertDatabaseCount('stores', 1);
    }

    public function test_email_registration_keeps_the_owner_phone(): void
    {
        $this->postJson('/api/v1/register', [
            'store_name' => 'بقالة النور',
            'owner_name' => 'علي أحمد',
            'owner_phone' => '0599111111',
            'email' => 'owner@example.com',
            'password' => 'password123',
            'password_confirmation' => 'password123',
        ])
            ->assertCreated()
            ->assertJsonPath('user.phone', '0599111111');
    }
}
