<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\UpdateStoreSettingsRequest;
use Illuminate\Http\Request;

class StoreSettingsController extends Controller
{
    public function show(Request $request)
    {
        return response()->json([
            'user' => $request->user()->name,
            'store' => $request->user()->store,
        ]);
    }

    /**
     * Owner-only store settings: the business timezone (D-23 / CR-14), the address, the area and
     * the map coordinates. Access and subscription columns are not fillable, so they cannot be sent.
     */
    public function update(UpdateStoreSettingsRequest $request)
    {
        $store = $request->user()->store;
        $store->update($request->validated());

        return response()->json([
            'message' => 'تم تحديث إعدادات المتجر بنجاح',
            'store' => $store->refresh(),
        ]);
    }
}
