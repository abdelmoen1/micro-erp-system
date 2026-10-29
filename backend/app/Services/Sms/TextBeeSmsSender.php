<?php

namespace App\Services\Sms;

use Illuminate\Support\Facades\Http;
use RuntimeException;

/**
 * textbee (MIT, textbee.dev): the message leaves from an Android phone of the store team with its
 * own SIM, so it costs only that SIM's SMS plan. The hosted free plan allows 50 messages a day.
 */
class TextBeeSmsSender implements SmsSender
{
    public function __construct(
        private readonly string $apiKey,
        private readonly ?string $deviceId,
        private readonly string $baseUrl,
    ) {}

    public function send(string $to, string $message): void
    {
        $response = Http::withHeaders(['x-api-key' => $this->apiKey])
            ->acceptJson()
            ->timeout(15)
            ->post(rtrim($this->baseUrl, '/') . '/gateway/send-sms', array_filter([
                'recipients' => [$to],
                'message' => $message,
                'deviceId' => $this->deviceId,
            ]));

        if (!$response->successful()) {
            throw new RuntimeException('textbee refused the message: HTTP ' . $response->status());
        }
    }
}
