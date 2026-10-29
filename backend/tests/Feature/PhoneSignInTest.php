<?php

namespace Tests\Feature;

use App\Models\PhoneOtp;
use App\Models\StoreInvitation;
use App\Models\User;
use App\Services\Sms\SmsSender;
use App\Support\PhoneNumber;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\Str;
use RuntimeException;
use Tests\Support\BuildsShopData;
use Tests\TestCase;

/**
 * Sign-in by mobile number: sign-up and login by phone, older e-mail accounts, one-time SMS codes
 * (sign-up, forgotten password, new number) with their limits, and the textbee gateway.
 */
class PhoneSignInTest extends TestCase
{
    use BuildsShopData;
    use RefreshDatabase;

    private FakeSms $sms;

    protected function setUp(): void
    {
        parent::setUp();
        RateLimiter::clear('otp');
    }

    /** SMS codes on, with every message kept for the test to read. */
    private function smsOn(): FakeSms
    {
        $this->sms = new FakeSms();
        $this->app->instance(SmsSender::class, $this->sms);

        return $this->sms;
    }

    private function signUp(array $overrides = []): \Illuminate\Testing\TestResponse
    {
        return $this->postJson('/api/v1/register', $overrides + [
            'store_name' => 'بقالة الأمانة',
            'owner_name' => 'علي أحمد',
            'owner_phone' => '059 912 3456',
            'password' => 'Secret-pass-2026',
            'password_confirmation' => 'Secret-pass-2026',
        ]);
    }

    public function test_numbers_are_kept_in_one_local_form(): void
    {
        foreach (['0599123456', '059 912 3456', '059-912-3456', '+970599123456', '00970599123456', '970599123456', '٠٥٩٩١٢٣٤٥٦'] as $input) {
            $this->assertSame('0599123456', PhoneNumber::normalize($input), $input);
        }
        $this->assertSame('0521234567', PhoneNumber::normalize('+972 52 123 4567'));
        foreach (['599123456', '0699123456', '05991234', 'abc', '', null] as $bad) {
            $this->assertNull(PhoneNumber::normalize($bad));
        }
        $this->assertSame('+970599123456', PhoneNumber::international('0599123456'));
        $this->assertSame('+970569123456', PhoneNumber::international('0569123456'));
        $this->assertSame('+972521234567', PhoneNumber::international('0521234567'));
    }

    public function test_an_owner_signs_up_and_in_with_the_phone_and_no_email(): void
    {
        $this->getJson('/api/v1/auth/options')->assertOk()->assertJsonPath('data.otp', false)->assertJsonPath('data.login', 'phone');

        $this->signUp()->assertCreated()->assertJsonPath('user.phone', '0599123456')->assertJsonMissingPath('user.email');
        $this->app['auth']->forgetGuards();

        foreach (['0599123456', '+970 599 123 456'] as $login) {
            $this->postJson('/api/v1/login', ['login' => $login, 'password' => 'Secret-pass-2026'])
                ->assertOk()->assertJsonStructure(['token'])->assertJsonPath('user.phone', '0599123456');
        }
        $this->postJson('/api/v1/login', ['login' => '0599123456', 'password' => 'wrong-pass'])
            ->assertUnauthorized()->assertJsonPath('code', 'INVALID_CREDENTIALS');
        $this->postJson('/api/v1/login', ['login' => '0599999999', 'password' => 'Secret-pass-2026'])
            ->assertUnauthorized()->assertJsonPath('code', 'INVALID_CREDENTIALS');
    }

