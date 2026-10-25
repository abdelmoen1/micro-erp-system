<?php

/*
| Hisbah platform settings (subscriptions). Values come from the environment; see .env.example.
*/

return [

    // Free trial a new store gets from its registration time, in days.
    'trial_days' => (int) env('HISBAH_TRIAL_DAYS', 7),

    // WhatsApp number shown on the "subscription expired" screens, international format digits
    // only (e.g. 970599000000). Empty: the screens show the message without the WhatsApp button.
    'support_whatsapp' => preg_replace('/\D+/', '', (string) env('SUPPORT_WHATSAPP', '')) ?: null,

];
