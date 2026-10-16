<?php

namespace Tests\Feature;

use Tests\TestCase;

/**
 * A protected API route answers guests with the 401 JSON envelope whatever the Accept header
 * (found on the deployed API: without `Accept: application/json` it returned 500).
 */
class GuestApiResponseTest extends TestCase
{
    public function test_guest_without_json_accept_header_gets_401_envelope(): void
    {
        $this->get('/api/v1/me')
            ->assertUnauthorized()
            ->assertJsonPath('code', 'UNAUTHENTICATED');
    }

    public function test_guest_with_json_accept_header_still_gets_401_envelope(): void
    {
        $this->getJson('/api/v1/me')
            ->assertUnauthorized()
            ->assertJsonPath('code', 'UNAUTHENTICATED');
    }
}
