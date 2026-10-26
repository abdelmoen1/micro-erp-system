<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\AcceptInvitationRequest;
use App\Http\Requests\ChangePasswordRequest;
use App\Http\Requests\GoogleRegisterStoreRequest;
use App\Http\Requests\RegisterStoreRequest;
use App\Models\User;
use App\Services\AuditService;
use App\Services\AuthService;
use App\Services\GoogleIdTokenVerifier;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class AuthController extends Controller
{
    public function __construct(private readonly AuthService $authService) {}

    public function register(RegisterStoreRequest $request)
    {
        $user = $this->authService->registerStore($request->validated());
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
        $credentials = $request->validate([
            'email' => ['required', 'email'],
            'password' => ['required', 'string'],
        ]);

        $user = $this->authService->login($credentials['email'], $credentials['password'], (string) $request->ip());
        $token = $this->authService->issueToken($user);

        return $this->authenticatedResponse($user->load('store'), 'تم تسجيل دخولك بنجاح', 200, $token);
    }

    /**
     * Google sign-in. A known account gets a token; a new one gets an onboarding token for
     * POST /register/google, so no store is created before the owner fills it in.
     */
    public function google(Request $request, GoogleIdTokenVerifier $verifier)
    {
        $data = $request->validate(['credential' => ['required', 'string', 'max:4096']]);
        $profile = $verifier->verify($data['credential']);
        $user = $this->authService->findGoogleUser($profile);

        if (!$user) {
            return response()->json([
                'message' => 'أكمل بيانات متجرك لإنشاء الحساب',
                'onboarding' => [
                    'token' => $this->authService->onboardingToken($profile),
                    'name' => $profile['name'],
                    'email' => $profile['email'],
                ],
            ]);
        }

        $token = $this->authService->issueToken($user);

        return $this->authenticatedResponse($user->load('store'), 'تم تسجيل دخولك بنجاح', 200, $token);
    }

    public function registerWithGoogle(GoogleRegisterStoreRequest $request)
    {
        $user = $this->authService->registerStoreWithGoogle($request->validated());
        $token = $this->authService->issueToken($user);

        return $this->authenticatedResponse($user, 'تم إنشاء المتجر والمالك بنجاح', 201, $token);
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