    public function test_one_account_per_number_and_a_clear_message_for_a_bad_one(): void
    {
        $this->signUp()->assertCreated();
        $this->app['auth']->forgetGuards();

        $this->signUp(['owner_phone' => '+970599123456'])->assertUnprocessable()
            ->assertJsonPath('errors.owner_phone.0', 'هذا الرقم مسجّل لحساب آخر. سجّل الدخول به، أو استعمل «نسيت كلمة المرور».');
        $this->signUp(['owner_phone' => '12345'])->assertUnprocessable()
            ->assertJsonPath('errors.owner_phone.0', 'رقم الجوال غير صحيح. اكتبه هكذا: 0599123456');
        $this->signUp(['owner_phone' => null])->assertUnprocessable()->assertJsonValidationErrors('owner_phone');
    }

    public function test_an_email_never_signs_in(): void
    {
        $store = $this->makeStore();
        $this->makeUser($store, 'owner', ['email' => 'old@shop.ps', 'phone' => '0599123456']);

        $this->postJson('/api/v1/login', ['login' => 'old@shop.ps', 'password' => 'password'])
            ->assertUnauthorized()->assertJsonPath('code', 'INVALID_CREDENTIALS');
        $this->postJson('/api/v1/login', ['email' => 'old@shop.ps', 'password' => 'password'])
            ->assertUnprocessable()->assertJsonValidationErrors('login');
        $this->postJson('/api/v1/login', ['login' => '0599123456', 'password' => 'password'])
            ->assertOk()->assertJsonMissingPath('user.email');
    }

    public function test_with_codes_on_sign_up_needs_the_code_sent_to_the_number(): void
    {
        $sms = $this->smsOn();
        $this->getJson('/api/v1/auth/options')->assertJsonPath('data.otp', true);

        $this->signUp()->assertUnprocessable()->assertJsonPath('errors.otp_code.0', 'اكتب الرمز الذي وصلك برسالة.');

        $this->postJson('/api/v1/auth/otp', ['phone' => '0599123456', 'purpose' => 'register'])
            ->assertOk()->assertJsonPath('data.resend_in', 60);
        $this->assertSame('+970599123456', $sms->to());
        $code = $sms->code();

        $wrong = $code === '111111' ? '222222' : '111111';
        $this->signUp(['otp_code' => $wrong])->assertUnprocessable()->assertJsonPath('errors.otp_code.0', 'الرمز غير صحيح.');
        $this->assertSame(1, PhoneOtp::first()->attempts);

        $this->signUp(['otp_code' => $code])->assertCreated();
        $this->assertNotNull(User::where('phone', '0599123456')->value('phone_verified_at'));
        $this->assertNotNull(PhoneOtp::first()->consumed_at, 'a code works once');
        $this->assertStringNotContainsString($code, PhoneOtp::first()->code_hash, 'only the hash is stored');
    }

    public function test_a_code_expires_and_locks_after_five_wrong_tries(): void
    {
        $sms = $this->smsOn();
        $this->postJson('/api/v1/auth/otp', ['phone' => '0599123456', 'purpose' => 'register'])->assertOk();
        $code = $sms->code();
        $wrong = $code === '111111' ? '222222' : '111111';

        for ($i = 0; $i < 5; $i++) {
            $this->signUp(['otp_code' => $wrong])->assertUnprocessable();
        }
        // Past the sign-up limit of 5 a minute: the right code no longer works either.
        $this->travel(61)->seconds();
        $this->signUp(['otp_code' => $code])->assertUnprocessable()
            ->assertJsonPath('errors.otp_code.0', 'انتهت صلاحية الرمز. اطلب رمزاً جديداً.');

        $this->travel(61)->seconds();
        $this->postJson('/api/v1/auth/otp', ['phone' => '0599123456', 'purpose' => 'register'])->assertOk();
        $this->travel(11)->minutes();
        $this->signUp(['otp_code' => $sms->code()])->assertUnprocessable()
            ->assertJsonPath('errors.otp_code.0', 'انتهت صلاحية الرمز. اطلب رمزاً جديداً.');
    }

