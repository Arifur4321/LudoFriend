<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('match_states', function (Blueprint $table) {
            $table->id();
            $table->foreignId('match_id')->constrained('matches')->cascadeOnDelete();
            // Optimistic-concurrency version; increments on every applied move.
            $table->unsignedInteger('version')->default(0);
            // Authoritative snapshot: token map, current turn, dice state,
            // consecutive sixes, winner, etc. (see GameEngineService).
            $table->json('state');
            $table->timestamp('updated_at')->nullable();
            $table->timestamp('created_at')->nullable();

            // Exactly one current snapshot per match.
            $table->unique('match_id');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('match_states');
    }
};
