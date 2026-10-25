<?php

namespace App\Http\Middleware;

use App\Support\SubscriptionAccess;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Business routes need a running trial or a valid paid subscription (403 SUBSCRIPTION_EXPIRED).
 * Runs after `store`, so a suspended store gets STORE_SUSPENDED first. Session routes (/me, /logout,
 * /subscription) stay outside it, so an expired store can still sign in and reach the renewal screen.
 */
class EnsureStoreSubscription
{
    public function handle(Request $request, Closure $next): Response
    {
        $store = $request->user()?->store;

        if ($store && !$store->hasAccess()) {
            throw SubscriptionAccess::expired($store);
        }

        return $next($request);
    }
}
