<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('match_players', function (Blueprint $table) {
            $table->id();
            $table->foreignId('match_id')->constrained('matches')->cascadeOnDelete();
            $table->foreignId('user_id')->nullable()->constrained('users')->nullOnDelete();
            $table->enum('color', ['red', 'green', 'yellow', 'blue']);
            $table->unsignedTinyInteger('seat');
            $table->boolean('is_bot')->default(false);
            // Final placement: 1 = winner, 2..4 = order finished / forfeited.
            $table->unsignedTinyInteger('placement')->nullable();
            $table->timestamp('disconnected_at')->nullable();
            $table->timestamp('reconnected_at')->nullable();
            $table->timestamps();

            $table->unique(['match_id', 'color']);
            $table->unique(['match_id', 'seat']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('match_players');
    }
};
