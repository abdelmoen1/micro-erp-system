<?php

namespace Tests\Feature;

use App\Models\Product;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Support\BuildsShopData;
use Tests\TestCase;

/** US-0403 low-stock detection (TC-0403-01 … 03). */
class LowStockTest extends TestCase
{
    use BuildsShopData;
    use RefreshDatabase;

    /** TC-0403-01 + AC1: without a configured threshold, 5 applies. */
    public function test_default_threshold_is_five(): void
    {
        $store = $this->makeStore();
        $owner = $this->makeUser($store);
        $api = $this->actingAs($owner, 'sanctum');

        foreach (['At five' => 5, 'Above' => 6] as $name => $stock) {
            $api->postJson('/api/v1/products', ['name' => $name, 'selling_price' => '1.00', 'current_stock' => $stock])
                ->assertCreated()
                ->assertJsonPath('product.minimum_stock', '5')
                ->assertJsonPath('product.is_low_stock', $stock <= 5);
        }

        $this->assertSame(['At five'], array_column($api->getJson('/api/v1/products/low-stock')->assertOk()->json('data'), 'name'));
    }

    /** TC-0403-02 + AC2: a custom threshold is used instead of 5. */
    public function test_custom_threshold_is_used(): void
    {
        $store = $this->makeStore();
        $owner = $this->makeUser($store);
        $this->makeProduct($store, ['name' => 'Custom 20', 'current_stock' => 15, 'minimum_stock' => 20]);
        $this->makeProduct($store, ['name' => 'Custom 0', 'current_stock' => 1, 'minimum_stock' => 0]);
        $this->makeProduct($store, ['name' => 'Empty, threshold 0', 'current_stock' => 0, 'minimum_stock' => 0]);

        $names = array_column($this->actingAs($owner, 'sanctum')->getJson('/api/v1/products/low-stock')->json('data'), 'name');

        $this->assertSame(['Empty, threshold 0', 'Custom 20'], $names);
    }

    /** TC-0403-03 + AC3: active products of my store at or below threshold, lowest stock first. */
    public function test_listing_is_active_store_scoped_and_lowest_first(): void
    {
        $store = $this->makeStore();
        $employee = $this->makeUser($store, 'employee');
        $this->makeProduct($store, ['name' => 'Three', 'current_stock' => 3]);
        $this->makeProduct($store, ['name' => 'Zero', 'current_stock' => 0]);
        $this->makeProduct($store, ['name' => 'Five', 'current_stock' => 5]);
        $this->makeProduct($store, ['name' => 'Also three', 'current_stock' => 3]);
        $this->makeProduct($store, ['name' => 'Plenty', 'current_stock' => 50]);
        $this->makeProduct($store, ['name' => 'Inactive', 'current_stock' => 0, 'status' => Product::STATUS_INACTIVE]);
        $this->makeProduct($this->makeStore('Theirs'), ['name' => 'Theirs', 'current_stock' => 0]);

        $data = $this->actingAs($employee, 'sanctum')->getJson('/api/v1/products/low-stock')->assertOk()->json('data');

        $this->assertSame(['Zero', 'Also three', 'Three', 'Five'], array_column($data, 'name'));
        $this->assertSame(['0', '3', '3', '5'], array_column($data, 'current_stock'));
        $this->assertTrue(collect($data)->every(fn($row) => $row['is_low_stock'] === true));
    }
}
