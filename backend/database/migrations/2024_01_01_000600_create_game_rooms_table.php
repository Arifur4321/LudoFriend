<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('game_rooms', function (Blueprint $table) {
            $table->id();
            $table->string('code', 8)->unique();
            $table->foreignId('host_user_id')->constrained('users')->cascadeOnDelete();
            $table->enum('mode', ['2p', '4p'])->default('4p');
            $table->enum('visibility', ['public', 'private'])->default('private')->index();
            $table->boolean('bot_fill')->default(false);
            $table->unsignedSmallInteger('turn_timer_seconds')->default(20);
            $table->enum('status', ['lobby', 'in_progress', 'finished', 'cancelled'])
                ->default('lobby')->index();
            $table->json('settings')->nullable();
            $table->timestamps();

            $table->index(['status', 'visibility']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('game_rooms');
    }
};
