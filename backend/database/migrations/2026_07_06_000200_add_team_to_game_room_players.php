<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/** Team index (0/1) for 2v2 lobbies; null for free-for-all. */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('game_room_players', function (Blueprint $table) {
            $table->unsignedTinyInteger('team')->nullable()->after('color');
        });
    }

    public function down(): void
    {
        Schema::table('game_room_players', function (Blueprint $table) {
            $table->dropColumn('team');
        });
    }
};
