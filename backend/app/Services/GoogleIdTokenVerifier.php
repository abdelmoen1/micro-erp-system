<?php

namespace App\Services;

use App\Exceptions\ApiException;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Str;

/**
 * Checks a Google Identity Services ID token (the `credential` the web button returns) with
 * Google's tokeninfo endpoint, which validates the signature and expiry, then checks that the
 * token was issued for our client id and carries a verified email.
 */
class GoogleIdTokenVerifier
{
    public const TOKENINFO_URL = 'https://oauth2.googleapis.com/tokeninfo';

    private const ISSUERS = ['accounts.google.com', 'https://accounts.google.com'];

    /** @return array{sub: string, email: string, name: string} */
    public function verify(string $idToken): array
    {
        $clientId = (string) config('services.google.client_id');

        if ($clientId === '') {
            throw new ApiException(503, 'SSO_UNAVAILABLE', 'الدخول بحساب Google غير مفعّل على هذا الخادم.');
        }

        try {
            $response = Http::timeout(8)->acceptJson()->get(self::TOKENINFO_URL, ['id_token' => $idToken]);
        } catch (ConnectionException) {
            throw new ApiException(503, 'SSO_UNAVAILABLE', 'تعذّر الوصول إلى Google. أعد المحاولة بعد قليل.');
        }

        if ($response->serverError()) {
            throw new ApiException(503, 'SSO_UNAVAILABLE', 'تعذّر الوصول إلى Google. أعد المحاولة بعد قليل.');
        }

        $claims = $response->ok() ? $response->json() : null;

        if (
            !is_array($claims)
            || !hash_equals($clientId, (string) ($claims['aud'] ?? ''))
            || !in_array($claims['iss'] ?? null, self::ISSUERS, true)
            || (int) ($claims['exp'] ?? 0) <= now()->getTimestamp()
            || !in_array($claims['email_verified'] ?? null, [true, 'true'], true)
            || empty($claims['sub'])
            || empty($claims['email'])
        ) {
            throw new ApiException(401, 'GOOGLE_TOKEN_INVALID', 'تعذّر التحقق من حساب Google. أعد المحاولة.');
        }

        return [
            'sub' => (string) $claims['sub'],
            'email' => Str::lower((string) $claims['email']),
            'name' => (string) ($claims['name'] ?? ''),
        ];
    }
}
