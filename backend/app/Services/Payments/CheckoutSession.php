<?php

namespace App\Services\Payments;

/** Where the website sends the customer to pay, and the provider's id for that attempt. */
final class CheckoutSession
{
    public function __construct(
        public readonly string $redirectUrl,
        public readonly string $providerReference,
    ) {}
}
