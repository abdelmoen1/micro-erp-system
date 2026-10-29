<?php

namespace App\Services;

use App\Enums\UserRole;
use App\Exceptions\ApiException;
use App\Models\PhoneOtp;
use App\Models\Store;
use App\Models\StoreInvitation;
use App\Models\User;
use App\Support\PhoneNumber;
use Illuminate\Contracts\Encryption\DecryptException;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

class AuthService
{
    public const MAX_LOGIN_ATTEMPTS = 5;

    public const LOGIN_DECAY_SECONDS = 60;

    /** How long a new Google user has to finish onboarding before signing in again. */
    public const ONBOARDING_MINUTES = 30;

    /**
     * Stateless credential check (no session), throttled per login + IP on failed attempts only
     * (US-0104), and refused for inactive staff (US-0105). [$login] is the mobile number; accounts
     * made with an e-mail before sign-in by phone may still give their e-mail.
     */
    public function login(string $login, string $password, string $ip): User
    {
        $phone = str_contains($login, '@') ? null : PhoneNumber::normalize($login);
        $key = 'login:' . sha1(Str::lower($phone ?? trim($login)) . '|' . $ip);

        if (RateLimiter::tooManyAttempts($key, self::MAX_LOGIN_ATTEMPTS)) {
            $seconds = RateLimiter::availableIn($key);

            throw new ApiException(
                429,
                'TOO_MANY_REQUESTS',
                "محاولات دخول كثيرة. حاول مجدداً بعد {$seconds} ثانية.",
                ['retry_after' => [$seconds]],
                ['Retry-After' => (string) $seconds],
            );
        }

        $user = $phone !== null
            ? User::where('phone', $phone)->first()
            : (str_contains($login, '@') ? User::where('email', trim($login))->first() : null);

        if (!$user || !Hash::check($password, $user->password)) {
            RateLimiter::hit($key, self::LOGIN_DECAY_SECONDS);

            throw new ApiException(401, 'INVALID_CREDENTIALS', 'البيانات المدخلة غير صحيحة');
        }

        RateLimiter::clear($key);

        if (!$user->isActive()) {
            throw new ApiException(403, 'USER_INACTIVE', 'تم إيقاف هذا الحساب. تواصل مع صاحب المتجر.');
        }

        $this->ensureStoreOpen($user);

        return $user;
    }

    /** 403 for every member of a store the platform admin suspended. */
    public static function storeSuspended(): ApiException
    {
        return new ApiException(403, 'STORE_SUSPENDED', 'تم إيقاف حساب هذا المتجر. تواصل مع إدارة حسبة.');
    }

    /**
     * Members of a suspended store cannot sign in. The platform admin still can, so the admin pages
     * stay reachable to reactivate it; their own store routes are closed like everyone else's.
     */
    private function ensureStoreOpen(User $user): void
    {
        if ($user->store?->isSuspended() && !$user->isPlatformAdmin()) {
            throw self::storeSuspended();
        }
    }

    /** Sanctum token that expires with sanctum.expiration (30 days by default). */
    public function issueToken(User $user): string
    {
        $minutes = (int) config('sanctum.expiration');

        return $user->createToken(
            'api-token',
            ['*'],
            $minutes > 0 ? now()->addMinutes($minutes) : null,
        )->plainTextToken;
    }

    /** [$data]['phone_verified'] is set when the owner's number was confirmed by an SMS code. */
    public function registerStore(array $data): User
    {
        return DB::transaction(function () use ($data) {
            $store = Store::create([
                'name' => $data['store_name'],
                'phone' => $data['phone'] ?? null,
                'address' => $data['address'] ?? null,
                'area' => $data['area'] ?? null,
                'latitude' => $data['latitude'] ?? null,
                'longitude' => $data['longitude'] ?? null,
                'timezone' => $data['timezone'] ?? Store::DEFAULT_TIMEZONE,
            ]);

            $owner = new User([
                'name' => $data['owner_name'],
                'email' => $data['email'] ?? null,
                'phone' => $data['owner_phone'] ?? null,
                'password' => $data['password'] ?? null,
            ]);
            $owner->phone_verified_at = ($data['phone_verified'] ?? false) ? now() : null;
            $owner->store_id = $store->id;
            $owner->role = UserRole::OWNER;
            $owner->google_id = $data['google_id'] ?? null;
            $owner->save();

            return $owner->load('store');
        });
    }

    /**
     * The account for a verified Google profile: by Google id, else by email (Google verified it,
     * so the account is linked on first use). Null means a new user who must onboard first.
     */
    public function findGoogleUser(array $profile): ?User
    {
        $user = User::where('google_id', $profile['sub'])->first()
            ?? User::where('email', $profile['email'])->first();

        if (!$user) {
            return null;
        }

        if (!$user->isActive()) {
            throw new ApiException(403, 'USER_INACTIVE', 'تم إيقاف هذا الحساب. تواصل مع صاحب المتجر.');
        }

        $this->ensureStoreOpen($user);

        if ($user->google_id === null) {
            $user->forceFill(['google_id' => $profile['sub']])->save();
        }

        return $user;
    }

