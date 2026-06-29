<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('match_events', function (Blueprint $table) {
            $table->id();
            $table->foreignId('match_id')->constrained('matches')->cascadeOnDelete();
            // Monotonic per-match sequence number. The unique constraint below
            // is the anti-replay / ordering guarantee: a duplicate or
            // out-of-order seq is rejected at the database level.
            $table->unsignedInteger('seq');
            $table->enum('actor_color', ['red', 'green', 'yellow', 'blue'])->nullable();
            $table->string('type'); // dice_rolled|token_moved|captured|turn_changed|...
            $table->json('payload')->nullable();
            $table->timestamp('server_time')->useCurrent();
            $table->timestamps();

            $table->unique(['match_id', 'seq']);
            $table->index(['match_id', 'type']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('match_events');
    }
};
