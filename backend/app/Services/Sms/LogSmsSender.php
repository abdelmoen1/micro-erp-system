<?php

namespace App\Services\Sms;

use Illuminate\Support\Facades\Log;

/** Local development: the message goes to the log instead of a phone. Never used in production. */
class LogSmsSender implements SmsSender
{
    public function send(string $to, string $message): void
    {
        Log::info('SMS to ' . $to . ': ' . $message);
    }
}
