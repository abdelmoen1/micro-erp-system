<?php

namespace Tests\Feature;

use App\Models\Product;
use App\Models\StockMovement;
use Illuminate\Foundation\Testing\RefreshDatabase;
use LogicException;
use Tests\Support\BuildsShopData;
use Tests\TestCase;

/** US-0401 product catalog with barcode lookup (TC-0401-01 … 06). */
class ProductCatalogTest extends TestCase
{
    use BuildsShopData;
    use RefreshDatabase;

    private function validProduct(array $overrides = []): array
    {
        return $overrides + [
            'name' => 'Milk 1L',
            'barcode' => '7290000000017',
            'selling_price' => '6.50',
            'cost_price' => '5.00',
            'current_stock' => 12,
        ];
    }

    /** TC-0401-01 + AC1: created with defaults and an `opening` movement; current_stock = Σ movements. */
    public function test_owner_creates_product_with_opening_movement(): void
    {
        $store = $this->makeStore();
        $owner = $this->makeUser($store);

        $response = $this->actingAs($owner, 'sanctum')->postJson('/api/v1/products', $this->validProduct())
            ->assertCreated()
            ->assertJsonPath('product.selling_price', '6.50')
            ->assertJsonPath('product.cost_price', '5.00')
            ->assertJsonPath('product.current_stock', 12)
            ->assertJsonPath('product.minimum_stock', 5)
            ->assertJsonPath('product.status', 'active');

        $product = Product::findOrFail($response->json('product.id'));
        $movement = $product->movements()->sole();
        $this->assertSame(StockMovement::TYPE_OPENING, $movement->type);
        $this->assertSame(12, $movement->quantity);
        $this->assertSame(12, $movement->balance_after);
        $this->assertSame($owner->id, (int) $movement->created_by);
        $this->assertSame($product->current_stock, (int) $product->movements()->sum('quantity'));
    }

    public function test_zero_opening_stock_still_records_the_opening_movement(): void
    {
        $owner = $this->makeUser($this->makeStore());

        $id = $this->actingAs($owner, 'sanctum')
            ->postJson('/api/v1/products', $this->validProduct(['current_stock' => 0, 'barcode' => null]))
            ->assertCreated()->json('product.id');

        $this->assertSame(0, Product::findOrFail($id)->movements()->sole()->quantity);
    }

    /** TC-0401-01: validation (price > 0 with 2 decimals, integer stock ≥ 0, required name). */
    public function test_validation_rejects_bad_product_data(): void
    {
        $owner = $this->makeUser($this->makeStore());
        $api = $this->actingAs($owner, 'sanctum');

        foreach ([
            'selling_price' => ['0', '-1', '1.234', 'abc'],
            'current_stock' => [-1, 1.5, 'x'],
            'name' => [''],
            'minimum_stock' => [-1],
        ] as $field => $values) {
            foreach ($values as $value) {
                $api->postJson('/api/v1/products', $this->validProduct([$field => $value]))
                    ->assertUnprocessable()
                    ->assertJsonPath('code', 'VALIDATION_FAILED')
                    ->assertJsonValidationErrors($field);
            }
        }

        $this->assertSame(0, Product::count());
        $this->assertSame(0, StockMovement::count());
    }

    /** TC-0401-02 + AC2: barcode unique per store; the same barcode is fine in another store. */
    public function test_barcode_is_unique_per_store(): void
    {
        $owner = $this->makeUser($this->makeStore('A'));
        $otherOwner = $this->makeUser($this->makeStore('B'));

        $this->actingAs($owner, 'sanctum')->postJson('/api/v1/products', $this->validProduct())->assertCreated();
        $this->actingAs($owner, 'sanctum')->postJson('/api/v1/products', $this->validProduct(['name' => 'Other']))
            ->assertUnprocessable()->assertJsonValidationErrors('barcode');
        $this->actingAs($otherOwner, 'sanctum')->postJson('/api/v1/products', $this->validProduct())->assertCreated();

        // Products without a barcode never collide.
        $this->actingAs($owner, 'sanctum')->postJson('/api/v1/products', $this->validProduct(['barcode' => null, 'name' => 'Bread']))->assertCreated();
        $this->actingAs($owner, 'sanctum')->postJson('/api/v1/products', $this->validProduct(['barcode' => '', 'name' => 'Eggs']))->assertCreated();
    }

    public function test_updating_a_product_keeps_its_own_barcode_but_not_anothers(): void
    {
        $store = $this->makeStore();
        $owner = $this->makeUser($store);
        $first = $this->makeProduct($store, ['barcode' => '111']);
        $this->makeProduct($store, ['barcode' => '222']);
        $api = $this->actingAs($owner, 'sanctum');

        $api->patchJson("/api/v1/products/{$first->id}", ['barcode' => '111', 'selling_price' => '9.99'])
            ->assertOk()->assertJsonPath('data.selling_price', '9.99');
        $api->patchJson("/api/v1/products/{$first->id}", ['barcode' => '222'])
            ->assertUnprocessable()->assertJsonValidationErrors('barcode');
    }

    /** Stock changes only through movements (adjustments are US-0402). */
    public function test_stock_cannot_be_edited_directly(): void
    {
        $store = $this->makeStore();
        $product = $this->makeProduct($store, ['current_stock' => 3]);

        $this->actingAs($this->makeUser($store), 'sanctum')
            ->patchJson("/api/v1/products/{$product->id}", ['current_stock' => 100])
            ->assertUnprocessable()->assertJsonValidationErrors('current_stock');

        $this->assertSame(3, $product->fresh()->current_stock);
    }

