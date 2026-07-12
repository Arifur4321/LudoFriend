<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Chat idempotency: a client-generated id makes "send once" safe against
 * retries, rapid double-taps, and reconnect replays. The unique index means a
 * duplicate POST resolves to the same persisted row instead of a second one.
 * Additive and safe for existing data (nullable; existing rows keep NULL, and
 * MySQL/SQLite both allow multiple NULLs under a unique index).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('match_messages', function (Blueprint $table) {
            $table->string('client_id', 64)->nullable()->after('user_id');
            $table->unique(['match_id', 'client_id']);
        });
    }

    public function down(): void
    {
        Schema::table('match_messages', function (Blueprint $table) {
            $table->dropUnique(['match_id', 'client_id']);
            $table->dropColumn('client_id');
        });
    }
};