    public function test_sending_is_limited_per_number_and_per_day(): void
    {
        $this->smsOn();
        $this->postJson('/api/v1/auth/otp', ['phone' => '0599123456', 'purpose' => 'register'])->assertOk();
        $this->postJson('/api/v1/auth/otp', ['phone' => '0599123456', 'purpose' => 'register'])
            ->assertStatus(429)->assertJsonPath('code', 'TOO_MANY_REQUESTS')->assertHeader('Retry-After');

        config(['services.sms.daily_limit' => 1]);
        $this->travel(2)->minutes();
        RateLimiter::clear('otp');
        $this->postJson('/api/v1/auth/otp', ['phone' => '0599654321', 'purpose' => 'register'])
            ->assertStatus(503)->assertJsonPath('code', 'OTP_DAILY_LIMIT');
    }

    public function test_without_a_gateway_codes_are_off_and_say_so(): void
    {
        $this->postJson('/api/v1/auth/otp', ['phone' => '0599123456', 'purpose' => 'register'])
            ->assertStatus(503)->assertJsonPath('code', 'OTP_UNAVAILABLE');
        $this->postJson('/api/v1/auth/otp', ['phone' => '0599123456', 'purpose' => 'reset'])
            ->assertStatus(503)->assertJsonPath('code', 'OTP_UNAVAILABLE');
    }

    public function test_a_forgotten_password_is_reset_by_the_code_and_signs_out_everywhere(): void
    {
        $sms = $this->smsOn();
        $store = $this->makeStore();
        $owner = $this->makeUser($store, 'owner', ['phone' => '0599123456']);
        $owner->createToken('old-phone');

        $this->postJson('/api/v1/auth/otp', ['phone' => '0599 123 456', 'purpose' => 'reset'])->assertOk();
        $this->postJson('/api/v1/auth/password/reset', [
            'phone' => '0599123456',
            'otp_code' => $sms->code(),
            'password' => 'New-pass-2026',
            'password_confirmation' => 'New-pass-2026',
        ])->assertOk();

        $this->assertSame(0, $owner->tokens()->count());
        $this->postJson('/api/v1/login', ['login' => '0599123456', 'password' => 'New-pass-2026'])->assertOk();
        $this->assertDatabaseHas('audit_logs', ['action' => 'user.password_reset', 'user_id' => $owner->id]);
    }

    public function test_a_reset_for_an_unknown_number_answers_alike_and_sends_nothing(): void
    {
        $sms = $this->smsOn();

        $this->postJson('/api/v1/auth/otp', ['phone' => '0599777777', 'purpose' => 'reset'])->assertOk();
        $this->assertSame([], $sms->sent);
        $this->postJson('/api/v1/auth/password/reset', [
            'phone' => '0599777777', 'otp_code' => '123456', 'password' => 'New-pass-2026', 'password_confirmation' => 'New-pass-2026',
        ])->assertUnprocessable()->assertJsonValidationErrors('otp_code');
    }

    public function test_an_account_changes_its_phone_with_the_password(): void
    {
        $store = $this->makeStore();
        $owner = $this->makeUser($store, 'owner', ['email' => 'old@shop.ps']);
        $this->makeUser($store, 'employee', ['phone' => '0599222222']);

        $this->actingAs($owner, 'sanctum')->patchJson('/api/v1/me/phone', ['phone' => '0599111111', 'current_password' => 'wrong'])
            ->assertUnprocessable()->assertJsonPath('errors.current_password.0', 'كلمة المرور الحالية غير صحيحة.');
        $this->actingAs($owner, 'sanctum')->patchJson('/api/v1/me/phone', ['phone' => '0599222222', 'current_password' => 'password'])
            ->assertUnprocessable()->assertJsonValidationErrors('phone');
        $this->actingAs($owner, 'sanctum')->patchJson('/api/v1/me/phone', ['phone' => '059 911 1111', 'current_password' => 'password'])
            ->assertOk()->assertJsonPath('user.phone', '0599111111');

        $this->app['auth']->forgetGuards();
        $this->postJson('/api/v1/login', ['login' => '0599111111', 'password' => 'password'])->assertOk();
        $this->assertDatabaseHas('audit_logs', ['action' => 'user.phone_changed', 'user_id' => $owner->id]);
    }

