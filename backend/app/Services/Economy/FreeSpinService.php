<?php

namespace App\Services\Economy;

use App\Models\DailySpin;
use App\Models\PlayerProfile;
use App\Models\User;
use App\Models\WalletTransaction;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use RuntimeException;

/**
 * FreeSpinService — server-authoritative free spin on a rolling cooldown.
 *
 * A player may claim one spin every `economy.free_spin.interval_minutes`
 * (default 60), measured from their most recent spin. The reward is chosen from
 * a weighted wheel (rare jackpots) entirely on the server; the client only
 * animates to the returned segment. Concurrency-safe: the claim locks the
 * player's wallet row FOR UPDATE, so two simultaneous requests can't both pass
 * the cooldown check.
 */
class FreeSpinService
{
    public function __construct(private readonly WalletService $wallet)
    {
    }

    /** Configured wheel segments: [['reward'=>int,'weight'=>int], ...]. */
    public function segments(): array
    {
        return array_values(config('economy.free_spin.segments', []));
    }

    public function enabled(): bool
    {
        return (bool) config('economy.free_spin.enabled', true);
    }

    public function intervalMinutes(): int
    {
        return max(1, (int) config('economy.free_spin.interval_minutes', 60));
    }

    /**
     * Availability + when the next spin unlocks.
     *
     * @return array{can_spin:bool,next_available_at:?string,last_reward:?int,interval_minutes:int}
     */
    public function status(User $user): array
    {
        $last = DailySpin::where('user_id', $user->id)->latest('id')->first();
        $nextAt = $last ? Carbon::parse($last->spun_at)->addMinutes($this->intervalMinutes()) : null;
        $ready = $this->enabled() && ($last === null || now()->greaterThanOrEqualTo($nextAt));

        return [
            'can_spin' => $ready,
            'next_available_at' => $ready ? null : $nextAt?->toIso8601String(),
            'last_reward' => $last?->reward,
            'interval_minutes' => $this->intervalMinutes(),
        ];
    }

    /**
     * Perform the spin: pick a weighted reward, enforce the cooldown, record the
     * claim and credit coins — all atomically.
     *
     * @return array{reward:int,segment_index:int,balance:int,next_available_at:string}
     *
     * @throws RuntimeException when disabled or still on cooldown.
     */
    public function spin(User $user): array
    {
        if (! $this->enabled()) {
            throw new RuntimeException('The free spin is currently disabled.');
        }

        [$reward, $segmentIndex] = $this->pickWeighted();
        $interval = $this->intervalMinutes();

        DB::transaction(function () use ($user, $reward, $segmentIndex, $interval) {
            // Serialize this user's spins on the wallet row (hold the lock).
            $profile = PlayerProfile::where('user_id', $user->id)->lockForUpdate()->first();
            if (! $profile) {
                PlayerProfile::create(['user_id' => $user->id, 'coins' => 0]);
                $profile = PlayerProfile::where('user_id', $user->id)->lockForUpdate()->first();
            }
            unset($profile); // lock acquired; balance mutated via WalletService below

            $last = DailySpin::where('user_id', $user->id)->latest('id')->first();
            if ($last && now()->lessThan(Carbon::parse($last->spun_at)->addMinutes($interval))) {
                throw new RuntimeException('Your free spin is still on cooldown.');
            }

            DailySpin::create([
                'user_id' => $user->id,
                'day_key' => now()->toDateString(),
                'reward' => $reward,
                'segment_index' => $segmentIndex,
                'spun_at' => now(),
            ]);

            $this->wallet->credit($user, $reward, WalletTransaction::TYPE_SPIN, [
                'reference_type' => 'free_spin',
                'description' => 'Free spin',
                'meta' => ['segment_index' => $segmentIndex],
            ]);
        });

        return [
            'reward' => $reward,
            'segment_index' => $segmentIndex,
            'balance' => $this->wallet->balance($user),
            'next_available_at' => now()->addMinutes($interval)->toIso8601String(),
        ];
    }

    /**
     * Weighted random pick. Returns [reward, segmentIndex].
     */
    private function pickWeighted(): array
    {
        $segments = $this->segments();
        if (empty($segments)) {
            return [0, 0];
        }

        $total = array_sum(array_column($segments, 'weight'));
        $roll = random_int(1, max(1, $total));

        $cumulative = 0;
        foreach ($segments as $index => $segment) {
            $cumulative += (int) $segment['weight'];
            if ($roll <= $cumulative) {
                return [(int) $segment['reward'], $index];
            }
        }

        $last = array_key_last($segments);

        return [(int) $segments[$last]['reward'], $last];
    }
}
