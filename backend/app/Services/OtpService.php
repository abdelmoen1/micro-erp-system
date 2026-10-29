<?php

namespace App\Services;

use App\Exceptions\ApiException;
use App\Models\PhoneOtp;
use App\Services\Sms\SmsSender;
use App\Support\PhoneNumber;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\ValidationException;
use Throwable;

/**
 * One-time SMS codes for sign-up, a forgotten password and a changed number. A code is 6 digits,
 * stored hashed, valid 10 minutes and for 5 tries, and works once. Sending is limited per number,
 * per IP and per day (the free textbee plan sends 50 a day). Without a configured gateway the
 * service is off and sign-up works without a code.
 */
class OtpService
{
    public const TTL_MINUTES = 10;

    public const MAX_ATTEMPTS = 5;

    public const RESEND_SECONDS = 60;

    public const PER_PHONE_PER_HOUR = 5;

    public const PER_IP_PER_HOUR = 10;

    public function __construct(private readonly ?SmsSender $sms) {}

    public function enabled(): bool
    {
        return $this->sms !== null;
    }

    /** Sends a new code to [$phone] (local form) and voids the earlier ones for the same purpose. */
    public function send(string $phone, string $purpose, ?string $ip): void
    {
        if (!$this->enabled()) {
            throw new ApiException(503, 'OTP_UNAVAILABLE', 'رسائل رمز التحقق غير مفعّلة حالياً.');
        }

        $last = PhoneOtp::query()->where('phone', $phone)->where('purpose', $purpose)->latest('id')->first();
        if ($last && $last->created_at->gt(now()->subSeconds(self::RESEND_SECONDS))) {
            $this->tooMany(self::RESEND_SECONDS - (int) $last->created_at->diffInSeconds(now(), true));
        }

        $hour = now()->subHour();
        if (PhoneOtp::query()->where('phone', $phone)->where('created_at', '>', $hour)->count() >= self::PER_PHONE_PER_HOUR
            || ($ip && PhoneOtp::query()->where('ip', $ip)->where('created_at', '>', $hour)->count() >= self::PER_IP_PER_HOUR)) {
            $this->tooMany(3600);
        }

        if (PhoneOtp::query()->where('created_at', '>', now()->startOfDay())->count() >= (int) config('services.sms.daily_limit')) {
            throw new ApiException(503, 'OTP_DAILY_LIMIT', 'وصلنا إلى حدّ رسائل التحقق لليوم. حاول غداً أو تواصل مع الدعم.');
        }

        $code = (string) random_int(100000, 999999);

        PhoneOtp::query()->where('phone', $phone)->where('purpose', $purpose)->whereNull('consumed_at')->update(['consumed_at' => now()]);
        $otp = PhoneOtp::create([
            'phone' => $phone,
            'purpose' => $purpose,
            'code_hash' => Hash::make($code),
            'expires_at' => now()->addMinutes(self::TTL_MINUTES),
            'ip' => $ip,
        ]);

        try {
            $this->sms->send(PhoneNumber::international($phone), "رمز حسبة: {$code}\nصالح " . self::TTL_MINUTES . ' دقائق. لا تعطه لأحد.');
        } catch (Throwable $e) {
            $otp->delete();
            report($e);

            throw new ApiException(503, 'OTP_SEND_FAILED', 'تعذّر إرسال الرسالة الآن. حاول بعد قليل.');
        }
    }

    /** Checks and uses up the code; a wrong code counts a try. Errors are on `otp_code`. */
    public function verify(string $phone, string $purpose, ?string $code): void
    {
        $otp = PhoneOtp::query()
            ->where('phone', $phone)
            ->where('purpose', $purpose)
            ->whereNull('consumed_at')
            ->latest('id')
            ->first();

        if (!$otp || $otp->expires_at->isPast() || $otp->attempts >= self::MAX_ATTEMPTS) {
            throw ValidationException::withMessages(['otp_code' => ['انتهت صلاحية الرمز. اطلب رمزاً جديداً.']]);
        }

        if (!Hash::check((string) $code, $otp->code_hash)) {
            $otp->increment('attempts');

            throw ValidationException::withMessages(['otp_code' => ['الرمز غير صحيح.']]);
        }

        $otp->forceFill(['consumed_at' => now()])->save();
    }

    private function tooMany(int $seconds): never
    {
        $seconds = max(1, $seconds);

        throw new ApiException(
            429,
            'TOO_MANY_REQUESTS',
            "طلبت رموزاً كثيرة. حاول بعد {$seconds} ثانية.",
            ['retry_after' => [$seconds]],
            ['Retry-After' => (string) $seconds],
        );
    }
}
