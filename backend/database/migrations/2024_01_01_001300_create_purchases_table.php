<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('purchases', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->string('product_id')->index();
            $table->enum('platform', ['ios', 'android', 'web'])->index();
            // Store receipt / purchase token for server-side verification later.
            $table->text('receipt')->nullable();
            $table->enum('status', ['pending', 'verified', 'refunded', 'failed'])
                ->default('pending')->index();
            $table->json('meta')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('purchases');
    }
};
