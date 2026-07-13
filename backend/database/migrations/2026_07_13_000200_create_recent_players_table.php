<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Directed "recently played with" pairs, written when a match completes.
     *
     * Both directions are stored (A→B and B→A) so "my recent players" is a
     * single indexed lookup. This intentionally does NOT touch friend_links:
     * the app's own friendship system stays the primary friend store, and
     * recent players are a parallel, lighter-weight list used for rematches
     * and room invites.
     */
    public function up(): void
    {
        Schema::create('recent_players', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('other_user_id')->constrained('users')->cascadeOnDelete();
            $table->unsignedInteger('games')->default(1);
            $table->foreignId('last_match_id')->nullable()->constrained('matches')->nullOnDelete();
            $table->timestamp('last_played_at');
            $table->timestamps();

            $table->unique(['user_id', 'other_user_id']);
            $table->index(['user_id', 'last_played_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('recent_players');
    }
};
