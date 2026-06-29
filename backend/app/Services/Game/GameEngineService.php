<?php

namespace App\Services\Game;

use App\Events\DiceRolled;
use App\Events\GameEnded;
use App\Events\TokenMoved;
use App\Events\TurnChanged;
use App\Jobs\PersistMatchReplay;
use App\Models\Matchup;
use App\Models\MatchEvent;
use App\Models\MatchState;
use App\Models\PlayerProfile;
use App\Models\PlayerStat;
use Illuminate\Support\Facades\DB;
use RuntimeException;

/**
 * GameEngineService — the server-authoritative referee.
 *
 * Responsibilities:
 *   - Own the canonical match_state JSON (token map, turn pointer, dice phase,
 *     consecutive-six counter, winner).
 *   - Validate every action against turn ownership AND dice phase AND the
 *     verified ruleset (via LudoRules). The client move is NEVER trusted; the
 *     outcome is always recomputed server-side.
 *   - Append match_events with a strictly increasing per-match seq. The
 *     unique(match_id, seq) DB constraint plus an explicit expected-seq check
 *     reject replayed / out-of-order events.
 *   - Persist a new match_state version and broadcast the resulting events.
 *
 * The `state` JSON shape:
 * [
 *   'tokens'      => ['red' => [int,int,int,int], ...],
 *   'turn_order'  => ['red','green',...],          // rotation order
 *   'turn'        => 'red',                          // whose turn it is
 *   'phase'       => 'awaiting_roll'|'awaiting_move',
 *   'dice'        => int|null,                       // last roll pending a move
 *   'consecutive_sixes' => int,                      // within current turn
 *   'finished'    => ['red'=>bool, ...],             // colors that won
 *   'winner'      => string|null,
 *   'seq'         => int,                            // last applied event seq
 * ]
 */
class GameEngineService
{
    public function __construct(private readonly LudoRules $rules)
    {
    }

    /* =====================================================================
     | Lifecycle
     | ===================================================================== */

