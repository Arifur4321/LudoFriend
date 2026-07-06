<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Economy fields on rooms: which staked board tier this lobby is playing,
 * the per-player stake (coins), and whether 4p is played as 2v2 teams.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('game_rooms', function (Blueprint $table) {
            $table->string('board_tier', 32)->default('classic')->after('mode')->index();
            $table->unsignedInteger('stake')->default(0)->after('board_tier');
            $table->boolean('team_mode')->default(false)->after('stake');
        });
    }

    public function down(): void
    {
        Schema::table('game_rooms', function (Blueprint $table) {
            $table->dropColumn(['board_tier', 'stake', 'team_mode']);
        });
    }
};
