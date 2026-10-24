<?php

namespace App\Services;

use App\Enums\UserRole;
use App\Exceptions\ApiException;
use App\Models\Store;
use App\Models\StoreInvitation;
use App\Models\User;
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
     * Stateless credential check (no session), throttled per email + IP
     * on failed attempts only (US-0104), and refused for inactive staff (US-0105).
     */
    public function login(string $email, string $password, string $ip): User
    {
        $key = 'login:' . sha1(Str::lower($email) . '|' . $ip);

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

        $user = User::where('email', $email)->first();

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

    public function registerStore(array $data): User
    {
        return DB::transaction(function () use ($data) {
            $store = Store::create([
                'name' => $data['store_name'],
                'phone' => $data['phone'] ?? null,
                'address' => $data['address'] ?? null,
                'timezone' => $data['timezone'] ?? Store::DEFAULT_TIMEZONE,
            ]);

            $owner = new User([
                'name' => $data['owner_name'],
                'email' => $data['email'],
                'phone' => $data['owner_phone'] ?? null,
                'password' => $data['password'] ?? null,
            ]);
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

            if ($invitation->email && !hash_equals(strtolower($invitation->email), strtolower($data['email']))) {
                throw ValidationException::withMessages([
                    'email' => 'البريد الإلكتروني لا يطابق الدعوة.',
                ]);
            }

            $user = new User([
                'name' => $data['name'],
                'email' => $data['email'],
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
