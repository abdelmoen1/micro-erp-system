<?php

namespace App\Http\Controllers\Api;

use App\Enums\UserRole;
use App\Exceptions\ApiException;
use App\Http\Controllers\Controller;
use App\Models\Store;
use App\Models\SubscriptionOrder;
use App\Models\SubscriptionPlan;
use App\Services\Payments\PaymentProviderRegistry;
use App\Services\SubscriptionService;
use App\Support\Money;
use App\Support\SubscriptionAccess;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

/**
 * The signed-in store's trial / subscription, and buying a plan (website). Reachable after expiry.
 * Only the owner may order; every member may read the status and the entitlements.
 */
class SubscriptionController extends Controller
{
    public function show(Request $request)
    {
        return response()->json(['data' => SubscriptionAccess::summary($request->user()->store)]);
    }

    /** Plans that can be ordered now (active and priced), plus how they can be paid. */
    public function plans(PaymentProviderRegistry $providers)
    {
        $plans = SubscriptionPlan::query()->ordered()->where('is_active', true)->get()
            ->filter(fn(SubscriptionPlan $plan) => $plan->isOrderable())
            ->map(fn(SubscriptionPlan $plan) => self::plan($plan))->values();

        return response()->json([
            'data' => $plans,
            'meta' => [
                'online_providers' => (object) $providers->available(),
                'whatsapp_available' => config('hisbah.whatsapp_business_number') !== null,
                'features' => config('hisbah.features'),
            ],
        ]);
    }

    public function orders(Request $request)
    {
        $orders = SubscriptionOrder::where('store_id', $request->user()->store_id)->latest('id')->limit(50)->get();

        return response()->json(['data' => $orders->map(fn($o) => self::order($o))->values()]);
    }

    /**
     * POST /subscription/orders: the owner asks for a plan. `manual_whatsapp` creates a pending
     * request and returns a WhatsApp link with its reference; nothing is activated until a platform
     * admin confirms the payment. `online` needs an enabled provider (none yet: 503).
     */
    public function store(Request $request, SubscriptionService $subscriptions, PaymentProviderRegistry $providers)
    {
        $user = $request->user();
        if (!$user->hasRole(UserRole::OWNER)) {
            throw new ApiException(403, 'FORBIDDEN', 'صاحب المتجر فقط يطلب الاشتراك.');
        }
        $data = $request->validate([
            'plan_id' => ['required', 'integer'],
            'channel' => ['required', Rule::in([SubscriptionOrder::CHANNEL_MANUAL, SubscriptionOrder::CHANNEL_ONLINE])],
            'provider' => ['nullable', 'string', 'max:30'],
        ]);
        $plan = SubscriptionPlan::find($data['plan_id']);
        if (!$plan) {
            throw ApiException::conflict('PLAN_UNAVAILABLE', 'هذه الباقة غير متاحة للشراء حالياً.');
        }

        if ($data['channel'] === SubscriptionOrder::CHANNEL_ONLINE) {
            $provider = $providers->get((string) ($data['provider'] ?? ''));
            if (!$provider) {
                throw new ApiException(503, 'PAYMENT_PROVIDER_UNAVAILABLE', 'الدفع الإلكتروني غير متاح حالياً. اختر الطلب عبر واتساب.');
            }
            $order = $subscriptions->createOrder($user->store, $user, $plan, SubscriptionOrder::CHANNEL_ONLINE, $provider->key());
            $session = $provider->createCheckout($order, rtrim((string) config('app.frontend_url', config('app.url')), '/') . '/subscription?order=' . $order->reference);
            $order->forceFill(['provider_reference' => $session->providerReference])->save();

            return response()->json(['data' => self::order($order) + ['checkout_url' => $session->redirectUrl]], 201);
        }

        $order = $subscriptions->createOrder($user->store, $user, $plan, SubscriptionOrder::CHANNEL_MANUAL);

        return response()->json(['data' => self::order($order) + ['whatsapp_url' => self::whatsappUrl($order, $user->store)]], 201);
    }

    /** wa.me link with a prefilled message: store, plan, duration, price and the reference. Nothing secret. */
    public static function whatsappUrl(SubscriptionOrder $order, Store $store): ?string
    {
        $number = config('hisbah.whatsapp_business_number');
        if (!$number) {
            return null;
        }
        $months = $order->duration_months;
        $duration = match (true) {
            $months === 1 => 'شهر واحد',
            $months === 2 => 'شهران',
            $months <= 10 => $months . ' أشهر',
            default => $months . ' شهراً',
        };
        $text = implode("\n", [
            'مرحباً، أريد الاشتراك في حسبة.',
            'المتجر: ' . $store->name,
            'الباقة: ' . ($order->plan_snapshot['name'] ?? '') . ' (' . $duration . ')',
            'السعر: ' . Money::of($order->amount) . ' ' . $order->currency,
            'رقم الطلب: ' . $order->reference,
        ]);

        return 'https://wa.me/' . $number . '?text=' . rawurlencode($text);
    }

    public static function plan(SubscriptionPlan $plan): array
    {
        return [
            'id' => $plan->id,
            'code' => $plan->code,
            'name' => $plan->name,
            'description' => $plan->description,
            'duration_months' => $plan->duration_months,
            'price' => $plan->price === null ? null : Money::of($plan->price),
            'currency' => $plan->currency,
            'features' => $plan->featureCodes(),
            'limits' => (object) array_filter($plan->limits ?? [], fn($v) => $v !== null),
        ];
    }

    public static function order(SubscriptionOrder $order): array
    {
        return [
            'id' => $order->id,
            'reference' => $order->reference,
            'status' => $order->status,
            'channel' => $order->channel,
            'plan' => ['name' => $order->plan_snapshot['name'] ?? null, 'code' => $order->plan_snapshot['code'] ?? null],
            'duration_months' => $order->duration_months,
            'amount' => Money::of($order->amount),
            'currency' => $order->currency,
            'created_at' => $order->created_at?->toIso8601String(),
            'paid_at' => $order->paid_at?->toIso8601String(),
            'period_starts_at' => $order->period_starts_at?->toIso8601String(),
            'period_ends_at' => $order->period_ends_at?->toIso8601String(),
        ];
    }
}
