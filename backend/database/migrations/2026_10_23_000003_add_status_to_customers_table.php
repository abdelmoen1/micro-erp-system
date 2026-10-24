<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/** US-0301 AC4 (FR-11): an inactive customer is hidden from new sales but keeps all history. */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('customers', function (Blueprint $table) {
            $table->string('status', 16)->default('active')->after('credit_limit');
            $table->index(['store_id', 'status']);
        });
    }

    public function down(): void
    {
        Schema::table('customers', function (Blueprint $table) {
            $table->dropIndex(['store_id', 'status']);
            $table->dropColumn('status');
        });
    }
};
