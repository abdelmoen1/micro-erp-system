<?php

namespace App\Http\Middleware;

use App\Exceptions\ApiException;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Platform owner routes (/admin). Runs before route-model binding (bootstrap/app.php), so a store
 * owner gets the same 403 whether or not the store id exists.
 */
class EnsurePlatformAdmin
{
    public function handle(Request $request, Closure $next): Response
    {
        if (!$request->user()?->isPlatformAdmin()) {
            throw new ApiException(403, 'FORBIDDEN', 'هذه الصفحة لمالك المنصة فقط.');
        }

        return $next($request);
    }
}