    /** TC-0401-03 + AC3: lookup returns the active product of my store, otherwise 404. */
    public function test_barcode_lookup(): void
    {
        $store = $this->makeStore();
        $employee = $this->makeUser($store, 'employee');
        $product = $this->makeProduct($store, ['barcode' => '7290000000017']);
        $this->makeProduct($this->makeStore('Other'), ['barcode' => '999']);
        $api = $this->actingAs($employee, 'sanctum');

        $api->getJson('/api/v1/products/lookup?barcode=7290000000017')
            ->assertOk()->assertJsonPath('data.id', $product->id)->assertJsonPath('data.selling_price', $product->selling_price);
        $api->getJson('/api/v1/products/lookup?barcode=0000')->assertNotFound()->assertJsonPath('code', 'NOT_FOUND');
        $api->getJson('/api/v1/products/lookup?barcode=999')->assertNotFound();
        $api->getJson('/api/v1/products/lookup')->assertUnprocessable()->assertJsonValidationErrors('barcode');

        $product->update(['status' => Product::STATUS_INACTIVE]);
        $api->getJson('/api/v1/products/lookup?barcode=7290000000017')->assertNotFound();
    }

    /** TC-0401-04 + AC4 / BR-04: no hard delete; deactivation hides the product from the POS list and lookup. */
    public function test_products_are_deactivated_never_deleted(): void
    {
        $store = $this->makeStore();
        $owner = $this->makeUser($store);
        $product = $this->makeProduct($store, ['name' => 'Rice', 'barcode' => '555']);
        $api = $this->actingAs($owner, 'sanctum');

        $api->deleteJson("/api/v1/products/{$product->id}")->assertStatus(405)->assertJsonPath('code', 'METHOD_NOT_ALLOWED');
        $this->assertNotNull($product->fresh());

        $api->postJson("/api/v1/products/{$product->id}/deactivate")->assertOk()->assertJsonPath('product.status', 'inactive');

        $this->assertSame([], $api->getJson('/api/v1/products')->json('data'));
        $this->assertSame([], $api->getJson('/api/v1/products?search=Rice')->json('data'));
        $this->assertCount(1, $api->getJson('/api/v1/products?status=inactive')->json('data'));
        $api->getJson('/api/v1/products/lookup?barcode=555')->assertNotFound();

        // FR-16: reactivation.
        $api->patchJson("/api/v1/products/{$product->id}", ['status' => 'active'])->assertOk()->assertJsonPath('data.status', 'active');
        $api->getJson('/api/v1/products/lookup?barcode=555')->assertOk();
    }

    /** TC-0401-05 + AC5: employees read but cannot create, update or deactivate. */
    public function test_employee_cannot_write_products(): void
    {
        $store = $this->makeStore();
        $employee = $this->makeUser($store, 'employee');
        $manager = $this->makeUser($store, 'manager');
        $product = $this->makeProduct($store);
        $api = $this->actingAs($employee, 'sanctum');

        $api->postJson('/api/v1/products', $this->validProduct())->assertForbidden()->assertJsonPath('code', 'FORBIDDEN');
        $api->patchJson("/api/v1/products/{$product->id}", ['name' => 'X'])->assertForbidden();
        $api->postJson("/api/v1/products/{$product->id}/deactivate")->assertForbidden();
        $api->getJson('/api/v1/products')->assertOk();
        $api->getJson("/api/v1/products/{$product->id}")->assertOk();

        $this->actingAs($manager, 'sanctum')->postJson('/api/v1/products', $this->validProduct())->assertCreated();
        $this->assertSame(2, Product::count());
    }

    /** TC-0401-06 + AC6: another store's product is 404 for every product route. */
    public function test_other_stores_products_are_not_found(): void
    {
        $owner = $this->makeUser($this->makeStore('Mine'));
        $theirs = $this->makeProduct($this->makeStore('Theirs'));
        $api = $this->actingAs($owner, 'sanctum');

        $api->getJson("/api/v1/products/{$theirs->id}")->assertNotFound();
        $api->patchJson("/api/v1/products/{$theirs->id}", ['name' => 'X'])->assertNotFound();
        $api->postJson("/api/v1/products/{$theirs->id}/deactivate")->assertNotFound();
        $this->assertSame([], $api->getJson('/api/v1/products')->json('data'));
        $this->assertSame('active', $theirs->fresh()->status);
    }

    public function test_search_matches_name_or_exact_barcode_within_the_store(): void
    {
        $store = $this->makeStore();
        $owner = $this->makeUser($store);
        $this->makeProduct($store, ['name' => 'Olive oil', 'barcode' => '123']);
        $this->makeProduct($store, ['name' => 'Sugar', 'barcode' => '456']);
        $api = $this->actingAs($owner, 'sanctum');

        $this->assertSame(['Olive oil'], array_column($api->getJson('/api/v1/products?search=olive')->json('data'), 'name'));
        $this->assertSame(['Sugar'], array_column($api->getJson('/api/v1/products?search=456')->json('data'), 'name'));
    }

    public function test_stock_movements_are_append_only(): void
    {
        $store = $this->makeStore();
        $owner = $this->makeUser($store);
        $id = $this->actingAs($owner, 'sanctum')->postJson('/api/v1/products', $this->validProduct())->json('product.id');
        $movement = Product::findOrFail($id)->movements()->sole();

        $this->expectException(LogicException::class);
        $movement->update(['quantity' => 99]);
    }
}
