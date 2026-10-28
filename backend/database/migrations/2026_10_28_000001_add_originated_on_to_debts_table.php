<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Legacy debts from the mobile app: the day an old debt started (before the shop used Hisbah).
 * Nullable, so every existing debt keeps working unchanged; created_at stays the day it was recorded.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('debts', function (Blueprint $table) {
            $table->date('originated_on')->nullable()->after('due_date');
        });
    }

    public function down(): void
    {
        Schema::table('debts', function (Blueprint $table) {
            $table->dropColumn('originated_on');
        });
    }
};
