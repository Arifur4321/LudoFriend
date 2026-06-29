<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // A player's place in the matchmaking queue for a given mode.
        Schema::create('matchmaking_tickets', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->enum('mode', ['2p', '4p'])->index();
            $table->enum('status', ['queued', 'matched', 'cancelled', 'expired'])
                ->default('queued')->index();
            $table->foreignId('room_id')->nullable()->constrained('game_rooms')->nullOnDelete();
            $table->unsignedInteger('rating')->default(1000);
            $table->timestamp('enqueued_at')->useCurrent();
            $table->timestamps();

            // A user can only hold one active ticket at a time (enforced in service
            // too, but this index speeds up the lookup).
            $table->index(['mode', 'status', 'enqueued_at']);
            $table->unique(['user_id', 'status']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('matchmaking_tickets');
    }
};
