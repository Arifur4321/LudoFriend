<?php

namespace App\Services\Game;

use App\Events\DiceRolled;
use App\Events\GameEnded;
use App\Events\TokenMoved;
use App\Events\TurnChanged;
use App\Jobs\PersistMatchReplay;
use App\Models\MatchEvent;
use App\Models\MatchState;
use App\Models\Matchup;
use App\Models\PlayerProfile;
use App\Models\PlayerStat;
use App\Models\WalletTransaction;
use App\Services\Economy\WalletService;
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
    public function __construct(
        private readonly LudoRules $rules,
        private readonly WalletService $wallet,
    ) {}

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
            'last_move' => null,
            'last_roll' => null,
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

    /**
     * Return the legal moves for the currently pending roll, if any.
     *
     * State refreshes use this after a reconnect or missed broadcast so the
     * active player can resume an awaiting-move turn instead of seeing a stale
     * dice/disabled board. The rules are still computed authoritatively here;
     * the client never supplies destinations.
     *
     * @param  array<string,mixed>  $state
     * @return array<int,array<string,mixed>>
     */
    public function legalMovesForState(array $state): array
    {
        if (($state['phase'] ?? null) !== 'awaiting_move'
            || ! isset($state['turn'], $state['dice'], $state['tokens'])) {
            return [];
        }

        return $this->rules->legalMoves(
            (string) $state['turn'],
            (int) $state['dice'],
            $state['tokens'],
        );
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
     *   replayed:bool,
     *   state:array
     * }
     *
     * @throws RuntimeException on wrong turn / wrong phase.
     */
    public function roll(
        Matchup $match,
        string $color,
        ?int $forcedDice = null,
        ?string $actionId = null,
    ): array {
        $color = strtolower($color);

        return DB::transaction(function () use ($match, $color, $forcedDice, $actionId) {
            $row = MatchState::where('match_id', $match->id)->lockForUpdate()->first();
            $state = $row->state;

            // A transport retry must not become a second dice roll. Only replay
            // the receipt while it still describes the current authoritative
            // state; after any later action changes seq, normal turn/phase
            // validation applies again.
            $lastRoll = $state['last_roll'] ?? null;
            if ($actionId !== null
                && is_array($lastRoll)
                && isset($lastRoll['action_hash'])
                && hash_equals((string) $lastRoll['action_hash'], hash('sha256', $actionId))
                && ($lastRoll['color'] ?? null) === $color
                && (int) ($lastRoll['state_seq'] ?? -1) === (int) $state['seq']) {
                return [
                    'dice' => (int) $lastRoll['dice'],
                    'forfeited' => (bool) $lastRoll['forfeited'],
                    'legal_moves' => $lastRoll['legal_moves'] ?? [],
                    'turn_passed' => (bool) $lastRoll['turn_passed'],
                    'replayed' => true,
                    'state' => $state,
                ];
            }

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
                $this->rememberRoll(
                    $state, $actionId, $color, $dice, true, [], true,
                );
                $this->persist($row, $state);

                return [
                    'dice' => $dice,
                    'forfeited' => true,
                    'legal_moves' => [],
                    'turn_passed' => true,
                    'replayed' => false,
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
                    $this->rememberRoll(
                        $state, $actionId, $color, $dice, false, [], false,
                    );
                    $this->persist($row, $state);

                    return [
                        'dice' => $dice,
                        'forfeited' => false,
                        'legal_moves' => [],
                        'turn_passed' => false,
                        'replayed' => false,
                        'state' => $state,
                    ];
                }

                $state['dice'] = null;
                $state = $this->advanceTurn($match, $state);
                $this->rememberRoll(
                    $state, $actionId, $color, $dice, false, [], true,
                );
                $this->persist($row, $state);

                return [
                    'dice' => $dice,
                    'forfeited' => false,
                    'legal_moves' => [],
                    'turn_passed' => true,
                    'replayed' => false,
                    'state' => $state,
                ];
            }

            // Legal moves exist: enter move phase holding the dice value.
            $state['dice'] = $dice;
            $state['phase'] = 'awaiting_move';
            $this->rememberRoll(
                $state, $actionId, $color, $dice, false, $legalMoves, false,
            );
            $this->persist($row, $state);

            return [
                'dice' => $dice,
                'forfeited' => false,
                'legal_moves' => $legalMoves,
                'turn_passed' => false,
                'replayed' => false,
                'state' => $state,
            ];
        });
    }

    /**
     * Store the response for one dice action in the authoritative snapshot so
     * an identical transport retry can be answered without rolling again.
     *
     * @param  array<string,mixed>  $state
     * @param  array<int,array<string,mixed>>  $legalMoves
     */
    private function rememberRoll(
        array &$state,
        ?string $actionId,
        string $color,
        int $dice,
        bool $forfeited,
        array $legalMoves,
        bool $turnPassed,
    ): void {
        $state['last_roll'] = [
            'action_hash' => $actionId === null ? null : hash('sha256', $actionId),
            'color' => $color,
            'dice' => $dice,
            'forfeited' => $forfeited,
            'legal_moves' => $legalMoves,
            'turn_passed' => $turnPassed,
            'state_seq' => (int) $state['seq'],
        ];
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
     * @param  int  $tokenIndex  0..3 — the token the player wants to move
     * @param  int|null  $clientSeq  optional client-asserted next seq (anti-replay)
     * @return array{
     *   from:int, to:int, path:array, move_seq:int, captured:array, finished:bool,
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
            $path = $this->movementPath($result['from'], $result['to']);

            // Persist token_moved event.
            $moveEvent = $this->appendEvent($match, $state, $color, 'token_moved', [
                'token' => $tokenIndex,
                'from' => $result['from'],
                'to' => $result['to'],
                'dice' => $dice,
                'path' => $path,
                'captured' => $result['captured'],
            ]);
            $state['last_move'] = [
                'move_seq' => $moveEvent->seq,
                'color' => $color,
                'token' => $tokenIndex,
                'from' => $result['from'],
                'to' => $result['to'],
                'path' => $path,
                'captured' => $result['captured'],
                'finished' => $result['finished'],
                'extra_turn' => $result['extra_turn'],
            ];

            broadcast(new TokenMoved(
                $match->id,
                $color,
                $tokenIndex,
                $result['from'],
                $result['to'],
                $path,
                $result['captured'],
                $moveEvent->seq,
            ));

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
                'path' => $path,
                'move_seq' => $moveEvent->seq,
                'captured' => $result['captured'],
                'finished' => $result['finished'],
                'extra_turn' => $extraTurn,
                'winner' => $winner,
                'turn_passed' => $turnPassed,
                'state' => $state,
            ];
        });
    }

    /**
     * Relative cells traversed by one legal move, excluding the starting cell.
     *
     * @return int[]
     */
    private function movementPath(int $from, int $to): array
    {
        if ($from < 0) {
            return [0];
        }

        return range($from + 1, $to);
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

        // In team mode the whole winning team places 1st; otherwise just the
        // finisher does.
        $winnerTeam = $match->team_mode ? $winnerPlayer?->team : null;
        $winningColors = $match->team_mode && $winnerTeam !== null
            ? $match->players()->where('team', $winnerTeam)->pluck('color')->all()
            : [$winnerColor];

        $match->forceFill([
            'status' => 'finished',
            'winner_user_id' => $winnerPlayer?->user_id,
            'ended_reason' => 'completed',
            'ended_at' => now(),
        ])->save();

        // Placement: winners = 1, then rank the rest by finished tokens desc.
        $ranking = collect($state['turn_order'])
            ->reject(fn ($c) => in_array($c, $winningColors, true))
            ->sortByDesc(fn ($c) => $this->rules->finishedCount($state['tokens'][$c]))
            ->values();

        $match->players()->whereIn('color', $winningColors)->update(['placement' => 1]);
        foreach ($ranking as $i => $color) {
            $match->players()->where('color', $color)->update(['placement' => $i + 2]);
        }

        $this->recordResults($match, $winningColors);

        broadcast(new GameEnded($match->id, $winnerColor, $winnerPlayer?->user_id));

        // Best-effort, off the request path: persist the ordered replay log.
        PersistMatchReplay::dispatch($match->id);
    }

    /**
     * Pay out the pot and update profile counters / all-time stats for the human
     * participants of a finished match.
     *
     * Pure winner-takes-all: the escrowed pot goes to the winner, or is split
     * evenly across the winning team (odd remainder to the finisher). Losers
     * already paid their stake at start, so nothing more is debited. All coin
     * movement flows through WalletService so the ledger stays authoritative.
     * For legacy/casual (unstaked) matches, a flat config reward is credited.
     *
     * @param  string[]  $winningColors  one color, or a whole team's colors
     */
    private function recordResults(Matchup $match, array $winningColors): void
    {
        $pot = (int) $match->pot;
        $rakeBps = (int) config('economy.house_rake_bps', 0);
        $payoutPool = $pot > 0 ? intdiv($pot * (10000 - $rakeBps), 10000) : 0;

        $winners = $match->players()
            ->whereIn('color', $winningColors)
            ->whereNotNull('user_id')
            ->where('is_bot', false)
            ->orderBy('placement')
            ->orderBy('seat')
            ->get();

        // Split the pool across human winners (even split, remainder to the first).
        $shares = $this->splitEvenly($payoutPool, $winners->count());

        foreach ($match->players()->whereNotNull('user_id')->where('is_bot', false)->get() as $mp) {
            $isWinner = in_array($mp->color, $winningColors, true);

            $profile = PlayerProfile::firstOrCreate(['user_id' => $mp->user_id]);
            // Coins are handled by the wallet below; recordWin(0) only advances
            // the win/streak counters.
            $isWinner ? $profile->recordWin(0) : $profile->recordLoss();

            $stat = PlayerStat::firstOrCreate(
                ['user_id' => $mp->user_id, 'period' => 'all_time'],
                ['rating' => config('ludo.rating_default')]
            );
            $stat->increment('games');
            if ($isWinner) {
                $stat->increment('wins');
            }
            $stat->increment('rating', $isWinner ? config('ludo.rating_k_factor') : 0);
        }

        if ($payoutPool > 0) {
            foreach ($winners as $i => $mp) {
                $share = $shares[$i] ?? 0;
                if ($share <= 0) {
                    continue;
                }
                $this->wallet->credit($mp->user_id, $share, WalletTransaction::TYPE_PRIZE, [
                    'reference_type' => 'match',
                    'reference_id' => $match->id,
                    'description' => 'Match prize',
                    'meta' => ['board_tier' => $match->board_tier, 'pot' => $pot],
                ]);
                $mp->forceFill(['payout' => $share])->save();
            }
        } elseif ((int) $match->stake === 0) {
            // Unstaked/casual match only: flat reward from config (kept for
            // offline parity and any legacy free rooms). A staked match with an
            // unexpected empty pot pays nothing rather than minting free coins.
            $reward = (int) config('ludo.win_coins_reward');
            if ($reward > 0) {
                foreach ($winners as $mp) {
                    $this->wallet->credit($mp->user_id, $reward, WalletTransaction::TYPE_PRIZE, [
                        'reference_type' => 'match',
                        'reference_id' => $match->id,
                        'description' => 'Match reward',
                    ]);
                    $mp->forceFill(['payout' => $reward])->save();
                }
            }
        }
    }

    /**
     * Split `$total` into `$parts` whole shares; the remainder goes to the first
     * share so the sum is exactly `$total` (no coins created or lost).
     *
     * @return int[]
     */
    private function splitEvenly(int $total, int $parts): array
    {
        if ($parts <= 0) {
            return [];
        }
        $base = intdiv($total, $parts);
        $shares = array_fill(0, $parts, $base);
        $shares[0] += $total - ($base * $parts);

        return $shares;
    }

    /**
     * Abort an active match and refund every escrowed stake. Used when a match
     * is abandoned (all players gone / stale) so coins are never stranded.
     */
    public function abortMatch(Matchup $match, string $reason = 'abandoned'): void
    {
        DB::transaction(function () use ($match, $reason) {
            $fresh = Matchup::whereKey($match->id)->lockForUpdate()->first();
            if (! $fresh || $fresh->status !== 'active') {
                return; // already finished/aborted
            }

            foreach ($fresh->players()->where('stake_paid', '>', 0)->whereNotNull('user_id')->where('is_bot', false)->get() as $mp) {
                $this->wallet->credit($mp->user_id, (int) $mp->stake_paid, WalletTransaction::TYPE_REFUND, [
                    'reference_type' => 'match',
                    'reference_id' => $fresh->id,
                    'description' => 'Match aborted — stake refunded',
                ]);
            }

            $fresh->forceFill([
                'status' => 'abandoned',
                'ended_reason' => $reason,
                'pot' => 0,
                'ended_at' => now(),
            ])->save();

            if ($fresh->room_id) {
                $fresh->room()->update(['status' => 'cancelled']);
            }
        });
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
