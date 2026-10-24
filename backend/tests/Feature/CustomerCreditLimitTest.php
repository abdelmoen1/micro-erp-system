<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Support\BuildsShopData;
use Tests\TestCase;

/** US-0305 customer credit limit (TC-0305-01, TC-0305-02). Enforcement is US-0502. */
class CustomerCreditLimitTest extends TestCase
{
    use BuildsShopData;
    use RefreshDatabase;

    /** TC-0305-01 + AC1: owner and manager set the limit; it is saved and returned as money. */
    public function test_owner_and_manager_set_the_credit_limit(): void
    {
        $store = $this->makeStore();
        $owner = $this->makeUser($store);
        $manager = $this->makeUser($store, 'manager');

        $id = $this->actingAs($owner, 'sanctum')
            ->postJson('/api/v1/customers', ['name' => 'Abu Ahmad', 'phone' => '0591111111', 'credit_limit' => '500'])
            ->assertCreated()
            ->assertJsonPath('customer.credit_limit', '500.00')
            ->json('customer.id');

        $this->actingAs($manager, 'sanctum')
            ->patchJson("/api/v1/customers/{$id}", ['credit_limit' => '750.50'])
            ->assertOk()
            ->assertJsonPath('data.credit_limit', '750.50');

        $this->assertSame('750.50', $this->actingAs($owner, 'sanctum')->getJson("/api/v1/customers/{$id}")->json('data.credit_limit'));
    }

    /** TC-0305-01 + AC1: an employee setting a limit gets 403 and nothing changes; other edits still work. */
    public function test_employee_cannot_set_the_credit_limit(): void
    {
        $store = $this->makeStore();
        $employee = $this->makeUser($store, 'employee');
        $customer = $this->makeCustomer($store);
        $api = $this->actingAs($employee, 'sanctum');

        $api->postJson('/api/v1/customers', ['name' => 'New', 'phone' => '0592222222', 'credit_limit' => '100.00'])
            ->assertForbidden()
            ->assertJsonPath('code', 'FORBIDDEN');
        $api->patchJson("/api/v1/customers/{$customer->id}", ['credit_limit' => '100.00'])->assertForbidden();
        $api->patchJson("/api/v1/customers/{$customer->id}", ['credit_limit' => null])->assertForbidden();
        $this->assertNull($customer->fresh()->credit_limit);
        $this->assertDatabaseMissing('customers', ['phone' => '0592222222']);

        $api->patchJson("/api/v1/customers/{$customer->id}", ['name' => 'Renamed'])
            ->assertOk()
            ->assertJsonPath('data.credit_limit', null);
        $api->postJson('/api/v1/customers', ['name' => 'Walk-in regular', 'phone' => '0593333333'])->assertCreated();
    }

    /** TC-0305-02 + AC2: no limit by default, and null removes an existing limit. */
    public function test_null_means_no_limit(): void
    {
        $store = $this->makeStore();
        $owner = $this->makeUser($store);
        $api = $this->actingAs($owner, 'sanctum');

        $id = $api->postJson('/api/v1/customers', ['name' => 'No limit', 'phone' => '0594444444'])
            ->assertCreated()
            ->assertJsonPath('customer.credit_limit', null)
            ->json('customer.id');

        $api->patchJson("/api/v1/customers/{$id}", ['credit_limit' => '200.00'])->assertJsonPath('data.credit_limit', '200.00');
        $api->patchJson("/api/v1/customers/{$id}", ['credit_limit' => null])->assertOk()->assertJsonPath('data.credit_limit', null);
        $this->assertDatabaseHas('customers', ['id' => $id, 'credit_limit' => null]);
    }

    public function test_credit_limit_validation(): void
    {
        $store = $this->makeStore();
        $owner = $this->makeUser($store);
        $customer = $this->makeCustomer($store);
        $api = $this->actingAs($owner, 'sanctum');

        foreach (['-1', '1.234', 'abc', '100000000'] as $value) {
            $api->patchJson("/api/v1/customers/{$customer->id}", ['credit_limit' => $value])
                ->assertUnprocessable()
                ->assertJsonPath('code', 'VALIDATION_FAILED')
                ->assertJsonValidationErrors('credit_limit');
        }

        // Zero is a real limit (no credit at all), distinct from null.
        $api->patchJson("/api/v1/customers/{$customer->id}", ['credit_limit' => '0'])->assertOk()->assertJsonPath('data.credit_limit', '0.00');
    }
}
