<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Seven-day free trial. A new store gets trial_ends_at = its registration time + the trial length
 * (App\Models\Store sets it on creation). A store has access while it has a valid paid subscription
 * or its trial has not ended; the subscription columns themselves are unchanged.
 *
 * Existing stores were registered before any trial existed, so they get a full trial from the
 * moment this migration runs instead of being locked out at deploy. Nothing else is rewritten.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('stores', function (Blueprint $table) {
            $table->timestamp('trial_ends_at')->nullable()->index();
        });

        DB::table('stores')->whereNull('trial_ends_at')->update([
            'trial_ends_at' => now()->addDays((int) config('hisbah.trial_days', 7)),
        ]);
    }

    public function down(): void
    {
        Schema::table('stores', function (Blueprint $table) {
            $table->dropIndex(['trial_ends_at']);
            $table->dropColumn('trial_ends_at');
        });
    }
};
