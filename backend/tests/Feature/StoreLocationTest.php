<?php

namespace Tests\Feature;

use App\Models\Store;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Routing\Middleware\ThrottleRequests;
use Illuminate\Support\Facades\DB;
use ReflectionMethod;
use Tests\Support\BuildsShopData;
use Tests\TestCase;

/**
 * Store location (area + map coordinates): set at registration or by the owner, visible only to
 * the store's own members and the platform admin, and backfilled from the registration address.
 */
class StoreLocationTest extends TestCase
{
    use BuildsShopData;
    use RefreshDatabase;

    private function registration(array $overrides = []): array
    {
        return $overrides + [
            'store_name' => 'بقالة الأمانة',
            'owner_name' => 'علي أحمد',
            'owner_phone' => '0599000031',
            'email' => 'ali@shop.ps',
            'password' => 'Secret-pass-2026',
            'password_confirmation' => 'Secret-pass-2026',
            'address' => 'شارع عمر المختار، غزة',
            'area' => 'غزة',
            'latitude' => 31.515239,
            'longitude' => 34.453186,
        ];
    }

    private function makeAdmin(): User
    {
        $admin = $this->makeUser($this->makeStore('Hisbah HQ'), 'owner');
        $admin->forceFill(['is_platform_admin' => true])->save();

        return $admin;
    }

    public function test_registration_saves_the_area_and_coordinates(): void
    {
        $this->postJson('/api/v1/register', $this->registration())
            ->assertCreated()
            ->assertJsonPath('user.store.area', 'غزة')
            ->assertJsonPath('user.store.latitude', 31.515239)
            ->assertJsonPath('user.store.longitude', 34.453186);

        $store = Store::sole();
        $this->assertSame(['شارع عمر المختار، غزة', 'غزة', 31.515239, 34.453186], [$store->address, $store->area, $store->latitude, $store->longitude]);
    }

    public function test_location_is_optional_and_coordinates_come_as_a_valid_pair(): void
    {
        // Six registrations from one IP: past the 5/min limit, which AuthHardeningTest covers.
        $this->withoutMiddleware(ThrottleRequests::class);

        $this->postJson('/api/v1/register', $this->registration(['email' => 'a@shop.ps', 'area' => null, 'latitude' => null, 'longitude' => null]))
            ->assertCreated()
            ->assertJsonPath('user.store.latitude', null);

        $invalid = [
            'latitude without longitude' => [['latitude' => 31.5, 'longitude' => null], 'longitude', 'أدخل خط الطول مع خط العرض.'],
            'latitude out of range' => [['latitude' => 91, 'longitude' => 34.4], 'latitude', 'خط العرض يجب أن يكون بين ‎-90 و 90.'],
            'longitude out of range' => [['latitude' => 31.5, 'longitude' => -181], 'longitude', 'خط الطول يجب أن يكون بين ‎-180 و 180.'],
            'too precise' => [['latitude' => 31.1234567, 'longitude' => 34.4], 'latitude', 'خط العرض: 6 منازل عشرية كحد أقصى.'],
            'not a number' => [['latitude' => 'north', 'longitude' => 34.4], 'latitude', 'خط العرض يجب أن يكون رقماً.'],
        ];
        foreach ($invalid as [$fields, $field, $message]) {
            $this->postJson('/api/v1/register', $this->registration(['email' => "x{$field}@shop.ps"] + $fields))
                ->assertUnprocessable()
                ->assertJsonValidationErrors([$field => $message], 'errors');
        }

        $this->assertSame(1, Store::count(), 'No invalid registration created a store.');
    }

    public function test_only_the_owner_updates_the_location_of_their_own_store(): void
    {
        $store = $this->makeStore('Shop', ['timezone' => 'Asia/Hebron']);
        $owner = $this->makeUser($store, 'owner');
        $manager = $this->makeUser($store, 'manager');
        $other = $this->makeStore('Other', ['area' => 'رفح']);

        $this->actingAs($owner, 'sanctum')
            ->patchJson('/api/v1/my-store', ['area' => 'خان يونس', 'latitude' => 31.3462, 'longitude' => 34.3063, 'address' => 'السوق الرئيسي، خان يونس'])
            ->assertOk()
            ->assertJsonPath('store.area', 'خان يونس')
            ->assertJsonPath('store.latitude', 31.3462);

        $store->refresh();
        $this->assertSame(['خان يونس', 31.3462, 34.3063, 'Asia/Hebron'], [$store->area, $store->latitude, $store->longitude, $store->timezone], 'Fields not sent keep their value.');

        // Clearing the coordinates sends both as null.
        $this->actingAs($owner, 'sanctum')->patchJson('/api/v1/my-store', ['latitude' => null, 'longitude' => null])->assertOk();
        $this->assertNull($store->fresh()->latitude);

        $this->actingAs($manager, 'sanctum')->patchJson('/api/v1/my-store', ['area' => 'غزة'])->assertForbidden();
        $this->assertSame('خان يونس', $store->fresh()->area);
        $this->assertSame('رفح', $other->fresh()->area, 'Another store is never reachable through /my-store.');
    }

