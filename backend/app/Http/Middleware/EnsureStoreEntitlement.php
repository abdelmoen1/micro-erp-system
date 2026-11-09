<?php

namespace App\Http\Middleware;

use App\Support\SubscriptionAccess;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * `entitled:<feature>`: the store's plan must grant the feature (Store::entitlements). The server
 * decides; hiding a button in a client is never the protection. Runs after `subscribed`.
 */
class EnsureStoreEntitlement
{
    public function handle(Request $request, Closure $next, string $feature): Response
    {
        $store = $request->user()?->store;

        if ($store && !$store->hasFeature($feature)) {
            throw SubscriptionAccess::featureMissing($feature);
        }

        return $next($request);
    }
}
