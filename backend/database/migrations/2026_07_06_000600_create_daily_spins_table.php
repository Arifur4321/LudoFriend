<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * One row per claimed free spin. Spins are gated by a rolling cooldown
 * (config economy.free_spin.interval_minutes, default 60), enforced in
 * FreeSpinService by locking the player's wallet row and checking the most
 * recent spin's timestamp — so there is no fixed-window uniqueness here.
 * `spun_at` (indexed with user_id) drives both the cooldown and the countdown.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('daily_spins', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->string('day_key', 10)->nullable(); // informational (date)
            $table->unsignedInteger('reward');         // coins awarded
            $table->unsignedTinyInteger('segment_index')->nullable();
            $table->timestamp('spun_at');
            $table->timestamps();

            // Fast "most recent spin for this user" lookup for the cooldown.
            $table->index(['user_id', 'spun_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('daily_spins');
    }
};