    public function test_location_is_visible_only_to_the_stores_members_and_the_platform_admin(): void
    {
        $gaza = $this->makeStore('Gaza shop', ['area' => 'غزة', 'latitude' => 31.5, 'longitude' => 34.46]);
        $rafah = $this->makeStore('Rafah shop', ['area' => 'رفح', 'latitude' => 31.29, 'longitude' => 34.25]);
        $gazaEmployee = $this->makeUser($gaza, 'employee');
        $rafahOwner = $this->makeUser($rafah, 'owner');
        $admin = $this->makeAdmin();

        $this->actingAs($gazaEmployee, 'sanctum')->getJson('/api/v1/my-store')
            ->assertOk()
            ->assertJsonPath('store.area', 'غزة')
            ->assertJsonPath('store.latitude', 31.5);
        $mine = $this->actingAs($rafahOwner, 'sanctum')->getJson('/api/v1/me')->assertOk();
        $mine->assertJsonPath('user.store.area', 'رفح');
        $this->assertStringNotContainsString('31.5', $mine->getContent(), 'Another store\'s coordinates never appear.');

        foreach (["/api/v1/admin/stores/{$gaza->id}", '/api/v1/admin/stores?area=' . urlencode('غزة')] as $uri) {
            $this->actingAs($rafahOwner, 'sanctum')->getJson($uri)->assertForbidden();
        }
        $this->app['auth']->forgetGuards();
        $this->getJson("/api/v1/admin/stores/{$gaza->id}")->assertUnauthorized();

        $this->actingAs($admin, 'sanctum')->getJson("/api/v1/admin/stores/{$gaza->id}")
            ->assertOk()
            ->assertJsonPath('data.area', 'غزة')
            ->assertJsonPath('data.latitude', 31.5)
            ->assertJsonPath('data.longitude', 34.46);
        $this->actingAs($admin, 'sanctum')->getJson('/api/v1/admin/stores?area=' . urlencode('رفح'))
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', $rafah->id);
        $this->actingAs($admin, 'sanctum')->getJson('/api/v1/admin/stores?search=' . urlencode('رفح'))
            ->assertJsonPath('data.0.id', $rafah->id);
    }

    public function test_migration_backfills_the_area_only_from_an_exact_registration_city(): void
    {
        $cases = [
            'شارع عمر المختار، غزة' => 'غزة',
            'حي النصر ، شمال غزة' => 'شمال غزة',
            'دوار النجمة، رفح' => 'رفح',
            'غزة' => null, // the city alone: not the "street، city" shape the forms wrote
            'شارع، مدينة أخرى' => null,
            'Omar Mukhtar St, Gaza' => null,
            'غزة، الرمال' => null, // the city first: unknown shape, left to the owner
        ];
        $ids = [];
        foreach (array_keys($cases) as $i => $address) {
            $ids[$address] = $this->makeStore("Store {$i}", ['address' => $address])->id;
        }
        $kept = $this->makeStore('Already set', ['address' => 'شارع، غزة', 'area' => 'دير البلح']);
        $none = $this->makeStore('No address');

        $migration = require database_path('migrations/2026_10_26_000001_add_location_to_stores_table.php');
        (new ReflectionMethod($migration, 'backfill'))->invoke($migration);

        foreach ($cases as $address => $area) {
            $row = DB::table('stores')->find($ids[$address]);
            $this->assertSame($area, $row->area, $address);
            $this->assertSame($address, $row->address, 'The address is never changed.');
            $this->assertNull($row->latitude);
        }
        $this->assertSame('دير البلح', $kept->fresh()->area, 'An area already set is kept.');
        $this->assertNull($none->fresh()->area);
    }
}
