<?php

namespace Tests\Feature;

use Illuminate\Support\Facades\Route;
use Tests\TestCase;

/**
 * Deployment behind an HTTPS-terminating edge (Railway): generated URLs must be https,
 * otherwise browsers block the Vite assets as mixed content. The client IP must not be
 * taken from X-Forwarded-For, which the login throttle relies on.
 */
class TrustedProxyTest extends TestCase
{
    protected function setUp(): void
    {
        parent::setUp();

        Route::get('/_proxy-probe', fn () => response()->json([
            'url' => asset('build/app.css'), // the helper @vite uses for asset tags
            'secure' => request()->secure(),
            'ip' => request()->ip(),
        ]));
    }

    public function test_forwarded_https_produces_https_urls(): void
    {
        $this->get('/_proxy-probe', ['X-Forwarded-Proto' => 'https', 'X-Forwarded-Host' => 'shop.example.com'])
            ->assertOk()
            ->assertJsonPath('secure', true)
            ->assertJsonPath('url', 'https://shop.example.com/build/app.css');
    }

    public function test_plain_request_stays_http(): void
    {
        $this->get('/_proxy-probe')
            ->assertOk()
            ->assertJsonPath('secure', false);

        $this->assertStringStartsWith('http://', $this->get('/_proxy-probe')->json('url'));
    }

    public function test_spoofed_forwarded_for_does_not_change_client_ip(): void
    {
        $this->withServerVariables(['REMOTE_ADDR' => '10.0.0.5'])
            ->get('/_proxy-probe', ['X-Forwarded-For' => '203.0.113.9'])
            ->assertOk()
            ->assertJsonPath('ip', '10.0.0.5');
    }
}
