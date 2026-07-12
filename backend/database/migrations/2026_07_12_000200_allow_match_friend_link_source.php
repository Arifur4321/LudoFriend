<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('friend_links', function (Blueprint $table) {
            $table->enum('source', ['facebook', 'code', 'link', 'match'])
                ->default('code')
                ->change();
        });
    }

    public function down(): void
    {
        DB::table('friend_links')->where('source', 'match')->update(['source' => 'code']);

        Schema::table('friend_links', function (Blueprint $table) {
            $table->enum('source', ['facebook', 'code', 'link'])
                ->default('code')
                ->change();
        });
    }
};
