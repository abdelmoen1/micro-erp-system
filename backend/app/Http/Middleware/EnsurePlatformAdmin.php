<?php

namespace App\Http\Middleware;

use App\Exceptions\ApiException;
use App\Models\AdminAccessLog;
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

        // Every platform-admin request is logged (who, what, which store, when): the owner can see
        // other stores' products, prices and suppliers, so that access leaves a trace.
        $storeParam = $request->route('store');
        AdminAccessLog::create([
            'admin_id' => $request->user()->id,
            'method' => $request->method(),
            'path' => substr($request->path(), 0, 255),
            'target_store_id' => is_numeric($storeParam) ? (int) $storeParam : ($request->integer('store_id') ?: null),
            'ip' => $request->ip(),
        ]);

        return $next($request);
    }
}
