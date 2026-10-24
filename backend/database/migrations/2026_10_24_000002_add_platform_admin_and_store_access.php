<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Platform owner dashboard.
 *
 * `users.is_platform_admin` marks the platform owner. It is never mass-assignable and no API route
 * sets it; only `php artisan hisbah:platform-admin` grants it.
 *
 * Stores get two independent states: account access (`status`: active | suspended, enforced at
 * login and on every store route) and the subscription (`subscription_status`: active | inactive,
 * with its dates). The subscription is recorded here but not enforced; the trial and billing
 * lifecycle will add values (e.g. `trial`) to the same 16-character column.
 *
 * Existing stores stay active; their subscription starts as inactive because no payment has been
 * verified yet. Nothing is deleted or rewritten.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->boolean('is_platform_admin')->default(false);
        });

        Schema::table('stores', function (Blueprint $table) {
            $table->string('status', 16)->default('active')->index();
            $table->string('suspension_reason', 500)->nullable();
            $table->timestamp('status_changed_at')->nullable();
            $table->foreignId('status_changed_by')->nullable()->constrained('users')->nullOnDelete();

            $table->string('subscription_status', 16)->default('inactive')->index();
            $table->timestamp('subscription_started_at')->nullable();
            $table->timestamp('subscription_expires_at')->nullable();
            $table->timestamp('subscription_changed_at')->nullable();
            $table->foreignId('subscription_changed_by')->nullable()->constrained('users')->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('stores', function (Blueprint $table) {
            $table->dropConstrainedForeignId('subscription_changed_by');
            $table->dropConstrainedForeignId('status_changed_by');
            $table->dropIndex(['status']);
            $table->dropIndex(['subscription_status']);
            $table->dropColumn([
                'status',
                'suspension_reason',
                'status_changed_at',
                'subscription_status',
                'subscription_started_at',
                'subscription_expires_at',
                'subscription_changed_at',
            ]);
        });

        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn('is_platform_admin');
        });
    }
};
