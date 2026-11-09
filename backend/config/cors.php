<?php

/*
| Cross-origin requests from browsers.
|
| The web back office calls the API through its own origin (frontend/vercel.json rewrites /api to
| Render), and the Android app is not a browser, so neither needs CORS. Only the origins listed in
| CORS_ALLOWED_ORIGINS (comma separated) may call the API cross-origin; the default allows the
| production web origin and the local Vite dev server. Authentication is by bearer token, never by
| cookie, so credentials are not supported.
*/

$origins = array_values(array_filter(array_map(
    'trim',
    explode(',', (string) env('CORS_ALLOWED_ORIGINS', 'https://hisbah-web.vercel.app,http://localhost:5173,http://127.0.0.1:5173')),
)));

return [

    'paths' => ['api/*'],

    'allowed_methods' => ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],

    'allowed_origins' => $origins,

    'allowed_origins_patterns' => [],

    'allowed_headers' => ['Accept', 'Authorization', 'Content-Type', 'Idempotency-Key', 'X-Correlation-ID', 'X-Requested-With'],

    'exposed_headers' => ['X-Correlation-ID', 'Retry-After'],

    'max_age' => 600,

    'supports_credentials' => false,

];
