<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('matches', function (Blueprint $table) {
            $table->id();
            $table->foreignId('room_id')->nullable()->constrained('game_rooms')->nullOnDelete();
            $table->enum('mode', ['2p', '4p'])->default('4p');
            $table->enum('status', ['active', 'finished', 'abandoned'])->default('active')->index();
            $table->foreignId('winner_user_id')->nullable()->constrained('users')->nullOnDelete();
            // Frozen copy of the rule config used for this match (audit/replay).
            $table->json('rule_config')->nullable();
            // Deterministic seed for dice RNG so replays reproduce exactly.
            $table->unsignedBigInteger('seed');
            $table->timestamp('started_at')->nullable();
            $table->timestamp('ended_at')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('matches');
    }
};
