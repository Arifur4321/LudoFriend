<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('friend_links', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('friend_user_id')->constrained('users')->cascadeOnDelete();
            $table->enum('source', ['facebook', 'code', 'link'])->default('code');
            $table->enum('status', ['pending', 'accepted', 'blocked'])->default('pending')->index();
            $table->timestamps();

            // A directed friendship pair is unique.
            $table->unique(['user_id', 'friend_user_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('friend_links');
    }
};
