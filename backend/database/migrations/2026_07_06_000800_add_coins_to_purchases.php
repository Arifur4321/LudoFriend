<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/** Coins granted by a verified coin-pack purchase + verification timestamp. */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('purchases', function (Blueprint $table) {
            $table->unsignedInteger('coins_awarded')->default(0)->after('status');
            $table->timestamp('verified_at')->nullable()->after('coins_awarded');
        });
    }

    public function down(): void
    {
        Schema::table('purchases', function (Blueprint $table) {
            $table->dropColumn(['coins_awarded', 'verified_at']);
        });
    }
};
