<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Persist a realistic per-seat display name for bot players so every device
 * shows the SAME name (and it stays stable across reconnect / state refresh).
 *
 * Nullable: human seats leave it null and keep deriving their name from the
 * linked user. Only bot seats populate it. No change to bot AI / turn logic.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('game_room_players', function (Blueprint $table) {
            $table->string('display_name', 40)->nullable()->after('is_bot');
        });

        Schema::table('match_players', function (Blueprint $table) {
            $table->string('display_name', 40)->nullable()->after('is_bot');
        });
    }

    public function down(): void
    {
        Schema::table('game_room_players', function (Blueprint $table) {
            $table->dropColumn('display_name');
        });

        Schema::table('match_players', function (Blueprint $table) {
            $table->dropColumn('display_name');
        });
    }
};
