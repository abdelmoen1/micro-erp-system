<?php

namespace Tests\Feature;

use App\Models\AuditLog;
use App\Models\Product;
use App\Models\StockMovement;
use App\Models\Store;
use App\Models\User;
use App\Support\Quantity;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Support\BuildsShopData;
use Tests\TestCase;

/** US-0402 stock movements and controlled adjustments (TC-0402-01 … 04). */
class StockAdjustmentTest extends TestCase
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

    /** Created through the API so the `opening` movement exists, as in production. */
    private function product(int $openingStock = 10, array $overrides = []): Product
    {
        $id = $this->actingAs($this->owner, 'sanctum')->postJson('/api/v1/products', $overrides + [
            'name' => 'Rice 1kg',
            'selling_price' => '8.00',
            'current_stock' => $openingStock,
        ])->assertCreated()->json('product.id');

        return Product::findOrFail($id);
    }

    private function adjust(User $user, Product $product, int $quantity, ?string $reason = 'Shelf count')
    {
        return $this->actingAs($user, 'sanctum')->postJson('/api/v1/stock-adjustments', array_filter([
            'product_id' => $product->id,
            'quantity' => $quantity,
            'reason' => $reason,
        ], fn($value) => $value !== null), $this->idem());
    }

    private function assertInvariant(Product $product): void
    {
        $product->refresh();
        $this->assertSame($product->current_stock, Quantity::of($product->movements()->sum('quantity')), 'current_stock = Σ movements');
        $this->assertSame($product->current_stock, $product->movements()->orderByDesc('id')->first()->balance_after);
    }

    /** TC-0402-01 + AC1: +/- adjustments create a movement and an audit entry, and update stock. */
    public function test_adjustment_records_movement_audit_and_stock(): void
    {
        $product = $this->product(10);

        $this->adjust($this->owner, $product, 5, 'Delivery counted')
            ->assertCreated()
            ->assertJsonPath('movement.type', 'adjustment_in')
            ->assertJsonPath('movement.quantity', '5')
            ->assertJsonPath('movement.balance_after', '15')
            ->assertJsonPath('movement.reason', 'Delivery counted')
            ->assertJsonPath('movement.created_by', $this->owner->id)
            ->assertJsonPath('product.current_stock', '15');

        $this->adjust($this->owner, $product, -4, 'Broken bottles')
            ->assertCreated()
            ->assertJsonPath('movement.type', 'adjustment_out')
            ->assertJsonPath('movement.quantity', '-4')
            ->assertJsonPath('product.current_stock', '11');

        $this->assertSame('11.000', $product->fresh()->current_stock);
        $this->assertInvariant($product);

        $logs = AuditLog::where('action', 'stock.adjusted')->orderBy('id')->get();
        $this->assertCount(2, $logs);
        $this->assertSame('Product', $logs[1]->entity_type);
        $this->assertSame((string) $product->id, $logs[1]->entity_id);
        $this->assertSame('-4', $logs[1]->metadata['quantity']);
        $this->assertSame('15', $logs[1]->metadata['balance_before']);
        $this->assertSame('11', $logs[1]->metadata['balance_after']);
        $this->assertSame('Broken bottles', $logs[1]->metadata['reason']);
    }

    /** AC1: the reason is required; quantity is a non-zero integer (CR-13). */
    public function test_adjustment_validation(): void
    {
        $product = $this->product(10);

        $this->adjust($this->owner, $product, 3, null)->assertUnprocessable()->assertJsonValidationErrors('reason');
        $this->adjust($this->owner, $product, 0)->assertUnprocessable()->assertJsonValidationErrors('quantity');

        $api = $this->actingAs($this->owner, 'sanctum');
        $api->postJson('/api/v1/stock-adjustments', ['product_id' => $product->id, 'quantity' => 1.5, 'reason' => 'x'], $this->idem())
            ->assertUnprocessable()->assertJsonValidationErrors('quantity');
        $api->postJson('/api/v1/stock-adjustments', ['quantity' => 1, 'reason' => 'x'], $this->idem())
            ->assertUnprocessable()->assertJsonValidationErrors('product_id');

        $this->assertSame(1, StockMovement::count());
        $this->assertSame(0, AuditLog::count());
    }

    /** TC-0402-02 + AC2: never below zero; nothing is written. Exactly zero is allowed. */
    public function test_adjustment_cannot_make_stock_negative(): void
    {
        $product = $this->product(3);

        $this->adjust($this->owner, $product, -4)
            ->assertUnprocessable()
            ->assertJsonPath('code', 'INSUFFICIENT_STOCK')
            ->assertJsonStructure(['errors' => ['quantity']]);

        $this->assertSame('3.000', $product->fresh()->current_stock);
        $this->assertSame(1, StockMovement::count());
        $this->assertSame(0, AuditLog::count());

        $this->adjust($this->owner, $product, -3)->assertCreated()->assertJsonPath('product.current_stock', '0');
        $this->assertInvariant($product);
    }

    /** TC-0402-03 + AC3: after any sequence of changes, current_stock = Σ movements. */
    public function test_stock_invariant_holds_over_a_sequence_of_adjustments(): void
    {
        $product = $this->product(7);
        $expected = 7;

        foreach ([5, -2, -10, 1, -11, 20, -1] as $quantity) {
            $response = $this->adjust($this->owner, $product, $quantity);
            if ($expected + $quantity < 0) {
                $response->assertUnprocessable()->assertJsonPath('code', 'INSUFFICIENT_STOCK');
            } else {
                $response->assertCreated();
                $expected += $quantity;
            }
            $this->assertSame(Quantity::of($expected), $product->fresh()->current_stock);
            $this->assertInvariant($product);
        }

        $this->artisan('hisbah:verify-stock')->assertExitCode(0);
    }

    /** TC-0402-04 + AC4: employees cannot adjust; managers can. */
    public function test_employee_cannot_adjust_stock(): void
    {
        $product = $this->product(10);
        $employee = $this->makeUser($this->store, 'employee');
        $manager = $this->makeUser($this->store, 'manager');

        $this->adjust($employee, $product, -1)->assertForbidden()->assertJsonPath('code', 'FORBIDDEN');
        $this->assertSame('10.000', $product->fresh()->current_stock);

        $this->adjust($manager, $product, -1)->assertCreated();
        $this->assertSame('9.000', $product->fresh()->current_stock);
    }

    /** 05 §2: stock adjustments need an Idempotency-Key. */
    public function test_adjustment_requires_an_idempotency_key(): void
    {
        $product = $this->product(10);

        $this->actingAs($this->owner, 'sanctum')
            ->postJson('/api/v1/stock-adjustments', ['product_id' => $product->id, 'quantity' => 1, 'reason' => 'x'])
            ->assertStatus(428)
            ->assertJsonPath('code', 'IDEMPOTENCY_KEY_REQUIRED');
    }

    /** Store isolation: another store's product id is rejected and left untouched. */
    public function test_cannot_adjust_another_stores_product(): void
    {
        $theirs = $this->makeProduct($this->makeStore('Theirs'), ['current_stock' => 10]);

        $this->adjust($this->owner, $theirs, -1)->assertUnprocessable()->assertJsonValidationErrors('product_id');
        $this->assertSame('10.000', $theirs->fresh()->current_stock);
    }

    /** GET /products/{id}/movements: the ledger, newest first, readable by every role. */
    public function test_movement_history_is_listed_newest_first(): void
    {
        $product = $this->product(10);
        $this->adjust($this->owner, $product, 2);
        $this->adjust($this->owner, $product, -5);
        $employee = $this->makeUser($this->store, 'employee');

        $data = $this->actingAs($employee, 'sanctum')
            ->getJson("/api/v1/products/{$product->id}/movements")
            ->assertOk()
            ->json('data');

        $this->assertSame(['adjustment_out', 'adjustment_in', 'opening'], array_column($data, 'type'));
        $this->assertSame(['-5', '2', '10'], array_column($data, 'quantity'));
        $this->assertSame(['7', '12', '10'], array_column($data, 'balance_after'));
    }

    /** T-0402-4: the verify command reports drift and fails. */
    public function test_verify_stock_command_reports_drift(): void
    {
        $product = $this->product(10);
        $this->artisan('hisbah:verify-stock')->assertExitCode(0);

        // Simulate a direct write that bypassed StockService.
        Product::whereKey($product->id)->update(['current_stock' => 12]);

        $this->artisan('hisbah:verify-stock')
            ->expectsOutputToContain('1 product(s) drift')
            ->assertExitCode(1);
        $this->artisan('hisbah:verify-stock', ['--store' => $this->makeStore('Empty')->id])->assertExitCode(0);
    }
}
