<?php

namespace Tests\Feature;

use App\Models\Product;
use App\Models\Store;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Support\BuildsShopData;
use Tests\TestCase;

/**
 * CR-13 (modified 2026-10-19, doc 15 §4): products sold by the piece or by the kg; decimal
 * quantities through the product API, stock adjustments and low-stock detection.
 */
class WeighedProductTest extends TestCase
{
    use BuildsShopData;
    use RefreshDatabase;

    private Store $store;
    private User $owner;

    protected function setUp(): void
    {
        parent::setUp();
        $this->store = $this->makeStore();
        $this->owner = $this->makeUser($this->store);
    }

    public function test_kg_product_keeps_grams_and_piece_is_the_default(): void
    {
        $this->create(['unit' => 'kg', 'current_stock' => '2.500', 'minimum_stock' => '0.750'])
            ->assertCreated()
            ->assertJsonPath('product.unit', 'kg')
            ->assertJsonPath('product.current_stock', '2.500')
            ->assertJsonPath('product.minimum_stock', '0.750')
            ->assertJsonPath('product.is_low_stock', false);

        $this->create(['barcode' => '7290000000002', 'current_stock' => 12])
            ->assertCreated()
            ->assertJsonPath('product.unit', 'piece')
            ->assertJsonPath('product.current_stock', '12');

        $kg = Product::where('unit', 'kg')->sole();
        $this->assertSame('2.500', $kg->current_stock);
        $this->assertSame('2.500', $kg->movements()->sole()->quantity);
    }

    public function test_quantities_must_fit_the_unit(): void
    {
        $this->create(['current_stock' => '2.5'])->assertUnprocessable()->assertJsonValidationErrors('current_stock');
        $this->create(['unit' => 'kg', 'current_stock' => '2.5005'])->assertUnprocessable()->assertJsonValidationErrors('current_stock');
        $this->create(['unit' => 'litre', 'current_stock' => '1'])->assertUnprocessable()->assertJsonValidationErrors('unit');
        $this->create(['unit' => 'kg', 'current_stock' => '1', 'minimum_stock' => '-1'])->assertUnprocessable()->assertJsonValidationErrors('minimum_stock');

        $this->assertSame(0, Product::count());
    }

    public function test_kg_stock_adjusts_by_the_gram(): void
    {
        $id = $this->create(['unit' => 'kg', 'current_stock' => '1.000'])->json('product.id');
        $piece = $this->makeProduct($this->store);

        $this->adjust($id, '-0.250')->assertCreated()
            ->assertJsonPath('movement.quantity', '-0.250')
            ->assertJsonPath('movement.balance_after', '0.750')
            ->assertJsonPath('product.current_stock', '0.750');
        $this->adjust($id, '-0.751')->assertUnprocessable()->assertJsonPath('code', 'INSUFFICIENT_STOCK');
        $this->adjust($id, '0.000')->assertUnprocessable()->assertJsonValidationErrors('quantity');
        $this->adjust($piece->id, '-0.5')->assertUnprocessable()->assertJsonValidationErrors('quantity');

        $this->actingAs($this->owner, 'sanctum')->getJson("/api/v1/products/{$id}/movements")->assertOk()
            ->assertJsonPath('data.0.quantity', '-0.250')
            ->assertJsonPath('data.1.quantity', '1.000');
        $this->artisan('hisbah:verify-stock')->assertExitCode(0);
    }

    public function test_unit_change_to_piece_needs_whole_stock(): void
    {
        $id = $this->create(['unit' => 'kg', 'current_stock' => '1.500'])->json('product.id');

        $this->updateProduct($id, ['unit' => 'piece'])->assertUnprocessable()->assertJsonValidationErrors('unit');

        $this->adjust($id, '0.500')->assertCreated();
        $this->updateProduct($id, ['unit' => 'piece'])->assertOk()
            ->assertJsonPath('data.unit', 'piece')
            ->assertJsonPath('data.current_stock', '2');
        $this->updateProduct($id, ['minimum_stock' => '1.5'])->assertUnprocessable()->assertJsonValidationErrors('minimum_stock');
    }

    public function test_low_stock_and_lookup_use_the_unit(): void
    {
        $this->create(['unit' => 'kg', 'barcode' => '2000000000017', 'current_stock' => '2.400', 'minimum_stock' => '2.500']);

        $this->actingAs($this->owner, 'sanctum')->getJson('/api/v1/products/low-stock')->assertOk()
            ->assertJsonPath('data.0.current_stock', '2.400')
            ->assertJsonPath('data.0.is_low_stock', true);
        $this->actingAs($this->owner, 'sanctum')->getJson('/api/v1/products/lookup?barcode=2000000000017')->assertOk()
            ->assertJsonPath('data.unit', 'kg')
            ->assertJsonPath('data.current_stock', '2.400');
    }

    private function create(array $overrides)
    {
        return $this->actingAs($this->owner, 'sanctum')->postJson('/api/v1/products', $overrides + [
            'name' => 'Almonds',
            'barcode' => '7299990000001',
            'selling_price' => '60.00',
        ]);
    }

    private function adjust(int $productId, string $quantity)
    {
        return $this->actingAs($this->owner, 'sanctum')->postJson('/api/v1/stock-adjustments', [
            'product_id' => $productId,
            'quantity' => $quantity,
            'reason' => 'Scale count',
        ], $this->idem());
    }

    private function updateProduct(int $productId, array $body)
    {
        return $this->actingAs($this->owner, 'sanctum')->patchJson("/api/v1/products/{$productId}", $body);
    }
}
