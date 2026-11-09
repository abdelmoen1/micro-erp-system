<?php

use App\Support\PhoneNumber;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Store subscriptions sold on the website (docs/release-readiness/SUBSCRIPTION_ARCHITECTURE.md):
 * plans the platform admin manages, orders (manual WhatsApp or an online provider), immutable payment
 * rows and order history, one free trial per owner number, account deletion requests and a log of
 * platform-admin reads of store data.
 *
 * Plans are created inactive and without a price: the owner sets prices before anything can be ordered.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('subscription_plans', function (Blueprint $table) {
            $table->id();
            $table->string('code', 40)->unique();
            $table->string('name', 100);
            $table->text('description')->nullable();
            $table->unsignedSmallInteger('duration_months');
            // NULL until the owner sets it: a plan without a price can never be ordered.
            $table->decimal('price', 12, 2)->nullable();
            $table->char('currency', 3)->nullable();
            $table->json('features')->nullable();
            $table->json('limits')->nullable();
            $table->boolean('is_active')->default(false);
            $table->unsignedSmallInteger('sort_order')->default(0);
            $table->timestamps();
        });

        Schema::table('stores', function (Blueprint $table) {
            $table->foreignId('subscription_plan_id')->nullable()->constrained('subscription_plans')->nullOnDelete();
            $table->timestamp('trial_started_at')->nullable();
            // The expiry a reminder was last recorded for (hisbah:subscription-reminders), so it is sent once.
            $table->timestamp('expiry_notice_for')->nullable();
            // Owner asked to close the store: members are signed out; the data is deleted on this date.
            $table->timestamp('deletion_scheduled_for')->nullable()->index();
        });

        Schema::create('subscription_orders', function (Blueprint $table) {
            $table->id();
            $table->string('reference', 20)->unique();
            // Kept after a store is deleted: Hisbah's own sales record (store_name keeps who it was).
            $table->foreignId('store_id')->nullable()->constrained()->nullOnDelete();
            $table->string('store_name');
            $table->foreignId('requested_by')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignId('subscription_plan_id')->nullable()->constrained('subscription_plans')->nullOnDelete();
            $table->json('plan_snapshot');
            $table->unsignedSmallInteger('duration_months');
            $table->decimal('amount', 12, 2);
            $table->char('currency', 3);
            $table->string('channel', 20); // manual_whatsapp | online
            $table->string('provider', 30)->nullable();
            $table->string('provider_reference', 120)->nullable();
            $table->string('status', 30)->index();
            $table->foreignId('reviewed_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('reviewed_at')->nullable();
            $table->timestamp('paid_at')->nullable();
            $table->timestamp('activated_at')->nullable();
            $table->timestamp('period_starts_at')->nullable();
            $table->timestamp('period_ends_at')->nullable();
            $table->timestamps();

            $table->unique(['provider', 'provider_reference']);
            $table->index(['store_id', 'created_at']);
        });

        // Append-only: a confirmed payment, a refund or a reversal. Never card data.
        Schema::create('subscription_payments', function (Blueprint $table) {
            $table->id();
            $table->foreignId('subscription_order_id')->constrained()->restrictOnDelete();
            $table->string('kind', 20); // payment | refund | reversal
            $table->string('source', 20); // manual | provider
            $table->decimal('amount', 12, 2);
            $table->char('currency', 3);
            $table->string('method', 40);
            $table->string('transaction_reference', 120);
            $table->string('provider', 30)->nullable();
            $table->foreignId('recorded_by')->nullable()->constrained('users')->nullOnDelete();
            $table->dateTime('paid_at');
            $table->timestamp('created_at')->useCurrent();

            $table->unique(['source', 'provider', 'transaction_reference', 'kind'], 'subscription_payments_txn_unique');
        });

        // Append-only history of an order: who changed what, when, and internal notes.
        Schema::create('subscription_order_events', function (Blueprint $table) {
            $table->id();
            $table->foreignId('subscription_order_id')->constrained()->restrictOnDelete();
            $table->foreignId('actor_id')->nullable()->constrained('users')->nullOnDelete();
            $table->string('type', 30); // created | status | note | payment | activated | provider_event
            $table->string('from_status', 30)->nullable();
            $table->string('to_status', 30)->nullable();
            $table->text('note')->nullable();
            $table->json('data')->nullable();
            $table->timestamp('created_at')->useCurrent();
        });

        // One free trial per owner mobile number, kept after the store is deleted (abuse prevention).
        // Only an HMAC of the number is stored.
        Schema::create('trial_claims', function (Blueprint $table) {
            $table->id();
            $table->string('phone_hash', 64)->unique();
            $table->foreignId('store_id')->nullable()->constrained()->nullOnDelete();
            $table->dateTime('started_at');
            $table->dateTime('ends_at');
            $table->timestamp('created_at')->useCurrent();
        });

        Schema::create('account_deletion_requests', function (Blueprint $table) {
            $table->id();
            $table->uuid('reference')->unique();
            $table->foreignId('user_id')->nullable()->constrained()->nullOnDelete();
            $table->foreignId('store_id')->nullable()->constrained()->nullOnDelete();
            $table->string('type', 20); // staff | store
            $table->string('source', 20); // app | web | public
            $table->string('status', 20)->index(); // pending_review | scheduled | completed | cancelled | rejected
            // Masked only (e.g. 059****567): enough to answer the person, not to identify them again.
            $table->string('phone_masked', 20)->nullable();
            $table->string('store_name')->nullable();
            $table->text('reason')->nullable();
            $table->timestamp('scheduled_for')->nullable();
            $table->timestamp('completed_at')->nullable();
            $table->foreignId('processed_by')->nullable()->constrained('users')->nullOnDelete();
            $table->json('result')->nullable();
            $table->timestamps();
        });

        Schema::create('admin_access_logs', function (Blueprint $table) {
            $table->id();
            $table->foreignId('admin_id')->nullable()->constrained('users')->nullOnDelete();
            $table->string('method', 8);
            $table->string('path', 255);
            $table->unsignedBigInteger('target_store_id')->nullable()->index();
            $table->string('ip', 45)->nullable();
            $table->timestamp('created_at')->useCurrent()->index();
        });

        $now = now();
        $plans = [
            ['code' => 'monthly', 'name' => 'شهري', 'duration_months' => 1, 'sort_order' => 1],
            ['code' => 'semiannual', 'name' => 'نصف سنوي', 'duration_months' => 6, 'sort_order' => 2],
            ['code' => 'annual', 'name' => 'سنوي', 'duration_months' => 12, 'sort_order' => 3],
        ];
        foreach ($plans as $plan) {
            DB::table('subscription_plans')->insert($plan + [
                'description' => null,
                'price' => null,
                'currency' => null,
                'features' => null, // NULL = every feature (config hisbah.features)
                'limits' => null,   // NULL = no limits
                'is_active' => false,
                'created_at' => $now,
                'updated_at' => $now,
            ]);
        }

        // Existing stores: the trial started when the store was created; their owners' numbers have
        // used their one trial. No trial end date is changed.
        DB::table('stores')->whereNull('trial_started_at')->update(['trial_started_at' => DB::raw('created_at')]);
        $owners = DB::table('users')->join('stores', 'stores.id', '=', 'users.store_id')
            ->where('users.role', 'owner')->whereNotNull('users.phone')
            ->get(['users.phone', 'stores.id', 'stores.created_at', 'stores.trial_ends_at']);
        foreach ($owners as $owner) {
            $phone = PhoneNumber::normalize($owner->phone);
            if (!$phone) {
                continue;
            }
            DB::table('trial_claims')->insertOrIgnore([
                'phone_hash' => hash_hmac('sha256', $phone, (string) config('app.key')),
                'store_id' => $owner->id,
                'started_at' => $owner->created_at ?? $now,
                'ends_at' => $owner->trial_ends_at ?? $owner->created_at ?? $now,
                'created_at' => $now,
            ]);
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('admin_access_logs');
        Schema::dropIfExists('account_deletion_requests');
        Schema::dropIfExists('trial_claims');
        Schema::dropIfExists('subscription_order_events');
        Schema::dropIfExists('subscription_payments');
        Schema::dropIfExists('subscription_orders');
        Schema::table('stores', function (Blueprint $table) {
            $table->dropConstrainedForeignId('subscription_plan_id');
            $table->dropIndex(['deletion_scheduled_for']);
            $table->dropColumn(['trial_started_at', 'expiry_notice_for', 'deletion_scheduled_for']);
        });
        Schema::dropIfExists('subscription_plans');
    }
};
