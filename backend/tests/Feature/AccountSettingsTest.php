<?php

namespace Tests\Feature;

use App\Models\AuditLog;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\Support\BuildsShopData;
use Tests\TestCase;

/** The «More» screens of the mobile app: the owner edits the store, anyone changes their password. */
class AccountSettingsTest extends TestCase
{
    use BuildsShopData;
    use RefreshDatabase;

    public function test_a_password_change_needs_the_current_one_and_signs_out_the_other_devices(): void
    {
        $user = $this->makeUser($this->makeStore(), 'employee');
        $phone = $user->createToken('phone')->plainTextToken;
        $laptop = $user->createToken('laptop')->plainTextToken;

        $this->withToken($phone)->patchJson('/api/v1/me/password', [
            'current_password' => 'wrong-one',
            'password' => 'New-pass-2026',
            'password_confirmation' => 'New-pass-2026',
        ])->assertUnprocessable()->assertJsonPath('errors.current_password.0', 'كلمة المرور الحالية غير صحيحة.');

        $this->withToken($phone)->patchJson('/api/v1/me/password', [
            'current_password' => 'password',
            'password' => 'New-pass-2026',
            'password_confirmation' => 'Other-2026',
        ])->assertUnprocessable()->assertJsonPath('errors.password.0', 'تأكيد كلمة المرور لا يطابقها.');

        $this->withToken($phone)->patchJson('/api/v1/me/password', [
            'current_password' => 'password',
            'password' => 'New-pass-2026',
            'password_confirmation' => 'New-pass-2026',
        ])->assertOk();

        $this->assertTrue(Hash::check('New-pass-2026', $user->refresh()->password));
        $this->assertSame(['phone'], $user->tokens()->pluck('name')->all(), 'this session stays; the laptop is signed out');
        $this->assertSame(1, AuditLog::where('action', 'user.password_changed')->count());
        $this->app['auth']->forgetGuards();
        $this->withToken($laptop)->getJson('/api/v1/me')->assertUnauthorized();
        $this->postJson('/api/v1/login', ['login' => $user->phone, 'password' => 'New-pass-2026'])->assertOk();
    }

    public function test_an_account_without_a_password_cannot_set_one_here(): void
    {
        $user = $this->makeUser($this->makeStore(), 'owner');
        $user->forceFill(['password' => null])->save();

        $this->actingAs($user)->patchJson('/api/v1/me/password', [
            'current_password' => 'anything',
            'password' => 'New-pass-2026',
            'password_confirmation' => 'New-pass-2026',
        ])->assertUnprocessable()->assertJsonPath('errors.current_password.0', 'هذا الحساب ليس له كلمة مرور لتغييرها. استعمل «نسيت كلمة المرور».');

        $this->assertNull($user->refresh()->password);
    }

    public function test_the_owner_edits_the_store_name_and_phone_printed_on_receipts(): void
    {
        $store = $this->makeStore('بقالة الأمانة');
        $owner = $this->makeUser($store, 'owner');

        $this->actingAs($owner)->patchJson('/api/v1/my-store', ['name' => 'بقالة الأمانة الجديدة', 'phone' => '0599123456', 'address' => 'شارع الوحدة'])
            ->assertOk()
            ->assertJsonPath('store.name', 'بقالة الأمانة الجديدة')
            ->assertJsonPath('store.phone', '0599123456');

        $this->actingAs($owner)->patchJson('/api/v1/my-store', ['name' => '', 'phone' => '59912'])
            ->assertUnprocessable()
            ->assertJsonPath('errors.name.0', 'اكتب اسم المتجر.')
            ->assertJsonPath('errors.phone.0', 'رقم الهاتف 9 أو 10 أرقام ويبدأ بـ 0، مثل 0599123456.');

        // A landline (9 digits) is fine; clearing the phone is allowed.
        $this->actingAs($owner)->patchJson('/api/v1/my-store', ['phone' => '082834567'])->assertOk();
        $this->actingAs($owner)->patchJson('/api/v1/my-store', ['phone' => null])->assertOk()->assertJsonPath('store.phone', null);
        $this->assertSame('بقالة الأمانة الجديدة', $store->refresh()->name);
    }

    public function test_only_the_owner_edits_the_store(): void
    {
        $store = $this->makeStore('بقالة الأمانة');

        foreach (['manager', 'employee'] as $role) {
            $this->actingAs($this->makeUser($store, $role))->patchJson('/api/v1/my-store', ['name' => 'اسم آخر'])->assertForbidden();
        }
        $this->assertSame('بقالة الأمانة', $store->refresh()->name);
    }
}
