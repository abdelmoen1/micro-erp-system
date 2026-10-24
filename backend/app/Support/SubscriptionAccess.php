<?php

namespace App\Support;

use App\Exceptions\ApiException;
use App\Models\Store;

/**
 * The store's trial / subscription as its own clients see it, and the 403 SUBSCRIPTION_EXPIRED that
 * every business route returns once the store has no access (EnsureStoreSubscription).
 */
final class SubscriptionAccess
{
    /** For GET /subscription and the error details: what the renewal screen needs. */
    public static function summary(Store $store): array
    {
        $trialEnds = $store->trial_ends_at;

        return [
            'state' => $store->subscriptionState(),
            'has_access' => $store->hasAccess(),
            'trial_ends_at' => $trialEnds?->toIso8601String(),
            'subscription_expires_at' => $store->subscription_expires_at?->toIso8601String(),
            // Whole days left in the trial, rounded up (0 once it has ended).
            'trial_days_left' => $trialEnds && $trialEnds->isFuture() ? (int) ceil(now()->diffInSeconds($trialEnds) / 86400) : 0,
            'support_whatsapp' => config('hisbah.support_whatsapp'),
        ];
    }

    public static function expired(Store $store): ApiException
    {
        $message = $store->subscriptionState() === Store::SUBSCRIPTION_EXPIRED
            ? 'انتهى اشتراك متجرك. بياناتك محفوظة؛ تواصل مع إدارة حسبة لتجديد الاشتراك.'
            : 'انتهت الفترة التجريبية لمتجرك. بياناتك محفوظة؛ تواصل مع إدارة حسبة لتفعيل الاشتراك.';

        return new ApiException(403, 'SUBSCRIPTION_EXPIRED', $message, details: self::summary($store));
    }
}
