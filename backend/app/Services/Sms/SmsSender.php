<?php

namespace App\Services\Sms;

/** Sends one text message. Throws when the gateway did not accept it. */
interface SmsSender
{
    /** @param string $to E.164, e.g. +970599123456 */
    public function send(string $to, string $message): void;
}
