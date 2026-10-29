<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * R2 offline sync (US-1101, D-03, doc 16 §4). `sync_conflicts` keeps every offline item a manager
 * must look at: a flagged sale (recorded), a held payment (not applied) or a rejected item (not
 * applied). Nothing an offline device sent is ever discarded (BR-10). `synced_at` marks rows that
 * arrived through the sync, whose `created_at` / `paid_at` is the time they happened (BR-08).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('sync_conflicts', function (Blueprint $table) {
            $table->id();
            $table->foreignId('store_id')->constrained()->cascadeOnDelete();
            $table->string('device_id', 64)->nullable();
            $table->uuid('client_transaction_id');
            $table->unsignedBigInteger('seq')->nullable();
            $table->string('type', 20);
            $table->string('kind', 20);
            $table->timestamp('occurred_at')->nullable();
            $table->foreignId('user_id')->nullable()->constrained()->nullOnDelete();
            $table->foreignId('customer_id')->nullable()->constrained()->nullOnDelete();
            $table->foreignId('invoice_id')->nullable()->constrained()->nullOnDelete();
            $table->decimal('amount', 12, 2)->nullable();
            $table->json('payload');
            $table->json('flags')->nullable();
            $table->string('reason', 64);
            $table->text('message')->nullable();
            $table->string('status', 20)->default('open');
            $table->string('resolution', 20)->nullable();
            $table->text('resolution_note')->nullable();
            $table->foreignId('resolved_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('resolved_at')->nullable();
            $table->timestamps();

            $table->unique(['store_id', 'client_transaction_id']);
            $table->index(['store_id', 'status', 'created_at']);
        });

        Schema::table('invoices', function (Blueprint $table) {
            $table->timestamp('synced_at')->nullable();
            $table->string('device_id', 64)->nullable();
        });

        Schema::table('payments', function (Blueprint $table) {
            $table->timestamp('synced_at')->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('payments', fn(Blueprint $table) => $table->dropColumn('synced_at'));
        Schema::table('invoices', fn(Blueprint $table) => $table->dropColumn(['synced_at', 'device_id']));
        Schema::dropIfExists('sync_conflicts');
    }
};
