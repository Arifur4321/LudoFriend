<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/** Team index + per-seat escrow/payout audit on match seats. */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('match_players', function (Blueprint $table) {
            $table->unsignedTinyInteger('team')->nullable()->after('color');
            $table->unsignedInteger('stake_paid')->default(0)->after('placement');
            $table->unsignedBigInteger('payout')->default(0)->after('stake_paid');
        });
    }

    public function down(): void
    {
        Schema::table('match_players', function (Blueprint $table) {
            $table->dropColumn(['team', 'stake_paid', 'payout']);
        });
    }
};
