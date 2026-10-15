<?php

namespace App\Http\Middleware;

use App\Exceptions\ApiException;
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

        return $next($request);
    }
}
