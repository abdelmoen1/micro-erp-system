<?php

/*
| Online payment providers for subscription orders (docs/release-readiness/PAYMENT_INTEGRATION_GUIDE.md).
|
| No provider is integrated yet: the selected provider's official documentation and sandbox
| credentials are required first. A provider is offered only when `enabled` is true AND `driver`
| names a class implementing App\Services\Payments\PaymentProvider. Nothing here talks to a
| provider, and no endpoint, signature scheme or response format has been assumed.
*/

$provider = fn(string $prefix) => [
    'enabled' => (bool) env("{$prefix}_ENABLED", false),
    'driver' => env("{$prefix}_DRIVER"), // e.g. App\Services\Payments\Providers\PalPayProvider (not written yet)
    'mode' => env("{$prefix}_MODE", 'sandbox'), // sandbox | live
    'merchant_id' => env("{$prefix}_MERCHANT_ID"),
    'api_key' => env("{$prefix}_API_KEY"),
    'webhook_secret' => env("{$prefix}_WEBHOOK_SECRET"),
    'base_url' => env("{$prefix}_BASE_URL"),
];

return [

    // Currencies an order may be priced in (ISO 4217). ILS first: the Palestinian market.
    'currencies' => array_values(array_filter(array_map('trim', explode(',', (string) env('PAYMENT_CURRENCIES', 'ILS,USD,JOD'))))),

    'providers' => [
        'palpay' => ['label' => 'PalPay'] + $provider('PALPAY'),
        'jawwal_pay' => ['label' => 'Jawwal Pay'] + $provider('JAWWAL_PAY'),
        'bank_of_palestine' => ['label' => 'Bank of Palestine'] + $provider('BOP_GATEWAY'),
    ],

];
