<?php

namespace App\Http\Middleware;

use App\Exceptions\ApiException;
use App\Services\AuthService;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class EnsureUserHasStore
{
    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user();

        if (!$user || !$user->store_id) {
            throw new ApiException(403, 'STORE_REQUIRED', 'المستخدم غير مرتبط بمتجر');
        }

        // A suspended store is closed to every member, platform admins included; tokens are kept
        // so access returns as soon as the store is reactivated.
        if ($user->store?->isSuspended()) {
            throw AuthService::storeSuspended();
        }

        // The owner asked to delete the store: until the date, only the owner may sign in, see the
        // request and cancel it. Everything else is closed.
        if ($user->store?->isClosing()) {
            $allowed = $request->is('api/v1/logout', 'api/v1/me', 'api/v1/me/deletion', 'api/v1/subscription');
            if (!$allowed || !$user->hasRole(\App\Enums\UserRole::OWNER)) {
                throw AuthService::storeClosing($user->store);
            }
        }

        return $next($request);
    }
}
