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

        return $next($request);
    }
}
