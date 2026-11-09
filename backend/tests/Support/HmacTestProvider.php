<?php

namespace Tests\Support;

use App\Models\SubscriptionOrder;
use App\Services\Payments\CheckoutSession;
use App\Services\Payments\InvalidPaymentNotification;
use App\Services\Payments\PaymentNotification;
use App\Services\Payments\PaymentProvider;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;

/**
 * TEST DOUBLE ONLY (never registered by the application): exercises the provider-independent
 * webhook pipeline with an HMAC-signed JSON body. It does not model any real provider's API.
 */
class HmacTestProvider implements PaymentProvider
{
    public const SECRET = 'test-only-secret';

    public function key(): string
    {
        return 'testpay';
    }

    public function createCheckout(SubscriptionOrder $order, string $returnUrl): CheckoutSession
    {
        return new CheckoutSession('https://checkout.test.invalid/' . $order->reference, 'tp_' . $order->reference);
    }

    public function parseWebhook(Request $request): PaymentNotification
    {
        $expected = hash_hmac('sha256', $request->getContent(), self::SECRET);
        if (!hash_equals($expected, (string) $request->header('X-Test-Signature'))) {
            throw new InvalidPaymentNotification('bad signature');
        }
        $body = $request->json()->all();

        return new PaymentNotification(
            $body['reference'], $body['status'], $body['transaction_id'], (string) $body['amount'], $body['currency'],
            isset($body['paid_at']) ? Carbon::parse($body['paid_at']) : null,
        );
    }

    public function fetchStatus(SubscriptionOrder $order): PaymentNotification
    {
        return new PaymentNotification($order->reference, PaymentNotification::PENDING, '', (string) $order->amount, $order->currency);
    }

    public static function sign(array $body): array
    {
        $json = json_encode($body);

        return [$json, ['X-Test-Signature' => hash_hmac('sha256', $json, self::SECRET), 'Content-Type' => 'application/json']];
    }
}
