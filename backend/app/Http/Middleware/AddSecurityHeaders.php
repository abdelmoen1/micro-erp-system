<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Baseline response headers for every response (API JSON and the welcome page).
 * The API returns JSON only, so nothing here limits what it legitimately does:
 * no MIME sniffing, no framing, no referrer leaks, and HTTPS pinned once a request arrived over it.
 */
class AddSecurityHeaders
{
    public function handle(Request $request, Closure $next): Response
    {
        $response = $next($request);
        $headers = $response->headers;

        $headers->set('X-Content-Type-Options', 'nosniff');
        $headers->set('X-Frame-Options', 'DENY');
        $headers->set('Referrer-Policy', 'no-referrer');
        $headers->set('Permissions-Policy', 'camera=(), microphone=(), geolocation=(), payment=()');
        $headers->set('Cross-Origin-Opener-Policy', 'same-origin');
        $headers->remove('X-Powered-By');

        if ($request->is('api/*')) {
            // JSON is never a document to render: block scripts, frames and plugins outright.
            $headers->set('Content-Security-Policy', "default-src 'none'; frame-ancestors 'none'");
        }

        // Only once the request is known to be HTTPS (Render forwards the scheme: bootstrap/app.php).
        if ($request->secure()) {
            $headers->set('Strict-Transport-Security', 'max-age=31536000');
        }

        return $response;
    }
}
