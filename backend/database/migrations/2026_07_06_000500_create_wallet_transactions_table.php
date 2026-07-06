<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Append-only coin ledger. Every coin movement (stake debit, prize credit,
 * spin reward, purchase, refund, admin adjustment) is one immutable row with
 * the signed amount and the resulting balance, so a wallet can always be
 * reconciled and audited. The PlayerProfile.coins column is a cached balance;
 * this table is the source of truth.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('wallet_transactions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            // stake, prize, spin, purchase, refund, adjustment, signup_bonus
            $table->string('type', 32)->index();
            // Signed: negative = debit, positive = credit.
            $table->bigInteger('amount');
            // Cached balance immediately after this row was applied.
            $table->unsignedBigInteger('balance_after');
            // Polymorphic reference to the originating record (match, spin, purchase).
            $table->string('reference_type', 48)->nullable();
            $table->unsignedBigInteger('reference_id')->nullable();
            $table->string('description')->nullable();
            $table->json('meta')->nullable();
            $table->timestamps();

            $table->index(['user_id', 'created_at']);
            $table->index(['reference_type', 'reference_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('wallet_transactions');
    }
};