    /**
     * Create the initial authoritative state for a match and persist it.
     *
     * @param  string[]  $turnOrder  colors in seat order (e.g. ['red','green',...])
     */
    public function initializeState(Matchup $match, array $turnOrder): MatchState
    {
        $state = [
            'tokens' => $this->rules->initialTokens($turnOrder),
            'turn_order' => array_values($turnOrder),
            'turn' => $turnOrder[0],
            'phase' => 'awaiting_roll',
            'dice' => null,
            'consecutive_sixes' => 0,
            'finished' => array_fill_keys($turnOrder, false),
            'winner' => null,
            'seq' => 0,
        ];

        return MatchState::create([
            'match_id' => $match->id,
            'version' => 0,
            'state' => $state,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    /**
     * Load the current authoritative state row for a match.
     */
    public function loadState(Matchup $match): MatchState
    {
        $state = MatchState::where('match_id', $match->id)->first();

        if (! $state) {
            throw new RuntimeException('Match state not initialized.');
        }

        return $state;
    }

    /* =====================================================================
     | Dice roll
     | ===================================================================== */

    /**
     * Roll the dice for `$color`. Validates turn ownership and phase, advances
     * the consecutive-six counter, applies the three-sixes forfeit rule, and
     * records the result. Returns a structured outcome for the controller.
     *
     * @return array{
     *   dice:int,
     *   forfeited:bool,
     *   legal_moves:array,
     *   turn_passed:bool,
     *   state:array
     * }
     *
     * @throws RuntimeException on wrong turn / wrong phase.
     */
    public function roll(Matchup $match, string $color, ?int $forcedDice = null): array
    {
        $color = strtolower($color);

        return DB::transaction(function () use ($match, $color, $forcedDice) {
            $row = MatchState::where('match_id', $match->id)->lockForUpdate()->first();
            $state = $row->state;

            $this->assertTurn($state, $color);
            $this->assertPhase($state, 'awaiting_roll');

            // Uniform 1..6. A seed-based deterministic RNG can be layered here
            // for exact replays; random_int keeps it simple and secure. Tests
            // pass $forcedDice to make rolls deterministic.
            $dice = $forcedDice ?? random_int(1, 6);

            $sixesBefore = (int) $state['consecutive_sixes'];
            $forfeited = $this->rules->isForfeitedThirdSix($sixesBefore, $dice);

            // Record the dice roll event regardless of outcome.
            $this->appendEvent($match, $state, $color, 'dice_rolled', [
                'dice' => $dice,
                'consecutive_sixes' => $forfeited ? $sixesBefore + 1 : $sixesBefore + ($dice === 6 ? 1 : 0),
                'forfeited' => $forfeited,
            ]);
            broadcast(new DiceRolled($match->id, $color, $dice, $forfeited));

            if ($forfeited) {
                // Third six: forfeit move, reset counter, pass the turn.
                $state['consecutive_sixes'] = 0;
                $state['dice'] = null;
                $state['phase'] = 'awaiting_roll';
                $state = $this->advanceTurn($match, $state);
                $this->persist($row, $state);

                return [
                    'dice' => $dice,
                    'forfeited' => true,
                    'legal_moves' => [],
                    'turn_passed' => true,
                    'state' => $state,
                ];
            }

            // Track consecutive sixes within the turn.
            $state['consecutive_sixes'] = $dice === 6 ? $sixesBefore + 1 : 0;

            $legalMoves = $this->rules->legalMoves($color, $dice, $state['tokens']);

            if ($legalMoves === []) {
                // No legal move: a six still grants another roll; otherwise the
                // turn passes.
                if ($dice === 6) {
                    $state['phase'] = 'awaiting_roll';
                    $state['dice'] = null;
                    $this->persist($row, $state);

                    return [
                        'dice' => $dice,
                        'forfeited' => false,
                        'legal_moves' => [],
                        'turn_passed' => false,
                        'state' => $state,
                    ];
                }

                $state['dice'] = null;
                $state = $this->advanceTurn($match, $state);
                $this->persist($row, $state);

                return [
                    'dice' => $dice,
                    'forfeited' => false,
                    'legal_moves' => [],
                    'turn_passed' => true,
                    'state' => $state,
                ];
            }

            // Legal moves exist: enter move phase holding the dice value.
            $state['dice'] = $dice;
            $state['phase'] = 'awaiting_move';
            $this->persist($row, $state);

            return [
                'dice' => $dice,
                'forfeited' => false,
                'legal_moves' => $legalMoves,
                'turn_passed' => false,
                'state' => $state,
            ];
        });
    }

    /* =====================================================================
     | Token move
     | ===================================================================== */

    /**
     * Apply a token move for `$color`. Validates turn ownership, that we are in
     * the move phase with a pending dice, and that the requested move is among
     * the legal moves recomputed server-side. The client only supplies which
     * token to move; the destination and captures are derived authoritatively.
     *
     * @param  int       $tokenIndex  0..3 — the token the player wants to move
     * @param  int|null  $clientSeq   optional client-asserted next seq (anti-replay)
     * @return array{
     *   from:int, to:int, captured:array, finished:bool,
     *   extra_turn:bool, winner:?string, turn_passed:bool, state:array
     * }
     *
     * @throws RuntimeException on wrong turn / wrong phase / illegal move / replay.
     */
    public function move(Matchup $match, string $color, int $tokenIndex, ?int $clientSeq = null): array
    {
        $color = strtolower($color);

        return DB::transaction(function () use ($match, $color, $tokenIndex, $clientSeq) {
            $row = MatchState::where('match_id', $match->id)->lockForUpdate()->first();
            $state = $row->state;

            $this->assertTurn($state, $color);
            $this->assertPhase($state, 'awaiting_move');

            // Anti-replay: if the client asserts a seq, it must equal the next
            // expected seq. Stale/duplicate requests are rejected here in
            // addition to the unique(match_id, seq) DB constraint.
            $expectedSeq = (int) $state['seq'] + 1;
            if ($clientSeq !== null && $clientSeq !== $expectedSeq) {
                throw new RuntimeException("Out-of-order or replayed action (expected seq {$expectedSeq}).");
            }

            $dice = $state['dice'];
            if ($dice === null) {
                throw new RuntimeException('No dice value pending for this move.');
            }

            // Recompute legal moves server-side; the requested token must be in
            // the legal set. We never trust a client-provided destination.
            $legalMoves = $this->rules->legalMoves($color, $dice, $state['tokens']);
            $chosen = collect($legalMoves)->firstWhere('token', $tokenIndex);
            if ($chosen === null) {
                throw new RuntimeException('Illegal move for the current dice value.');
            }

            // Authoritatively apply.
            $result = $this->rules->applyMove($color, $tokenIndex, $dice, $state['tokens']);
            $state['tokens'] = $result['tokens'];

            // Persist token_moved event.
            $this->appendEvent($match, $state, $color, 'token_moved', [
                'token' => $tokenIndex,
                'from' => $result['from'],
                'to' => $result['to'],
                'dice' => $dice,
            ]);
            broadcast(new TokenMoved($match->id, $color, $tokenIndex, $result['from'], $result['to']));

            // Capture events.
            if ($result['captured'] !== []) {
                $this->appendEvent($match, $state, $color, 'captured', [
                    'by' => $color,
                    'captured' => $result['captured'],
                    'cell' => $this->rules->absolutePos($color, $result['to']),
                ]);
            }

            // Winner check for the moving color.
            $winner = null;
            if ($this->rules->isWinner($state['tokens'][$color])) {
                $state['finished'][$color] = true;
                $winner = $color;
                $state['winner'] = $color;
            }

            // Decide turn flow: extra turn if six/capture/home, unless forfeited
            // (handled in roll). After a move the six-counter only persists when
            // an extra turn is granted by a six.
            $extraTurn = $result['extra_turn'] && $winner === null;

            $turnPassed = false;
            if ($winner !== null) {
                // Match ends.
                $state['phase'] = 'finished';
                $state['dice'] = null;
                $this->finalizeMatch($match, $state, $color);
            } elseif ($extraTurn) {
                // Same player rolls again.
                $state['phase'] = 'awaiting_roll';
                $state['dice'] = null;
                if ($dice !== 6) {
                    // Extra turn from capture/home (not a six) resets six streak.
                    $state['consecutive_sixes'] = 0;
                }
            } else {
                $state['phase'] = 'awaiting_roll';
                $state['dice'] = null;
                $state['consecutive_sixes'] = 0;
                $state = $this->advanceTurn($match, $state);
                $turnPassed = true;
            }

            $this->persist($row, $state);

            return [
                'from' => $result['from'],
                'to' => $result['to'],
                'captured' => $result['captured'],
                'finished' => $result['finished'],
                'extra_turn' => $extraTurn,
                'winner' => $winner,
                'turn_passed' => $turnPassed,
                'state' => $state,
            ];
        });
    }

    /* =====================================================================
     | Turn management
     | ===================================================================== */

    /**
     * Advance the turn pointer to the next color that has not finished.
     */
    private function advanceTurn(Matchup $match, array $state): array
    {
        $order = $state['turn_order'];
        $count = count($order);
        $currentIndex = array_search($state['turn'], $order, true);

        for ($step = 1; $step <= $count; $step++) {
            $next = $order[($currentIndex + $step) % $count];
            if (empty($state['finished'][$next])) {
                $state['turn'] = $next;
                $state['consecutive_sixes'] = 0;
                $this->appendEvent($match, $state, $next, 'turn_changed', ['turn' => $next]);
                broadcast(new TurnChanged($match->id, $next));

                return $state;
            }
        }

        // Everyone finished — leave as-is (match should have ended).
        return $state;
    }

    /**
     * Finalize a completed match: mark the model, set winner, broadcast end,
     * and assign placements based on finished-token counts.
     */
    private function finalizeMatch(Matchup $match, array &$state, string $winnerColor): void
    {
        $this->appendEvent($match, $state, $winnerColor, 'game_ended', [
            'winner' => $winnerColor,
        ]);

        $winnerPlayer = $match->players()->where('color', $winnerColor)->first();

        $match->forceFill([
            'status' => 'finished',
            'winner_user_id' => $winnerPlayer?->user_id,
            'ended_at' => now(),
        ])->save();

        // Placement: winner = 1, then rank the rest by finished tokens desc.
        $ranking = collect($state['turn_order'])
            ->reject(fn ($c) => $c === $winnerColor)
            ->sortByDesc(fn ($c) => $this->rules->finishedCount($state['tokens'][$c]))
            ->values();

        $match->players()->where('color', $winnerColor)->update(['placement' => 1]);
        foreach ($ranking as $i => $color) {
            $match->players()->where('color', $color)->update(['placement' => $i + 2]);
        }

        $this->recordResults($match, $winnerPlayer?->user_id);

        broadcast(new GameEnded($match->id, $winnerColor, $winnerPlayer?->user_id));

        // Best-effort, off the request path: persist the ordered replay log.
        PersistMatchReplay::dispatch($match->id);
    }

    /**
     * Update profile counters / coins and all-time leaderboard stats for the
     * human participants of a finished match.
     */
    private function recordResults(Matchup $match, ?int $winnerUserId): void
    {
        $reward = (int) config('ludo.win_coins_reward');

        foreach ($match->players()->whereNotNull('user_id')->where('is_bot', false)->get() as $mp) {
            $isWinner = $winnerUserId !== null && $mp->user_id === $winnerUserId;

            $profile = PlayerProfile::firstOrCreate(['user_id' => $mp->user_id]);
            $isWinner ? $profile->recordWin($reward) : $profile->recordLoss();

            $stat = PlayerStat::firstOrCreate(
                ['user_id' => $mp->user_id, 'period' => 'all_time'],
                ['rating' => config('ludo.rating_default')]
            );
            $stat->increment('games');
            if ($isWinner) {
                $stat->increment('wins');
            }
            // Simple rating nudge; a full Elo pass can run in RecalculateLeaderboard.
            $stat->increment('rating', $isWinner ? config('ludo.rating_k_factor') : 0);
        }
    }

    /* =====================================================================
     | Event log + persistence (anti-replay core)
     | ===================================================================== */

    /**
     * Append a match event with the next sequence number. The working `$state`
     * is passed BY REFERENCE so its `seq` is bumped in lock-step with the row —
     * keeping the caller's local copy and the persisted snapshot consistent.
     *
     * A duplicate seq violates the unique(match_id, seq) constraint and aborts
     * the surrounding transaction, making replays impossible to persist.
     *
     * @param  array  $state  working state (by reference; its `seq` is advanced)
     */
    private function appendEvent(Matchup $match, array &$state, ?string $actorColor, string $type, array $payload): MatchEvent
    {
        $nextSeq = (int) $state['seq'] + 1;

        $event = MatchEvent::create([
            'match_id' => $match->id,
            'seq' => $nextSeq,
            'actor_color' => $actorColor,
            'type' => $type,
            'payload' => $payload,
            'server_time' => now(),
        ]);

        // Advance the working state's sequence so persist() writes it.
        $state['seq'] = $nextSeq;

        return $event;
    }

    /**
     * Persist the working state into the match_state row, bumping the version.
     */
    private function persist(MatchState $row, array $state): void
    {
        $row->state = $state;
        $row->version = $row->version + 1;
        $row->updated_at = now();
        $row->save();
    }

    /* =====================================================================
     | Guards
     | ===================================================================== */

    private function assertTurn(array $state, string $color): void
    {
        if (($state['winner'] ?? null) !== null) {
            throw new RuntimeException('Match has already finished.');
        }

        if (($state['turn'] ?? null) !== $color) {
            throw new RuntimeException('It is not your turn.');
        }
    }

    private function assertPhase(array $state, string $phase): void
    {
        if (($state['phase'] ?? null) !== $phase) {
            throw new RuntimeException("Invalid action for the current phase ({$state['phase']}).");
        }
    }
}
