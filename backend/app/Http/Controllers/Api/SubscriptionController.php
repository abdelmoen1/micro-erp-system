<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Support\SubscriptionAccess;
use Illuminate\Http\Request;

/** The signed-in store's trial / subscription. Reachable after expiry (renewal screen, "check again"). */
class SubscriptionController extends Controller
{
    public function show(Request $request)
    {
        return response()->json(['data' => SubscriptionAccess::summary($request->user()->store)]);
    }
}
