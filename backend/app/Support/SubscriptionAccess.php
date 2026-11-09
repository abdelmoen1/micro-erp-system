<?php

namespace App\Support;

use App\Exceptions\ApiException;
use App\Models\Store;

/**
 * The store's trial / subscription as its own clients see it, and the 403 SUBSCRIPTION_EXPIRED that
 * every business route returns once the store has no access (EnsureStoreSubscription).
 * Messages are neutral (no payment instructions): the Android app is a consumption-only Play build.
 */
final class SubscriptionAccess
{
    /** For GET /subscription and the error details. */
    public static function summary(Store $store): array
    {
        $trialEnds = $store->trial_ends_at;
        $ends = $store->accessEndsAt();

        return [
            'state' => $store->subscriptionState(),
            'lifecycle' => $store->lifecycle(),
            'has_access' => $store->hasAccess(),
            'trial_started_at' => $store->trial_started_at?->toIso8601String(),
            'trial_ends_at' => $trialEnds?->toIso8601String(),
            'subscription_expires_at' => $store->subscription_expires_at?->toIso8601String(),
            // Whole days left in the trial, rounded up (0 once it has ended).
            'trial_days_left' => $trialEnds && $trialEnds->isFuture() ? (int) ceil(now()->diffInSeconds($trialEnds) / 86400) : 0,
            'days_left' => $ends && $ends->isFuture() ? (int) ceil(now()->diffInSeconds($ends) / 86400) : 0,
            'entitlements' => $store->entitlements(),
            // Used by the website only; the Android app never shows it.
            'support_whatsapp' => config('hisbah.support_whatsapp'),
        ];
    }

    public static function expired(Store $store): ApiException
    {
        $message = $store->subscriptionState() === Store::SUBSCRIPTION_EXPIRED
            ? 'انتهى اشتراك متجرك. بياناتك محفوظة كما هي.'
            : 'انتهت الفترة التجريبية لمتجرك. بياناتك محفوظة كما هي.';

        return new ApiException(403, 'SUBSCRIPTION_EXPIRED', $message, details: self::summary($store));
    }

    public static function featureMissing(string $feature): ApiException
    {
        return new ApiException(403, 'FEATURE_NOT_IN_PLAN', 'هذه الميزة غير مشمولة في باقة متجرك.', details: ['feature' => $feature]);
    }

    public static function limitReached(string $limit, int $max): ApiException
    {
        return new ApiException(403, 'PLAN_LIMIT_REACHED', 'وصل متجرك إلى الحد المسموح في باقته.', details: ['limit' => $limit, 'max' => $max]);
    }
}
