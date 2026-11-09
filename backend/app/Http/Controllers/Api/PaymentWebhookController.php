<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\Payments\InvalidPaymentNotification;
use App\Services\Payments\PaymentProviderRegistry;
use App\Services\Payments\PaymentWebhookProcessor;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;

/**
 * POST /payments/webhooks/{provider}: unauthenticated by design; the adapter verifies the
 * provider's signature. A provider that is not enabled with a real driver answers 404.
 */
class PaymentWebhookController extends Controller
{
    public function __invoke(Request $request, string $provider, PaymentProviderRegistry $registry, PaymentWebhookProcessor $processor)
    {
        $adapter = $registry->get($provider);
        abort_if(!$adapter, 404);

        try {
            $notification = $adapter->parseWebhook($request);
        } catch (InvalidPaymentNotification $e) {
            Log::warning('Rejected payment notification.', ['provider' => $provider, 'reason' => $e->getMessage()]);

            return response()->json(['code' => 'INVALID_SIGNATURE', 'message' => 'Invalid notification.'], 400);
        }

        return response()->json(['result' => $processor->handle($provider, $notification)]);
    }
}
