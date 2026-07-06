<?php

namespace App\Jobs;

use App\Models\Matchup;
use App\Services\Game\GameEngineService;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;

/**
 * Housekeeping job: abort active matches that have gone idle (no state change)
 * past the configured threshold and refund every escrowed stake, so coins are
 * never stranded when a table is abandoned mid-game.
 */
class ExpireStaleMatches implements ShouldQueue
{
    use Queueable;

    public function handle(GameEngineService $engine): void
    {
        $minutes = (int) config('economy.match_idle_abort_minutes', 30);
        $cutoff = now()->subMinutes($minutes);

        Matchup::query()
            ->where('status', 'active')
            ->whereHas('state', fn ($q) => $q->where('updated_at', '<', $cutoff))
            ->get()
            ->each(fn (Matchup $match) => $engine->abortMatch($match, 'idle_timeout'));
    }
}
