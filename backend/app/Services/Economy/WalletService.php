<?php

namespace App\Services\Economy;

use App\Exceptions\InsufficientCoinsException;
use App\Models\PlayerProfile;
use App\Models\User;
use App\Models\WalletTransaction;
use Illuminate\Support\Facades\DB;

/**
 * WalletService — the ONLY place coins move.
 *
 * Every mutation runs inside a DB transaction with the player_profiles row
 * locked FOR UPDATE, so concurrent stakes/prizes/spins/purchases can never
 * race into a wrong balance. Each mutation writes one immutable
 * wallet_transactions ledger row carrying the signed amount and the resulting
 * balance, and keeps the cached PlayerProfile.coins column in sync. The ledger
 * is the source of truth; the column is a fast cache.
 */
class WalletService
{
    /** Cached balance for a user (coins column). */
    public function balance(User|int $user): int
    {
        $userId = $user instanceof User ? $user->id : $user;

        return (int) (PlayerProfile::where('user_id', $userId)->value('coins') ?? 0);
    }

    /**
     * Credit coins (amount must be > 0). Returns the ledger row.
     *
     * @param  array{reference_type?:string,reference_id?:int,description?:string,meta?:array}  $opts
     */
    public function credit(User|int $user, int $amount, string $type, array $opts = []): WalletTransaction
    {
        if ($amount <= 0) {
            throw new \InvalidArgumentException('Credit amount must be positive.');
        }

        return $this->apply($user, $amount, $type, $opts);
    }

    /**
     * Debit coins (amount must be > 0). Throws InsufficientCoinsException if the
     * balance would go negative (unless meta 'allow_negative' is true).
     *
     * @param  array{reference_type?:string,reference_id?:int,description?:string,meta?:array,allow_negative?:bool}  $opts
     */
    public function debit(User|int $user, int $amount, string $type, array $opts = []): WalletTransaction
    {
        if ($amount <= 0) {
            throw new \InvalidArgumentException('Debit amount must be positive.');
        }

        return $this->apply($user, -$amount, $type, $opts);
    }

    /**
     * Atomically move `$signedAmount` coins and append the ledger row.
     */
    private function apply(User|int $user, int $signedAmount, string $type, array $opts): WalletTransaction
    {
        $userId = $user instanceof User ? $user->id : $user;
        $allowNegative = (bool) ($opts['allow_negative'] ?? false);

        return DB::transaction(function () use ($userId, $signedAmount, $type, $opts, $allowNegative) {
            // Lock (or create) the wallet row so the balance can't move under us.
            $profile = PlayerProfile::where('user_id', $userId)->lockForUpdate()->first();
            if (! $profile) {
                $profile = PlayerProfile::create(['user_id' => $userId, 'coins' => 0]);
                $profile = PlayerProfile::where('user_id', $userId)->lockForUpdate()->first();
            }

            $current = (int) $profile->coins;
            $next = $current + $signedAmount;

            if ($next < 0 && ! $allowNegative) {
                throw new InsufficientCoinsException(abs($signedAmount), $current);
            }

            $profile->coins = $next;
            $profile->save();

            return WalletTransaction::create([
                'user_id' => $userId,
                'type' => $type,
                'amount' => $signedAmount,
                'balance_after' => $next,
                'reference_type' => $opts['reference_type'] ?? null,
                'reference_id' => $opts['reference_id'] ?? null,
                'description' => $opts['description'] ?? null,
                'meta' => $opts['meta'] ?? null,
            ]);
        });
    }

    /**
     * Seed a brand-new account's starting balance as a single ledger row.
     * Idempotent: does nothing if a signup bonus was already granted.
     */
    public function grantSignupBonus(User $user, ?int $amount = null): void
    {
        $amount ??= (int) config('economy.starting_coins', config('ludo.starting_coins', 500));
        if ($amount <= 0) {
            return;
        }

        $already = WalletTransaction::where('user_id', $user->id)
            ->where('type', WalletTransaction::TYPE_SIGNUP_BONUS)
            ->exists();

        if ($already) {
            return;
        }

        $this->credit($user, $amount, WalletTransaction::TYPE_SIGNUP_BONUS, [
            'description' => 'Welcome bonus',
        ]);
    }

    /** Recent ledger rows, newest first. */
    public function history(User|int $user, int $limit = 50)
    {
        $userId = $user instanceof User ? $user->id : $user;

        return WalletTransaction::where('user_id', $userId)
            ->latest('id')
            ->limit($limit)
            ->get();
    }
}
