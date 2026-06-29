<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('game_room_players', function (Blueprint $table) {
            $table->id();
            $table->foreignId('room_id')->constrained('game_rooms')->cascadeOnDelete();
            // Nullable for bot seats.
            $table->foreignId('user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->unsignedTinyInteger('seat'); // 0..3
            $table->enum('color', ['red', 'green', 'yellow', 'blue']);
            $table->boolean('is_bot')->default(false);
            $table->boolean('is_ready')->default(false);
            $table->timestamp('joined_at')->nullable();
            $table->timestamps();

            // No duplicate seats or colors within a room.
            $table->unique(['room_id', 'seat']);
            $table->unique(['room_id', 'color']);
            // A human can only occupy one seat per room.
            $table->unique(['room_id', 'user_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('game_room_players');
    }
};
