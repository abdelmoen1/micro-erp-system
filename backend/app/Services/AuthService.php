<?php

namespace App\Services;

use App\Enums\UserRole;
use App\Exceptions\ApiException;
use App\Models\PhoneOtp;
use App\Models\Store;
use App\Models\StoreInvitation;
use App\Models\TrialClaim;
use App\Support\SubscriptionAccess;
use App\Models\User;
use App\Support\PhoneNumber;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

class AuthService
{
    public const MAX_LOGIN_ATTEMPTS = 5;

    public const LOGIN_DECAY_SECONDS = 60;

    /** Failed sign-ins per number per hour from any address: caps slow password guessing. */
    public const MAX_LOGIN_ATTEMPTS_PER_HOUR = 20;

    /**
     * Stateless credential check (no session), throttled on failed attempts only: 5 a minute per
     * login + IP (US-0104) and 20 an hour per login from any IP. Refused for inactive staff (US-0105).
     * [$login] is the mobile number.
     */
    public function login(string $login, string $password, string $ip): User
    {
        $user = $this->verifyCredentials($login, $password, $ip);

        if (!$user->isActive()) {
            throw new ApiException(403, 'USER_INACTIVE', 'تم إيقاف هذا الحساب. تواصل مع صاحب المتجر.');
        }

        $this->ensureStoreOpen($user);

        return $user;
    }

    /**
     * The number + password check with the sign-in throttles, and nothing else: also used by the
     * public account-deletion form, where a deactivated staff member must still be able to ask.
     */
    public function verifyCredentials(string $login, string $password, string $ip): User
    {
        $phone = PhoneNumber::normalize($login);
        $identity = $phone ?? Str::lower(trim($login));
        $key = 'login:' . sha1($identity . '|' . $ip);
        $hourKey = 'login-hour:' . sha1($identity);

        foreach ([$key => self::MAX_LOGIN_ATTEMPTS, $hourKey => self::MAX_LOGIN_ATTEMPTS_PER_HOUR] as $limiter => $max) {
            if (RateLimiter::tooManyAttempts($limiter, $max)) {
                $seconds = RateLimiter::availableIn($limiter);

                throw new ApiException(
                    429,
                    'TOO_MANY_REQUESTS',
                    "محاولات دخول كثيرة. حاول مجدداً بعد {$seconds} ثانية.",
                    ['retry_after' => [$seconds]],
                    ['Retry-After' => (string) $seconds],
                );
            }
        }

        $user = $phone !== null ? User::where('phone', $phone)->first() : null;

        // An unknown number costs the same hash check as a known one: the response time does not
        // tell who has an account.
        $valid = Hash::check($password, $user?->password ?? self::dummyHash());

        if (!$user || !$user->password || !$valid) {
            RateLimiter::hit($key, self::LOGIN_DECAY_SECONDS);
            RateLimiter::hit($hourKey, 3600);

            throw new ApiException(401, 'INVALID_CREDENTIALS', 'البيانات المدخلة غير صحيحة');
        }

        RateLimiter::clear($key);
        RateLimiter::clear($hourKey);

        return $user;
    }

    /** A hash of a random value, made once per process with the configured cost. */
    private static function dummyHash(): string
    {
        static $hash = null;

        return $hash ??= Hash::make(Str::random(32));
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
        // A store the owner asked to delete: only the owner signs in (to cancel before the date).
        if ($user->store?->isClosing() && !$user->hasRole(UserRole::OWNER)) {
            throw self::storeClosing($user->store);
        }
    }

    public static function storeClosing(Store $store): ApiException
    {
        return new ApiException(403, 'STORE_CLOSING', 'طلب صاحب المتجر حذف هذا المتجر.', details: [
            'deletion_scheduled_for' => $store->deletion_scheduled_for?->toIso8601String(),
        ]);
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
            // One free trial per owner number, ever: a number that already had one (even for a
            // store since deleted) starts without a trial. Only an HMAC of the number is kept.
            $phone = PhoneNumber::normalize((string) ($data['owner_phone'] ?? ''));
            $claim = $phone ? TrialClaim::where('phone_hash', TrialClaim::hashPhone($phone))->lockForUpdate()->first() : null;

            $store = new Store([
                'name' => $data['store_name'],
                'phone' => $data['phone'] ?? null,
                'address' => $data['address'] ?? null,
                'area' => $data['area'] ?? null,
                'latitude' => $data['latitude'] ?? null,
                'longitude' => $data['longitude'] ?? null,
                'timezone' => $data['timezone'] ?? Store::DEFAULT_TIMEZONE,
            ]);
            if ($claim) {
                $store->trial_started_at = now();
                $store->trial_ends_at = now();
            }
            $store->save();

            if ($phone && !$claim) {
                TrialClaim::create([
                    'phone_hash' => TrialClaim::hashPhone($phone),
                    'store_id' => $store->id,
                    'started_at' => $store->trial_started_at,
                    'ends_at' => $store->trial_ends_at,
                ]);
            }

            $owner = new User([
                'name' => $data['owner_name'],
                'phone' => $data['owner_phone'] ?? null,
                'password' => $data['password'] ?? null,
            ]);
            $owner->phone_verified_at = ($data['phone_verified'] ?? false) ? now() : null;
            $owner->store_id = $store->id;
            $owner->role = UserRole::OWNER;
            $owner->save();

            return $owner->load('store');
        });
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

    /** Plan limit `max_employees`: active staff (not the owner) the store may have. */
    public static function ensureStaffRoom(Store $store): void
    {
        $max = $store->limit('max_employees');
        if ($max === null) {
            return;
        }
        $staff = $store->users()->where('role', '<>', UserRole::OWNER->value)->where('status', User::STATUS_ACTIVE)->count();
        if ($staff >= $max) {
            throw SubscriptionAccess::limitReached('max_employees', $max);
        }
    }

    public function createInvitation(User $inviter, array $data): array
    {
        self::ensureStaffRoom($inviter->store);
        $token = Str::random(64);
        $invitation = StoreInvitation::create([
            'store_id' => $inviter->store_id,
            'invited_by' => $inviter->id,
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

            $store = Store::query()->lockForUpdate()->findOrFail($invitation->store_id);
            if ($store->isSuspended()) {
                throw self::storeSuspended();
            }
            if ($store->isClosing()) {
                throw self::storeClosing($store);
            }
            self::ensureStaffRoom($store);

            $user = new User([
                'name' => $data['name'],
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
