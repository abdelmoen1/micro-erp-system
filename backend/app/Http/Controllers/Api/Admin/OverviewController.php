<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\CatalogProduct;
use App\Models\Product;
use App\Models\Store;

/** Platform admin: store and subscription counts for the overview strip. */
class OverviewController extends Controller
{
    public function __invoke()
    {
        $count = fn(callable $scope) => $scope(Store::query())->count();

        return response()->json([
            'data' => [
                'stores' => [
                    'total' => Store::query()->count(),
                    'active' => $count(fn($q) => $q->where('status', Store::STATUS_ACTIVE)),
                    'suspended' => $count(fn($q) => $q->where('status', Store::STATUS_SUSPENDED)),
                    'registered_last_30_days' => $count(fn($q) => $q->where('created_at', '>=', now()->subDays(30))),
                ],
                'subscriptions' => [
                    'active' => $count(fn($q) => $q->subscriptionState(Store::SUBSCRIPTION_ACTIVE)),
                    'trial' => $count(fn($q) => $q->subscriptionState(Store::SUBSCRIPTION_TRIAL)),
                    'expired' => $count(fn($q) => $q->subscriptionState(Store::SUBSCRIPTION_EXPIRED)),
                    'inactive' => $count(fn($q) => $q->subscriptionState(Store::SUBSCRIPTION_INACTIVE)),
                ],
                'products' => [
                    'store_rows' => Product::query()->count(),
                    'catalog_items' => CatalogProduct::query()->count(),
                ],
                'generated_at' => now(),
            ],
        ]);
    }
}
