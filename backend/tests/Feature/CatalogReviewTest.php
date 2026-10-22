<?php

namespace Tests\Feature;

use App\Models\Product;
use App\Models\Store;
use App\Models\User;
use App\Services\SaleService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Tests\Support\BuildsShopData;
use Tests\TestCase;

/** W-08 stock filters, D-27 negative-stock review, US-0408 CSV import, US-0801 v2, DEF-19. */
class CatalogReviewTest extends TestCase
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

    public function test_stock_filters_and_negative_review_name_the_causing_sales(): void
    {
        $this->makeProduct($this->store, ['name' => 'Plenty', 'current_stock' => 50]);
        $this->makeProduct($this->store, ['name' => 'Low', 'current_stock' => 2]);
        $oil = $this->makeProduct($this->store, ['name' => 'Oil', 'current_stock' => 1]);
        $sale = app(SaleService::class)->create($this->owner, ['items' => [['product_id' => $oil->id, 'quantity' => 3]], 'paid_amount' => '30.00', 'payment_method' => 'cash'])['invoice'];

        $this->actingAs($this->owner, 'sanctum')->getJson('/api/v1/products?stock=low')
            ->assertOk()->assertJsonCount(2, 'data');
        $this->actingAs($this->owner, 'sanctum')->getJson('/api/v1/products?stock=negative')
            ->assertOk()->assertJsonCount(1, 'data')->assertJsonPath('data.0.name', 'Oil');

        $this->actingAs($this->owner, 'sanctum')->getJson('/api/v1/products/negative-stock')
            ->assertOk()
            ->assertJsonPath('data.0.product.id', $oil->id)
            ->assertJsonPath('data.0.sales.0.invoice_id', $sale->id)
            ->assertJsonPath('data.0.sales.0.quantity', '3')
            ->assertJsonPath('data.0.sales.0.balance_after', '-2')
            ->assertJsonPath('data.0.sales.0.created_by', $this->owner->name);
    }

    public function test_csv_with_errors_imports_nothing_and_lists_row_errors(): void
    {
        $this->makeProduct($this->store, ['barcode' => '6291041500213']);
        $csv = "name,barcode,unit,selling_price,current_stock\n"
            . "Tea,111,piece,6.50,10\n"
            . "Almonds,6291041500213,kg,60,1.5\n"
            . "Rice,,piece,28,2.5\n"
            . "Milk,111,piece,,4\n";

        $this->import($csv, dryRun: true)
            ->assertStatus(422)
            ->assertJsonPath('code', 'IMPORT_INVALID')
            ->assertJsonPath('details.rows', 4)
            ->assertJsonPath('details.invalid_rows', 3)
            ->assertJsonFragment(['row' => 3, 'column' => 'barcode'])
            ->assertJsonFragment(['row' => 4, 'column' => 'current_stock'])
            ->assertJsonFragment(['row' => 5, 'column' => 'selling_price']);

        $this->assertSame(1, Product::count());
    }

    public function test_clean_csv_dry_runs_then_imports_atomically_with_opening_stock(): void
    {
        $csv = "\xEF\xBB\xBFname,barcode,unit,selling_price,cost_price,current_stock,minimum_stock\n"
            . "Tea,111,piece,6.50,4,10,3\n"
            . "Almonds,,kg,60.00,,1.250,2\n";

        $this->import($csv, dryRun: true)->assertOk()->assertJsonPath('data.rows', 2)->assertJsonPath('data.kg', 1);
        $this->assertSame(0, Product::count());

        $this->import($csv)->assertCreated()->assertJsonPath('data.imported', 2);
        $almonds = Product::where('name', 'Almonds')->sole();
        $this->assertSame('kg', $almonds->unit);
        $this->assertSame('1.250', $almonds->current_stock);
        $this->assertDatabaseHas('stock_movements', ['product_id' => $almonds->id, 'type' => 'opening']);

        $employee = $this->makeUser($this->store, 'employee');
        $this->app['auth']->forgetGuards();
        $this->actingAs($employee, 'sanctum')->post('/api/v1/products/import', ['file' => $this->csvFile($csv)], ['Accept' => 'application/json'])
            ->assertForbidden();
    }

    /** US-0801: collections split, insights and the AC5 new-debt rule. */
    public function test_dashboard_v2_collections_and_insights(): void
    {
        $customer = $this->makeCustomer($this->store);
        $sales = app(SaleService::class);
        $product = $this->makeProduct($this->store, ['selling_price' => '50.00', 'current_stock' => 3, 'minimum_stock' => 5]);
        $sale = $sales->create($this->owner, ['customer_id' => $customer->id, 'items' => [['product_id' => $product->id, 'quantity' => 2]], 'paid_amount' => '30.00', 'payment_method' => 'cash'])['invoice'];
        $voided = $sales->create($this->owner, ['customer_id' => $customer->id, 'items' => [['product_id' => $product->id, 'quantity' => 1]], 'paid_amount' => '0'])['invoice'];
        $sales->void($this->owner, $voided, 'Mistake');
        $sale->debt->update(['due_date' => now()->subDays(3)->toDateString()]);
        $this->actingAs($this->owner, 'sanctum')->postJson('/api/v1/payments', ['debt_id' => $sale->debt->id, 'amount' => '20.00', 'method' => 'cash'], $this->idem())->assertCreated();

        $this->actingAs($this->owner, 'sanctum')->getJson('/api/v1/dashboard?period=today')
            ->assertOk()
            ->assertJsonPath('data.collections.at_sale', '30.00')
            ->assertJsonPath('data.collections.debt_repayments', '20.00')
            ->assertJsonPath('data.collections.total', '50.00')
            ->assertJsonPath('data.summary.new_debt', '70.00')
            ->assertJsonPath('data.summary.low_stock_count', 1)
            ->assertJsonPath('data.insights.overdue.count', 1)
            ->assertJsonPath('data.insights.overdue.amount', '50.00')
            ->assertJsonPath('data.insights.top_balances.0.total_remaining', '50.00')
            ->assertJsonPath('data.insights.low_stock.items.0.id', $product->id)
            ->assertJsonPath('data.returns.count', 0);
    }

    /** DEF-19: framework validation messages come back in Arabic. */
    public function test_framework_validation_messages_are_arabic(): void
    {
        $this->actingAs($this->owner, 'sanctum')->getJson('/api/v1/sales?type=gift')
            ->assertStatus(422)
            ->assertJsonPath('errors.type.0', 'القيمة المحددة لـ النوع غير صحيحة.');

        $this->actingAs($this->owner, 'sanctum')->getJson('/api/v1/debts?per_page=500')
            ->assertStatus(422)
            ->assertJsonPath('errors.per_page.0', 'يجب ألا يتجاوز عدد العناصر في الصفحة 50.');
    }

    private function import(string $csv, bool $dryRun = false)
    {
        $response = $this->actingAs($this->owner, 'sanctum')->post('/api/v1/products/import', [
            'file' => $this->csvFile($csv),
            'dry_run' => $dryRun ? '1' : '0',
        ], ['Accept' => 'application/json']);
        $this->app['auth']->forgetGuards();

        return $response;
    }

    private function csvFile(string $csv): UploadedFile
    {
        return UploadedFile::fake()->createWithContent('products.csv', $csv);
    }
}
