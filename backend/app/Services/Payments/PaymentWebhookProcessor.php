<?php

namespace App\Services\Payments;

use App\Models\SubscriptionOrder;
use App\Services\SubscriptionService;
use Illuminate\Support\Facades\Log;

/**
 * Applies a verified provider notification to its order: the reference must name an order of this
 * provider; amount and currency must match it (SubscriptionService checks); a repeated transaction
 * is a no-op. A `pending` notification changes nothing.
 */
class PaymentWebhookProcessor
{
    public function __construct(private readonly SubscriptionService $subscriptions) {}

    /** @return string what happened: activated | duplicate | failed | ignored */
    public function handle(string $provider, PaymentNotification $notification): string
    {
        $order = SubscriptionOrder::where('reference', $notification->orderReference)->first();
        if (!$order || $order->provider !== $provider || $order->channel !== SubscriptionOrder::CHANNEL_ONLINE) {
            Log::warning('Payment notification for an unknown order.', ['provider' => $provider, 'reference' => $notification->orderReference]);

            return 'ignored';
        }

        return match ($notification->status) {
            PaymentNotification::PAID => $this->paid($provider, $order, $notification),
            PaymentNotification::FAILED => tap('failed', fn() => $this->subscriptions->markProviderFailed($order, $provider, $notification->reason)),
            default => 'ignored',
        };
    }

    private function paid(string $provider, SubscriptionOrder $order, PaymentNotification $n): string
    {
        $wasPaid = $order->status === SubscriptionOrder::PAID;
        $this->subscriptions->confirmProviderPayment($order, $provider, $n->transactionId, $n->amount, $n->currency, $n->paidAt ?? now());

        return $wasPaid ? 'duplicate' : 'activated';
    }
}
