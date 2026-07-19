<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Widen guest_sessions.token so the opaque guest re-auth secret always fits.
 *
 * Root cause of the "guests cannot create a private room" report: the column
 * was VARCHAR(80) but the value was being stored via an `encrypted` cast, which
 * produced a ~250-char blob and overflowed the column on MySQL
 * (SQLSTATE[22001] "Data too long for column 'token'"). The guest-login INSERT
 * then 500'd, the client fell back to a token-less local guest, and the next
 * authenticated call (create room) failed for lack of a bearer token.
 *
 * The `encrypted` cast is removed in the model (the token is an opaque random
 * secret that is only ever written, never read — re-auth is by device_id), and
 * this migration gives the column comfortable, index-safe headroom.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('guest_sessions', function (Blueprint $table) {
            // Keep the existing unique index; only widen the column.
            $table->string('token', 128)->change();
        });
    }

    public function down(): void
    {
        Schema::table('guest_sessions', function (Blueprint $table) {
            $table->string('token', 80)->change();
        });
    }
};
