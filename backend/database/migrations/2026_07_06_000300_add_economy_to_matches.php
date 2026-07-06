<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Escrow + payout fields on a match. `stake` is the per-seat buy-in, `pot`
 * is the total escrowed at start, both frozen for audit. `team_mode` mirrors
 * the room. `ended_reason` records finished|abandoned cause. Aborted matches
 * use the existing 'abandoned' status and are refunded from the ledger.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('matches', function (Blueprint $table) {
            $table->string('board_tier', 32)->nullable()->after('mode');
            $table->unsignedInteger('stake')->default(0)->after('board_tier');
            $table->unsignedBigInteger('pot')->default(0)->after('stake');
            $table->boolean('team_mode')->default(false)->after('pot');
            $table->string('ended_reason', 32)->nullable()->after('status');
        });
    }

    public function down(): void
    {
        Schema::table('matches', function (Blueprint $table) {
            $table->dropColumn(['board_tier', 'stake', 'pot', 'team_mode', 'ended_reason']);
        });
    }
};
