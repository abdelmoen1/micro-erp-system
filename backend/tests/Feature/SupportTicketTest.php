<?php

namespace Tests\Feature;

use App\Models\Store;
use App\Models\SupportTicket;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Support\BuildsShopData;
use Tests\TestCase;

class SupportTicketTest extends TestCase
{
    use BuildsShopData;
    use RefreshDatabase;

    private function makeAdmin(): User
    {
        $admin = $this->makeUser($this->makeStore('Hisbah HQ'), 'owner');
        $admin->forceFill(['is_platform_admin' => true])->save();

        return $admin;
    }

    private function complaint(array $overrides = []): array
    {
        return [
            'type' => 'technical',
            'subject' => 'الطابعة لا تطبع الإيصال',
            'details' => 'بعد البيع تظهر رسالة خطأ ولا يخرج شيء من الطابعة.',
            ...$overrides,
        ];
    }

    public function test_a_store_user_sends_a_complaint_and_sees_it_with_its_status(): void
    {
        $store = $this->makeStore('Shop');
        $owner = $this->makeUser($store);

        $this->actingAs($owner, 'sanctum')
            ->postJson('/api/v1/support-tickets', $this->complaint())
            ->assertCreated()
            ->assertJsonPath('data.status', 'open')
            ->assertJsonPath('data.subject', 'الطابعة لا تطبع الإيصال');

        $this->actingAs($owner, 'sanctum')
            ->getJson('/api/v1/support-tickets')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.user.name', $owner->name);
    }

    public function test_the_type_subject_and_details_are_required_with_arabic_messages(): void
    {
        $owner = $this->makeUser($this->makeStore('Shop'));

        $this->actingAs($owner, 'sanctum')
            ->postJson('/api/v1/support-tickets', ['type' => 'nonsense'])
            ->assertStatus(422)
            ->assertJsonPath('errors.type.0', 'نوع الدعم غير صحيح.')
            ->assertJsonPath('errors.subject.0', 'اكتب موضوع المشكلة.')
            ->assertJsonPath('errors.details.0', 'اكتب تفاصيل المشكلة.');
    }

    public function test_an_expired_store_can_still_ask_for_help(): void
    {
        $store = $this->makeStore('Shop');
        $store->forceFill(['trial_ends_at' => now()->subDay(), 'subscription_expires_at' => null])->save();
        $owner = $this->makeUser($store);

        $this->actingAs($owner, 'sanctum')->getJson('/api/v1/dashboard')->assertForbidden();
        $this->actingAs($owner, 'sanctum')->postJson('/api/v1/support-tickets', $this->complaint(['type' => 'account']))->assertCreated();
    }

    public function test_stores_never_see_each_others_complaints_and_an_employee_sees_only_theirs(): void
    {
        $shop = $this->makeStore('Shop');
        $owner = $this->makeUser($shop);
        $employee = $this->makeUser($shop, 'employee');
        $other = $this->makeUser($this->makeStore('Other'));

        $this->actingAs($owner, 'sanctum')->postJson('/api/v1/support-tickets', $this->complaint());
        $this->actingAs($employee, 'sanctum')->postJson('/api/v1/support-tickets', $this->complaint(['subject' => 'من الموظف']));
        $this->actingAs($other, 'sanctum')->postJson('/api/v1/support-tickets', $this->complaint(['subject' => 'متجر آخر']));

        $this->actingAs($owner, 'sanctum')->getJson('/api/v1/support-tickets')->assertJsonCount(2, 'data');
        $this->actingAs($employee, 'sanctum')->getJson('/api/v1/support-tickets')
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.subject', 'من الموظف');
        $this->actingAs($other, 'sanctum')->getJson('/api/v1/support-tickets')->assertJsonCount(1, 'data');
    }

    public function test_the_admin_lists_every_store_and_replies_and_the_store_sees_the_reply(): void
    {
        $owner = $this->makeUser($this->makeStore('Shop'));
        $this->actingAs($owner, 'sanctum')->postJson('/api/v1/support-tickets', $this->complaint());
        $ticket = SupportTicket::sole();
        $admin = $this->makeAdmin();

        $this->actingAs($admin, 'sanctum')
            ->getJson('/api/v1/admin/support-tickets?status=open')
            ->assertOk()
            ->assertJsonPath('meta.open_count', 1)
            ->assertJsonPath('data.0.store.name', 'Shop')
            ->assertJsonPath('data.0.user.phone', $owner->phone);

        $this->actingAs($admin, 'sanctum')
            ->patchJson("/api/v1/admin/support-tickets/{$ticket->id}", ['status' => 'closed', 'reply' => 'حدّث التطبيق ثم أعد المحاولة.'])
            ->assertOk()
            ->assertJsonPath('data.status', 'closed');

        $this->assertDatabaseHas('audit_logs', ['action' => 'support_ticket.updated', 'store_id' => $owner->store_id]);
        $this->actingAs($owner, 'sanctum')
            ->getJson('/api/v1/support-tickets')
            ->assertJsonPath('data.0.reply', 'حدّث التطبيق ثم أعد المحاولة.')
            ->assertJsonPath('data.0.status', 'closed');
        $this->assertNotNull($ticket->fresh()->replied_at);
    }

    public function test_store_members_cannot_answer_complaints(): void
    {
        $owner = $this->makeUser($this->makeStore('Shop'));
        $this->actingAs($owner, 'sanctum')->postJson('/api/v1/support-tickets', $this->complaint());

        $this->actingAs($owner, 'sanctum')
            ->patchJson('/api/v1/admin/support-tickets/' . SupportTicket::sole()->id, ['status' => 'closed'])
            ->assertForbidden();
    }

    public function test_deleting_a_store_removes_its_complaints(): void
    {
        $store = $this->makeStore('Shop');
        $owner = $this->makeUser($store);
        $this->actingAs($owner, 'sanctum')->postJson('/api/v1/support-tickets', $this->complaint());

        app(\App\Services\StoreDeletionService::class)->delete(Store::find($store->id), $this->makeAdmin());

        $this->assertSame(0, SupportTicket::count());
    }
}
