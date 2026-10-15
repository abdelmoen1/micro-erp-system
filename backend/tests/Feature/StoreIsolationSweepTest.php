<?php

namespace Tests\Feature;

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
        $theirStaff = $this->makeUser($theirs, 'employee');
        $customer = $this->makeCustomer($theirs);
        $invoice = $this->makeCreditInvoice($theirs, $customer);
        $group = (string) Str::uuid();
        $payment = $invoice->debt->payments()->create([
            'amount' => '10.00', 'method' => 'cash', 'paid_at' => now(), 'payment_group_id' => $group,
        ]);

        return [
            'customer' => $customer->id,
            'invoice' => $invoice->id,
            'debt' => $invoice->debt->id,
            'payment' => $payment->id,
            'paymentGroupId' => $group,
            'user' => $theirStaff->id,
        ];
    }

    private function body(string $method): array
    {
        return in_array($method, ['POST', 'PUT', 'PATCH'], true)
            ? ['name' => 'x', 'amount' => '1.00', 'reason' => 'x', 'method' => 'cash', 'role' => 'manager']
            : [];
    }
}
