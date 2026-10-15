<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\AcceptInvitationRequest;
use App\Http\Requests\RegisterStoreRequest;
use App\Models\User;
use App\Services\AuthService;
use Illuminate\Http\Request;

class AuthController extends Controller
{
    public function __construct(private readonly AuthService $authService) {}

    public function register(RegisterStoreRequest $request)
    {
        $user = $this->authService->registerStore($request->validated());
        $token = $this->authService->issueToken($user);

        return $this->authenticatedResponse($user, 'تم إنشاء المتجر والمالك بنجاح', 201, $token);
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

    private function authenticatedResponse(User $user, string $message, int $status, ?string $token = null)
    {
        return response()->json(array_filter([
            'message' => $message,
            'user' => $user,
            'token' => $token,
        ], static fn($value) => $value !== null), $status);
    }
}
