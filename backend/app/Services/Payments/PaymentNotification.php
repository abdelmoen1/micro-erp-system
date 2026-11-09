<?php

namespace App\Services\Payments;

use Illuminate\Support\Carbon;

/** A provider message AFTER its authenticity was verified by the adapter. */
final class PaymentNotification
{
    public const PAID = 'paid';
    public const FAILED = 'failed';
    public const PENDING = 'pending';

    public function __construct(
        public readonly string $orderReference,
        public readonly string $status,
        public readonly string $transactionId,
        public readonly string $amount,
        public readonly string $currency,
        public readonly ?Carbon $paidAt = null,
        public readonly ?string $reason = null,
    ) {}
}
