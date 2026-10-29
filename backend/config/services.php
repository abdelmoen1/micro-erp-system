<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Third Party Services
    |--------------------------------------------------------------------------
    |
    | This file is for storing the credentials for third party services such
    | as Mailgun, Postmark, AWS and more. This file provides the de facto
    | location for this type of information, allowing packages to have
    | a conventional file to locate the various service credentials.
    |
    */

    'postmark' => [
        'token' => env('POSTMARK_TOKEN'),
    ],

    'ses' => [
        'key' => env('AWS_ACCESS_KEY_ID'),
        'secret' => env('AWS_SECRET_ACCESS_KEY'),
        'region' => env('AWS_DEFAULT_REGION', 'us-east-1'),
    ],

    'resend' => [
        'key' => env('RESEND_KEY'),
    ],

    // Google sign-in (web): the OAuth client id the ID tokens must be issued for.
    'google' => [
        'client_id' => env('GOOGLE_CLIENT_ID'),
    ],

    // One-time SMS codes (sign-up, forgotten password, changed number). `textbee` sends from the
    // team's Android phone and SIM; `log` writes them to the log (local only); empty = off, and
    // sign-up works without a code. 45 a day keeps under textbee's free 50.
    'sms' => [
        'driver' => env('SMS_DRIVER'),
        'daily_limit' => (int) env('SMS_DAILY_LIMIT', 45),
    ],

    'textbee' => [
        'key' => env('TEXTBEE_API_KEY'),
        'device_id' => env('TEXTBEE_DEVICE_ID'),
        'url' => env('TEXTBEE_API_URL', 'https://api.textbee.dev/api/v1'),
    ],

    'slack' => [
        'notifications' => [
            'bot_user_oauth_token' => env('SLACK_BOT_USER_OAUTH_TOKEN'),
            'channel' => env('SLACK_BOT_USER_DEFAULT_CHANNEL'),
        ],
    ],

];