    /** A sealed, short-lived copy of the Google profile that POST /register/google trusts. */
    public function onboardingToken(array $profile): string
    {
        return Crypt::encryptString(json_encode([
            'sub' => $profile['sub'],
            'email' => $profile['email'],
            'name' => $profile['name'],
            'exp' => now()->addMinutes(self::ONBOARDING_MINUTES)->getTimestamp(),
        ]));
    }

    public function registerStoreWithGoogle(array $data): User
    {
        try {
            $profile = json_decode(Crypt::decryptString($data['onboarding_token']), true);
        } catch (DecryptException) {
            $profile = null;
        }

        if (!is_array($profile) || ($profile['exp'] ?? 0) <= now()->getTimestamp()) {
            throw ValidationException::withMessages([
                'onboarding_token' => 'انتهت مهلة التسجيل. تابع بحساب Google مرة أخرى.',
            ]);
        }

        if (User::where('google_id', $profile['sub'])->orWhere('email', $profile['email'])->exists()) {
            throw ValidationException::withMessages([
                'email' => 'هذا البريد مسجّل مسبقاً. سجّل الدخول بحساب Google.',
            ]);
        }

        return $this->registerStore([
            ...$data,
            'email' => $profile['email'],
            'google_id' => $profile['sub'],
        ]);
    }

    /**
     * A forgotten password: the SMS code proves the number, the new password is set, and every
     * device is signed out. An unknown number gets the same refusal as a wrong code.
     */
    public function resetPassword(OtpService $otp, string $phone, string $code, string $password, AuditService $audit): void
    {
        $otp->verify($phone, PhoneOtp::PURPOSE_RESET, $code);
        $user = User::where('phone', $phone)->first();

        if (!$user) {
            throw ValidationException::withMessages(['otp_code' => ['الرمز غير صحيح.']]);
        }

        DB::transaction(function () use ($user, $password, $audit) {
            $user->forceFill(['password' => $password, 'phone_verified_at' => $user->phone_verified_at ?? now()])->save();
            $user->tokens()->delete();
            $audit->record('user.password_reset', $user, ['by' => 'sms_code'], $user);
        });
    }

    /** The number this account signs in with; [$code] is checked when SMS codes are on. */
    public function changePhone(OtpService $otp, User $user, string $phone, ?string $code, AuditService $audit): User
    {
        if ($otp->enabled()) {
            $otp->verify($phone, PhoneOtp::PURPOSE_CHANGE_PHONE, $code);
        }

        DB::transaction(function () use ($otp, $user, $phone, $audit) {
            $before = $user->phone;
            $user->forceFill(['phone' => $phone, 'phone_verified_at' => $otp->enabled() ? now() : null])->save();
            $audit->record('user.phone_changed', $user, [
                'from' => $before ? PhoneNumber::masked($before) : null,
                'to' => PhoneNumber::masked($phone),
            ], $user);
        });

        return $user->load('store');
    }

    public function createInvitation(User $inviter, array $data): array
    {
        $token = Str::random(64);
        $invitation = StoreInvitation::create([
            'store_id' => $inviter->store_id,
            'invited_by' => $inviter->id,
            'email' => $data['email'] ?? null,
            'role' => $data['role'],
            'token_hash' => hash('sha256', $token),
            'expires_at' => now()->addHours($data['expires_in_hours'] ?? 72),
        ]);

        return [$invitation, $token];
    }

    public function acceptInvitation(array $data): User
    {
        return DB::transaction(function () use ($data) {
            $invitation = StoreInvitation::where('token_hash', hash('sha256', $data['token']))
                ->lockForUpdate()
                ->first();

            if (!$invitation || $invitation->accepted_at || $invitation->expires_at->isPast()) {
                throw ValidationException::withMessages([
                    'token' => 'الدعوة غير صالحة أو منتهية.',
                ]);
            }

            if ($invitation->store()->value('status') === Store::STATUS_SUSPENDED) {
                throw self::storeSuspended();
            }

            // An invitation made for an e-mail is kept for it when the new member gives an e-mail.
            if ($invitation->email && !empty($data['email']) && !hash_equals(strtolower($invitation->email), strtolower($data['email']))) {
                throw ValidationException::withMessages([
                    'email' => 'البريد الإلكتروني لا يطابق الدعوة.',
                ]);
            }

            $user = new User([
                'name' => $data['name'],
                'email' => $data['email'] ?? null,
                'phone' => $data['phone'],
                'password' => $data['password'],
            ]);
            $user->store_id = $invitation->store_id;
            $user->role = $invitation->role;
            $user->save();

            $invitation->forceFill(['accepted_at' => now()])->save();

            return $user->load('store');
        });
    }
}