    public function test_with_codes_on_a_new_number_is_confirmed_and_needs_a_signed_in_account(): void
    {
        $sms = $this->smsOn();
        $store = $this->makeStore();
        $owner = $this->makeUser($store, 'owner');

        $this->postJson('/api/v1/auth/otp', ['phone' => '0599111111', 'purpose' => 'change_phone'])->assertForbidden();

        $this->actingAs($owner, 'sanctum')->postJson('/api/v1/auth/otp', ['phone' => '0599111111', 'purpose' => 'change_phone'])->assertOk();
        $this->actingAs($owner, 'sanctum')->patchJson('/api/v1/me/phone', ['phone' => '0599111111', 'current_password' => 'password'])
            ->assertUnprocessable()->assertJsonValidationErrors('otp_code');
        $this->actingAs($owner, 'sanctum')->patchJson('/api/v1/me/phone', ['phone' => '0599111111', 'current_password' => 'password', 'otp_code' => $sms->code()])
            ->assertOk();
        $this->assertNotNull($owner->fresh()->phone_verified_at);
    }

    public function test_staff_join_an_invitation_with_their_phone(): void
    {
        $store = $this->makeStore();
        $owner = $this->makeUser($store, 'owner');
        StoreInvitation::create([
            'store_id' => $store->id, 'invited_by' => $owner->id, 'role' => 'employee',
            'token_hash' => hash('sha256', 'invite'), 'expires_at' => now()->addDay(),
        ]);

        $this->postJson('/api/v1/register/invitation', [
            'token' => 'invite', 'name' => 'سامر', 'phone' => '0569123456', 'password' => 'Secret-pass-2026', 'password_confirmation' => 'Secret-pass-2026',
        ])->assertCreated()->assertJsonPath('user.phone', '0569123456');

        $this->app['auth']->forgetGuards();
        $this->postJson('/api/v1/login', ['login' => '0569123456', 'password' => 'Secret-pass-2026'])->assertOk();
    }

    public function test_textbee_sends_from_the_configured_device_and_a_refusal_saves_nothing(): void
    {
        config(['services.sms.driver' => 'textbee', 'services.textbee.key' => 'test-key', 'services.textbee.device_id' => 'dev-1']);
        Http::fake(['api.textbee.dev/*' => Http::sequence()->push(['data' => ['success' => true]], 201)->push('down', 500)]);

        $this->postJson('/api/v1/auth/otp', ['phone' => '0599123456', 'purpose' => 'register'])->assertOk();
        Http::assertSent(fn($request) => $request->url() === 'https://api.textbee.dev/api/v1/gateway/send-sms'
            && $request->hasHeader('x-api-key', 'test-key')
            && $request['recipients'] === ['+970599123456']
            && $request['deviceId'] === 'dev-1'
            && Str::contains($request['message'], 'رمز حسبة'));

        $this->postJson('/api/v1/auth/otp', ['phone' => '0599654321', 'purpose' => 'register'])
            ->assertStatus(503)->assertJsonPath('code', 'OTP_SEND_FAILED');
        $this->assertSame(0, PhoneOtp::where('phone', '0599654321')->count());
    }
}

/** Keeps every message instead of sending it. */
class FakeSms implements SmsSender
{
    /** @var list<array{to: string, message: string}> */
    public array $sent = [];

    public function send(string $to, string $message): void
    {
        $this->sent[] = ['to' => $to, 'message' => $message];
    }

    public function to(): string
    {
        return end($this->sent)['to'] ?? throw new RuntimeException('nothing sent');
    }

    public function code(): string
    {
        preg_match('/\d{6}/', end($this->sent)['message'] ?? '', $m);

        return $m[0] ?? throw new RuntimeException('no code in the message');
    }
}
