<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Public 2v2 team matchmaking: a separate queue dimension so team tickets are
 * only ever paired with other team tickets — never mixed with free-for-all, and
 * never bot-filled. Free-for-all tickets keep team_mode = false (the default),
 * so existing behaviour is unchanged.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('matchmaking_tickets', function (Blueprint $table) {
            $table->boolean('team_mode')->default(false)->after('mode')->index();
        });
    }

    public function down(): void
    {
        Schema::table('matchmaking_tickets', function (Blueprint $table) {
            $table->dropColumn('team_mode');
        });
    }
};
