<?php

/*
| Hisbah platform settings (subscriptions, trial, deletion). Values come from the environment;
| see .env.example and docs/release-readiness/SUBSCRIPTION_ARCHITECTURE.md.
*/

return [

    // Free trial a new store gets from its registration time, in days (once per owner number).
    'trial_days' => (int) env('HISBAH_TRIAL_DAYS', 14),

    // A trial or paid period with this many days or fewer left is reported as `expiring`.
    'expiring_days' => (int) env('HISBAH_EXPIRING_DAYS', 3),

    // An owner's "close my store" request: days before the store and its data are deleted.
    'deletion_grace_days' => (int) env('HISBAH_DELETION_GRACE_DAYS', 14),

    // Support number shown on the WEBSITE's "subscription expired" screen (digits only). The Android
    // app never shows it (Google Play consumption-only build).
    'support_whatsapp' => preg_replace('/\D+/', '', (string) env('SUPPORT_WHATSAPP', '')) ?: null,

    // WhatsApp Business number for manual subscription requests from the WEBSITE (international
    // digits, e.g. 970599000000). Empty: the request is still created, without a WhatsApp link.
    'whatsapp_business_number' => preg_replace('/\D+/', '', (string) env('WHATSAPP_BUSINESS_NUMBER', '')) ?: null,

    /*
    | Paid features a plan can grant (subscription_plans.features). A plan whose `features` is NULL
    | grants all of them; so do the trial and a subscription activated before plans existed.
    | Core selling, products, customers, debts, offline sync and the dashboard are not listed: every
    | store with access has them. Each feature here is enforced by `entitled:<code>` on its routes.
    */
    'features' => [
        'staff' => 'دعوة موظفين جدد',
        'suppliers' => 'تسجيل مشتريات ودفعات ومرتجعات الموردين',
        'csv_import' => 'استيراد الأصناف من ملف',
    ],

    // Limits a plan can set (subscription_plans.limits); missing or NULL = no limit.
    'limits' => [
        'max_employees' => 'أقصى عدد للموظفين (بدون المالك)',
        'max_products' => 'أقصى عدد للأصناف النشطة',
    ],

];
