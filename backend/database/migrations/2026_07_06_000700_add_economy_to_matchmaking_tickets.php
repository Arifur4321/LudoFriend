<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/** Tier-aware quick match: pair only players who chose the same board. */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('matchmaking_tickets', function (Blueprint $table) {
            $table->string('board_tier', 32)->default('classic')->after('mode')->index();
            $table->unsignedInteger('stake')->default(0)->after('board_tier');
        });
    }

    public function down(): void
    {
        Schema::table('matchmaking_tickets', function (Blueprint $table) {
            $table->dropColumn(['board_tier', 'stake']);
        });
    }
};
