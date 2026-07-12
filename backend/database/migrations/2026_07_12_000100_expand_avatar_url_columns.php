<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->text('avatar')->nullable()->change();
        });

        Schema::table('player_profiles', function (Blueprint $table) {
            $table->text('avatar')->nullable()->change();
        });

        Schema::table('social_accounts', function (Blueprint $table) {
            $table->text('avatar_url')->nullable()->change();
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->string('avatar')->nullable()->change();
        });

        Schema::table('player_profiles', function (Blueprint $table) {
            $table->string('avatar')->nullable()->change();
        });

        Schema::table('social_accounts', function (Blueprint $table) {
            $table->string('avatar_url')->nullable()->change();
        });
    }
};
