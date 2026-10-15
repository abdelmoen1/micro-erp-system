<?php

namespace App\Http\Middleware;

use App\Exceptions\ApiException;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Blocks deactivated staff even if a token survived (US-0105, D-13).
 */
class EnsureUserIsActive
{
    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user();

        if ($user && !$user->isActive()) {
            $token = $user->currentAccessToken();

            if ($token && method_exists($token, 'delete')) {
                $token->delete();
            }

            throw new ApiException(403, 'USER_INACTIVE', 'تم إيقاف هذا الحساب. تواصل مع صاحب المتجر.');
        }

        return $next($request);
    }
}
