<?php

namespace Tests\Feature;

use App\Models\SyncConflict;
use App\Models\ReceivingAccount;
use App\Models\SuspendedInvoice;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Routing\Route as RouteDefinition;
use Illuminate\Support\Facades\Route;
use Illuminate\Support\Str;
use Tests\Support\BuildsShopData;
use Tests\TestCase;

/**
 * TC-0108-02: every /api/v1 route with a resource parameter returns 404 when
 * called with another store's identifier. New parameters must be added to
 * foreignIds(), or this test fails.
 */
class StoreIsolationSweepTest extends TestCase
{
    use BuildsShopData;
    use RefreshDatabase;

    public function test_every_parameterised_route_hides_other_stores_records(): void
    {
        $mine = $this->makeStore('Mine');
        $owner = $this->makeUser($mine, 'owner');

        $foreignIds = $this->foreignIds();

        $routes = collect(Route::getRoutes()->getRoutes())
            ->filter(fn(RouteDefinition $route) => str_starts_with($route->uri(), 'api/v1/'))
            ->filter(fn(RouteDefinition $route) => count($route->parameterNames()) > 0)
            // Platform admin routes span stores by design; a store owner gets 403 there (PlatformAdminTest).
            ->reject(fn(RouteDefinition $route) => str_starts_with($route->uri(), 'api/v1/admin/'))
            ->values();

        $this->assertNotEmpty($routes);
        $checked = 0;

        foreach ($routes as $route) {
            foreach (array_diff($route->methods(), ['HEAD']) as $method) {
                $uri = $route->uri();
                foreach ($route->parameterNames() as $name) {
                    $this->assertArrayHasKey($name, $foreignIds, "No foreign fixture for route parameter {{$name}} ({$uri}).");
                    $uri = str_replace('{' . $name . '}', (string) $foreignIds[$name], $uri);
                }

                $response = $this->actingAs($owner, 'sanctum')->json($method, '/' . $uri, $this->body($method), $this->idem());

                $this->assertSame(404, $response->getStatusCode(), "{$method} /{$route->uri()} leaked another store's record: " . $response->getContent());
                $checked++;
            }
        }

        $this->assertGreaterThanOrEqual(15, $checked);
    }

    /** Identifiers belonging to another store, keyed by route parameter name. */
    private function foreignIds(): array
    {
        $theirs = $this->makeStore('Theirs');
        $theirSupplier = \App\Models\Supplier::create(['store_id' => $theirs->id, 'name' => 'Theirs']);
        $theirStaff = $this->makeUser($theirs, 'employee');
        $customer = $this->makeCustomer($theirs);
        $invoice = $this->makeCreditInvoice($theirs, $customer);
        $group = (string) Str::uuid();
        $payment = $invoice->debt->payments()->create([
            'amount' => '10.00', 'method' => 'cash', 'paid_at' => now(), 'payment_group_id' => $group,
        ]);
        $account = ReceivingAccount::create([
            'store_id' => $theirs->id,
            'provider' => 'palpay',
            'account_name' => 'Foreign',
            'account_identifier' => '0000',
            'active' => true,
        ]);
        $suspended = SuspendedInvoice::create([
            'store_id' => $theirs->id,
            'reference' => 'FOREIGN-' . Str::uuid(),
            'cashier_id' => $theirStaff->id,
            'status' => SuspendedInvoice::STATUS_PENDING_TRANSFER,
            'subtotal' => '10.00',
            'discount_amount' => '0.00',
            'total_amount' => '10.00',
            'payment_method' => 'palpay',
            'receiving_account_id' => $account->id,
        ]);

        return [
            // Public, not store data: an unknown deletion reference and a provider that is not enabled are 404 too.
            'reference' => (string) Str::uuid(),
            'provider' => 'palpay',
            'customer' => $customer->id,
            'invoice' => $invoice->id,
            'debt' => $invoice->debt->id,
            'payment' => $payment->id,
            'account' => $account->id,
            'paymentGroupId' => $group,
            'user' => $theirStaff->id,
            'product' => $this->makeProduct($theirs)->id,
            'supplier' => $theirSupplier->id,
            'purchaseInvoice' => $theirSupplier->invoices()->create(['store_id' => $theirs->id, 'total' => '10.00'])->id,
            'conflict' => SyncConflict::create([
                'store_id' => $theirs->id,
                'client_transaction_id' => (string) Str::uuid(),
                'type' => 'payment',
                'kind' => SyncConflict::KIND_CONFLICT,
                'payload' => [],
                'reason' => 'PAYMENT_EXCEEDS_REMAINING',
            ])->id,
        ];
    }

    private function body(string $method): array
    {
        return in_array($method, ['POST', 'PUT', 'PATCH'], true)
            ? ['name' => 'x', 'amount' => '1.00', 'reason' => 'x', 'method' => 'cash', 'role' => 'manager']
            : [];
    }
}
