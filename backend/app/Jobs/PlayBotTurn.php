<?php

namespace App\Jobs;

use App\Models\Matchup;
use App\Services\Game\BotStrategyService;
use App\Services\Game\GameEngineService;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;
use Illuminate\Support\Facades\Cache;

/**
 * PlayBotTurn — the server-authoritative bot driver.
 *
 * Dispatched (AFTER the triggering transaction commits) whenever a human action,
 * a match start, or the recovery sweep leaves the turn on a bot seat. It owns and
 * advances the bot's play entirely on the server, so an online match NEVER waits
 * on any human's phone to execute a bot's turn:
 *
 *   - acquire a best-effort per-match lock (execution mutex);
 *   - reload the authoritative MatchState;
 *   - while the current turn is a bot AND the match is live:
 *       * short humanising delay (~600-1200 ms, configurable);
 *       * roll once (the engine is authoritative — dice probabilities unchanged);
 *       * if a move is available, pick ONE legal token (BotStrategyService) and
 *         move once;
 *       * continue on extra turns (six / capture / reached-home);
 *       * stop the instant the turn passes to a human or the match ends;
 *   - bounded by a max action count so a logic error can never infinite-loop.
 *
 * Idempotency & safety:
 *   - every engine call is wrapped in a row lock and reloads authoritative state,
 *     so two workers (or a retry) can never double-apply an action;
 *   - a stable per-step action_id lets the engine replay a stored result instead
 *     of acting twice on a genuine transport retry;
 *   - the engine's own bot-dispatch hook is SUPPRESSED for the calls made here,
 *     so this loop is the single driver of a bot sequence (no dispatch storm);
 *   - broadcasts (DiceRolled / TokenMoved / TurnChanged / GameEnded) are emitted
 *     by the engine exactly as for a human action, so all devices stay in sync.
 */
class PlayBotTurn implements ShouldQueue
{
    use Queueable;

    public int $matchId;

    /** Retry a couple of times on a transient DB/queue hiccup; self-healing. */
    public int $tries = 3;

    public int $backoff = 2;

    public function __construct(int $matchId)
    {
        $this->matchId = $matchId;
    }

    public function handle(GameEngineService $engine, BotStrategyService $strategy): void
    {
        // Best-effort execution mutex. Correctness does NOT depend on it (every
        // engine action is row-locked and reloads authoritative state), so if the
        // cache lock is unavailable we still proceed safely.
        $lock = null;
        try {
            $lock = Cache::lock('bot-turn:'.$this->matchId, (int) config('bots.turn.lock_seconds', 20));
            if (! $lock->get()) {
                return; // another worker already drives this match's bot turn
            }
        } catch (\Throwable $e) {
            $lock = null;
        }

        try {
            $this->drive($engine, $strategy);
        } finally {
            if ($lock) {
                try {
                    $lock->release();
                } catch (\Throwable $e) {
                    // ignore lock-release failures
                }
            }
        }
    }

    /**
     * The bot loop, factored out so tests can drive it directly (without the
     * cache lock or queue). Safe to call repeatedly — idempotent via the engine.
     */
    public function drive(GameEngineService $engine, BotStrategyService $strategy): void
    {
        $maxActions = (int) config('bots.turn.max_actions', 60);
        $actions = 0;

        while ($actions < $maxActions) {
            $match = Matchup::find($this->matchId);
            if (! $match || $match->status !== 'active') {
                return;
            }

            $state = $match->state()->first()?->state;
            if (! is_array($state)) {
                return;
            }
            if (($state['winner'] ?? null) !== null || ($state['phase'] ?? null) === 'finished') {
                return;
            }

            $color = $state['turn'] ?? null;
            if ($color === null) {
                return;
            }

            // Stop the instant control belongs to a human.
            $isBot = (bool) $match->players()->where('color', $color)->value('is_bot');
            if (! $isBot) {
                return;
            }

            $this->think();

            $phase = $state['phase'] ?? null;
            $seq = (int) ($state['seq'] ?? 0);

            if ($phase === 'awaiting_roll') {
                $roll = $engine->roll(
                    $match,
                    (string) $color,
                    forcedDice: null,
                    actionId: "bot-{$this->matchId}-{$seq}-roll",
                    dispatchBots: false,
                );
                $actions++;

                // Turn ended (forfeited third six, or no legal move and not a six).
                if (($roll['turn_passed'] ?? false) || ($roll['forfeited'] ?? false)) {
                    continue;
                }

                // A six with no legal move: the same bot rolls again next loop.
                $legalMoves = $roll['legal_moves'] ?? [];
                if ($legalMoves === []) {
                    continue;
                }

                $token = $strategy->chooseToken($legalMoves);
                $afterRollSeq = (int) ($roll['state']['seq'] ?? $seq);
                $engine->move(
                    $match,
                    (string) $color,
                    $token,
                    clientSeq: null,
                    actionId: "bot-{$this->matchId}-{$afterRollSeq}-move",
                    dispatchBots: false,
                );
                $actions++;

                continue;
            }

            if ($phase === 'awaiting_move') {
                // Resuming mid-turn (e.g. a retry after a crash between roll and
                // move): a dice value is already pending; just move.
                $legalMoves = $engine->legalMovesForState($state);
                if ($legalMoves === []) {
                    // Stuck in awaiting_move with no legal move should not happen
                    // (the roll path passes the turn instead). Bail rather than spin.
                    return;
                }
                $token = $strategy->chooseToken($legalMoves);
                $engine->move(
                    $match,
                    (string) $color,
                    $token,
                    clientSeq: null,
                    actionId: "bot-{$this->matchId}-{$seq}-move",
                    dispatchBots: false,
                );
                $actions++;

                continue;
            }

            // Unknown phase — stop.
            return;
        }
    }

    /**
     * Short, human-like pause before a bot acts. Skipped under tests so the
     * suite stays fast.
     */
    private function think(): void
    {
        if (app()->environment('testing')) {
            return;
        }

        $min = (int) config('bots.turn.think_min_ms', 600);
        $max = (int) config('bots.turn.think_max_ms', 1200);
        if ($max < $min) {
            $max = $min;
        }

        usleep(random_int($min, $max) * 1000);
    }
}
