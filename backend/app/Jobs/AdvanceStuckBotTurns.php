<?php

namespace App\Jobs;

use App\Models\Matchup;
use App\Services\Game\GameEngineService;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;

/**
 * AdvanceStuckBotTurns — recovery safety net for online bot turns.
 *
 * The NORMAL path dispatches PlayBotTurn the moment a human passes the turn to a
 * bot, so bots react within seconds through the queue/event flow (this sweep is
 * NOT the normal driver). This job exists only for failure cases — e.g. the
 * queue worker was briefly down when the transition happened: it re-dispatches
 * PlayBotTurn for any active match whose current turn is a bot and whose
 * authoritative state has not advanced for a short grace period.
 *
 * It never drives a fresh transition (that is the event path's job) and is safe
 * to run alongside it: PlayBotTurn is idempotent and locked per match, so a
 * redundant dispatch is a no-op.
 */
class AdvanceStuckBotTurns implements ShouldQueue
{
    use Queueable;

    public function handle(GameEngineService $engine): void
    {
        $grace = (int) config('bots.turn.recovery_after_seconds', 8);
        $cutoff = now()->subSeconds($grace);

        Matchup::query()
            ->where('status', 'active')
            ->whereHas('state', fn ($q) => $q->where('updated_at', '<', $cutoff))
            ->with(['state'])
            ->chunkById(100, function ($matches) use ($engine) {
                foreach ($matches as $match) {
                    $state = $match->state?->state;
                    if (! is_array($state)) {
                        continue;
                    }
                    // maybeDispatchBotTurn re-checks winner/phase/is_bot before
                    // dispatching, so this only fires for genuinely stuck bots.
                    $engine->maybeDispatchBotTurn($match, $state);
                }
            });
    }
}
