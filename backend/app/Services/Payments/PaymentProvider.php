<?php

namespace App\Services\Payments;

use App\Models\SubscriptionOrder;
use Illuminate\Http\Request;

/**
 * What a Palestinian (or later regional) payment provider adapter must implement. No adapter exists
 * yet: each one is written from the provider's official documentation and tested against its
 * sandbox (PAYMENT_INTEGRATION_GUIDE.md). Adapters never see or store card data.
 */
interface PaymentProvider
{
    /** Config key, e.g. `palpay`. */
    public function key(): string;

    /**
     * Start a payment for the order at the provider and return where to send the customer.
     * Must send the order reference, amount and currency exactly as stored on the order.
     */
    public function createCheckout(SubscriptionOrder $order, string $returnUrl): CheckoutSession;

    /**
     * Authenticate an incoming notification (signature / HMAC / mutual TLS — whatever the provider
     * documents) and parse it. Throws InvalidPaymentNotification when it cannot be verified.
     */
    public function parseWebhook(Request $request): PaymentNotification;

    /** Ask the provider for the authoritative status of a payment (used before trusting a return URL). */
    public function fetchStatus(SubscriptionOrder $order): PaymentNotification;
}
