<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Replace the unique(user_id, status) index on matchmaking_tickets with a plain
 * lookup index.
 *
 * The unique constraint made a user's ticket history one-row-per-status, which:
 *   - blocked re-queueing after a finished game (an old 'matched' row lingered
 *     and a new 'matched' collided), and
 *   - threw on a second cancel (two 'cancelled' rows collided).
 *
 * "One active ticket per user" is now enforced in MatchmakingService (a locked
 * read of the user's tickets inside the enqueue transaction), which correctly
 * allows historical cancelled/matched rows to accumulate.
 */
return new class extends Migration
{
    public function up(): void
    {
        // Add the replacement index FIRST: the unique(user_id, status) index is
        // what the user_id foreign key relies on, and MySQL refuses to drop an
        // index still needed by a constraint (errno 1553). The new composite
        // index also leads with user_id, so it satisfies the FK before the drop.
        Schema::table('matchmaking_tickets', function (Blueprint $table) {
            $table->index(['user_id', 'status'], 'matchmaking_tickets_user_status_idx');
        });

        Schema::table('matchmaking_tickets', function (Blueprint $table) {
            $table->dropUnique(['user_id', 'status']);
        });
    }

    public function down(): void
    {
        Schema::table('matchmaking_tickets', function (Blueprint $table) {
            $table->unique(['user_id', 'status']);
        });

        Schema::table('matchmaking_tickets', function (Blueprint $table) {
            $table->dropIndex('matchmaking_tickets_user_status_idx');
        });
    }
};
