<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Leaderboard rows: one per (user, period). Recomputed by the
        // RecalculateLeaderboard job.
        Schema::create('player_stats', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->enum('period', ['all_time', 'weekly'])->default('all_time')->index();
            $table->unsignedInteger('wins')->default(0);
            $table->unsignedInteger('games')->default(0);
            $table->integer('rating')->default(1000);
            $table->unsignedInteger('rank')->nullable()->index();
            $table->timestamps();

            $table->unique(['user_id', 'period']);
            $table->index(['period', 'rating']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('player_stats');
    }
};
