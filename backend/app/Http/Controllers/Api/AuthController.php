<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\AcceptInvitationRequest;
use App\Http\Requests\ChangePasswordRequest;
use App\Http\Requests\ChangePhoneRequest;
use App\Http\Requests\RegisterStoreRequest;
use App\Http\Requests\ResetPasswordRequest;
use App\Http\Requests\SendOtpRequest;
use App\Models\PhoneOtp;
use App\Models\User;
use App\Services\AuditService;
use App\Services\AuthService;
use App\Services\OtpService;
use App\Support\PhoneNumber;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class AuthController extends Controller
{
    public function __construct(private readonly AuthService $authService) {}

    /** GET /auth/options: what the sign-in screens should offer (SMS codes on or off). */
    public function options(OtpService $otp)
    {
        return response()->json(['data' => ['login' => 'phone', 'otp' => $otp->enabled()]]);
    }

    /** POST /auth/otp: a one-time code by SMS for sign-up, a forgotten password or a new number. */
    public function sendOtp(SendOtpRequest $request, OtpService $otp)
    {
        $phone = $request->validated('phone');
        $purpose = $request->validated('purpose');

        // A reset is only sent to a number with an account; the answer is the same either way, so
        // the form never tells who is registered. Off, every purpose gets 503 OTP_UNAVAILABLE.
        if (!$otp->enabled() || $purpose !== PhoneOtp::PURPOSE_RESET || User::where('phone', $phone)->exists()) {
            $otp->send($phone, $purpose, $request->ip());
        }

        return response()->json([
            'message' => 'أرسلنا رمزاً من 6 أرقام إلى ' . PhoneNumber::masked($phone) . '.',
            'data' => ['expires_in' => OtpService::TTL_MINUTES * 60, 'resend_in' => OtpService::RESEND_SECONDS],
        ]);
    }

    /** POST /auth/password/reset: a new password by the SMS code; every device is signed out. */
    public function resetPassword(ResetPasswordRequest $request, OtpService $otp, AuditService $audit)
    {
        $data = $request->validated();
        $this->authService->resetPassword($otp, $data['phone'], $data['otp_code'], $data['password'], $audit);

        return response()->json(['message' => 'تم تغيير كلمة المرور. سجّل الدخول برقم جوالك وكلمة المرور الجديدة.']);
    }

    /** PATCH /me/phone: the number this account signs in with. */
    public function changePhone(ChangePhoneRequest $request, OtpService $otp, AuditService $audit)
    {
        $user = $this->authService->changePhone($otp, $request->user(), $request->validated('phone'), $request->validated('otp_code'), $audit);

        return response()->json(['message' => 'تم حفظ رقم الجوال. سجّل الدخول به من الآن.', 'user' => $user]);
    }

    public function register(RegisterStoreRequest $request, OtpService $otp)
    {
        $data = $request->validated();

        // With SMS codes on, the owner's number is confirmed before the store exists.
        if ($otp->enabled()) {
            $otp->verify($data['owner_phone'], PhoneOtp::PURPOSE_REGISTER, $data['otp_code'] ?? null);
            $data['phone_verified'] = true;
        }

        $user = $this->authService->registerStore($data);
        $token = $this->authService->issueToken($user);

        return $this->authenticatedResponse($user->load('store'), 'تم إنشاء المتجر والمالك بنجاح', 201, $token);
    }

    public function acceptInvitation(AcceptInvitationRequest $request)
    {
        $user = $this->authService->acceptInvitation($request->validated());
        $token = $this->authService->issueToken($user);

        return $this->authenticatedResponse($user, 'تم إنشاء الحساب والانضمام إلى المتجر بنجاح', 201, $token);
    }

    public function login(Request $request)
    {
        // `login` is the mobile number: accounts sign in with nothing else.
        $credentials = $request->validate([
            'login' => ['required', 'string', 'max:255'],
            'password' => ['required', 'string'],
        ], [
            'login.required' => 'اكتب رقم الجوال.',
        ]);

        $user = $this->authService->login($credentials['login'], $credentials['password'], (string) $request->ip());
        $token = $this->authService->issueToken($user);

        return $this->authenticatedResponse($user->load('store'), 'تم تسجيل دخولك بنجاح', 200, $token);
    }

    public function logout(Request $request)
    {
        $token = $request->user()->currentAccessToken();

        if ($token && method_exists($token, 'delete')) {
            $token->delete();
        }

        return response()->json(['message' => 'تم تسجيل الخروج بنجاح']);
    }

    public function me(Request $request)
    {
        return response()->json(['user' => $request->user()->load('store')]);
    }

    /**
     * PATCH /me/password: a new password for the signed-in account. This session stays signed in;
     * every other device is signed out, so a lost phone loses its access too.
     */
    public function changePassword(ChangePasswordRequest $request, AuditService $audit)
    {
        $user = $request->user();
        $current = $user->currentAccessToken();

        DB::transaction(function () use ($user, $current, $request, $audit) {
            $user->update(['password' => $request->validated('password')]);
            $user->tokens()->when($current?->id, fn($tokens, $id) => $tokens->whereKeyNot($id))->delete();
            $audit->record('user.password_changed', $user);
        });

        return response()->json(['message' => 'تم تغيير كلمة المرور. سُجّل الخروج من الأجهزة الأخرى.']);
    }

    private function authenticatedResponse(User $user, string $message, int $status, ?string $token = null)
    {
        return response()->json(array_filter([
            'message' => $message,
            'user' => $user,
            'token' => $token,
        ], static fn($value) => $value !== null), $status);
    }
}
