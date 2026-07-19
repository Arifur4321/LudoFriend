<?php

namespace App\Services\Game;

use App\Events\DiceRolled;
use App\Events\GameEnded;
use App\Events\TokenMoved;
use App\Events\TurnChanged;
use App\Jobs\PersistMatchReplay;
use App\Jobs\PlayBotTurn;
use App\Models\MatchEvent;
use App\Models\MatchState;
use App\Models\Matchup;
use App\Models\PlayerProfile;
use App\Models\PlayerStat;
use App\Models\RecentPlayer;
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
        bool $dispatchBots = true,
    ): array {
        $color = strtolower($color);
        $broadcasts = [];

        $result = DB::transaction(function () use ($match, $color, $forcedDice, $actionId, &$broadcasts) {
            $row = MatchState::where('match_id', $match->id)->lockForUpdate()->first();
            if (! $row) {
                // Missing authoritative state for an active match: surface a clean
                // domain error (HTTP 422) rather than a null-deref 500.
                throw new RuntimeException('Match state not initialized.');
            }
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
            // Queued, not sent yet: broadcasts are flushed only after the
            // transaction commits (see flushBroadcasts) so a peer reacting to
            // the event can never GET a pre-commit / rolled-back state.
            $broadcasts[] = new DiceRolled($match->id, $color, $dice, $forfeited);

            if ($forfeited) {
                // Third six: forfeit move, reset counter, pass the turn.
                $state['consecutive_sixes'] = 0;
                $state['dice'] = null;
                $state['phase'] = 'awaiting_roll';
                $state = $this->advanceTurn($match, $state, $broadcasts);
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
                $state = $this->advanceTurn($match, $state, $broadcasts);
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

        $this->flushBroadcasts($broadcasts);

        // If the turn now belongs to a bot, hand it to the server-side driver.
        // Suppressed when the caller is the bot driver itself (it loops through
        // consecutive bot turns on its own), preventing a dispatch storm.
        if ($dispatchBots) {
            $this->maybeDispatchBotTurn($match, $result['state'] ?? null);
        }

        return $result;
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
    public function move(
        Matchup $match,
        string $color,
        int $tokenIndex,
        ?int $clientSeq = null,
        ?string $actionId = null,
        bool $dispatchBots = true,
    ): array {
        $color = strtolower($color);
        $broadcasts = [];

        $result = DB::transaction(function () use ($match, $color, $tokenIndex, $clientSeq, $actionId, &$broadcasts) {
            $row = MatchState::where('match_id', $match->id)->lockForUpdate()->first();
            if (! $row) {
                // Missing authoritative state for an active match: surface a clean
                // domain error (HTTP 422) rather than a null-deref 500.
                throw new RuntimeException('Match state not initialized.');
            }
            $state = $row->state;

            // Idempotency: a transport retry of the SAME physical tap must not
            // become a second move (and must not 422). Replay the stored
            // receipt while it still describes the current authoritative state
            // (same seq); after any later action, normal validation applies.
            $lastMove = $state['last_move'] ?? null;
            if ($actionId !== null
                && is_array($lastMove)
                && isset($lastMove['action_hash'])
                && hash_equals((string) $lastMove['action_hash'], hash('sha256', $actionId))
                && ($lastMove['color'] ?? null) === $color
                && (int) ($lastMove['token'] ?? -1) === $tokenIndex
                && (int) ($lastMove['state_seq'] ?? -1) === (int) $state['seq']) {
                return [
                    'from' => (int) $lastMove['from'],
                    'to' => (int) $lastMove['to'],
                    'path' => $lastMove['path'] ?? [],
                    'move_seq' => (int) $lastMove['move_seq'],
                    'captured' => $lastMove['captured'] ?? [],
                    'finished' => (bool) ($lastMove['finished'] ?? false),
                    'extra_turn' => (bool) ($lastMove['extra_turn'] ?? false),
                    'winner' => $state['winner'] ?? null,
                    'turn_passed' => (bool) ($lastMove['turn_passed'] ?? false),
                    'replayed' => true,
                    'state' => $state,
                ];
            }

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

            // Authoritatively apply. applyMove throws \InvalidArgumentException on
            // illegal geometry; the legal-set check above already guards this, but
            // convert defensively to a domain RuntimeException so the HTTP layer
            // returns 422 (never a 500) even if it is somehow reached.
            try {
                $result = $this->rules->applyMove($color, $tokenIndex, $dice, $state['tokens']);
            } catch (\InvalidArgumentException $e) {
                throw new RuntimeException('Illegal move for the current dice value.');
            }
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

            $broadcasts[] = new TokenMoved(
                $match->id,
                $color,
                $tokenIndex,
                $result['from'],
                $result['to'],
                $path,
                $result['captured'],
                $moveEvent->seq,
            );

            // Capture events.
            if ($result['captured'] !== []) {
                $this->appendEvent($match, $state, $color, 'captured', [
                    'by' => $color,
                    'captured' => $result['captured'],
                    'cell' => $this->rules->absolutePos($color, $result['to']),
                ]);
            }

            // Winner check for the moving color. A color "finishes" when all its
            // tokens are home. In free-for-all the first color to finish wins the
            // match. In 2v2 team mode the match ends ONLY when BOTH teammates
            // (every color on the finisher's team) have finished — a single
            // teammate finishing must NOT end the match or win for the pair.
            $colorFinished = $this->rules->isWinner($state['tokens'][$color]);
            if ($colorFinished) {
                $state['finished'][$color] = true;
            }

            $winner = null;
            if ($colorFinished) {
                if ($match->team_mode) {
                    if ($this->teamHasFinished($match, $state, $color)) {
                        $winner = $color; // representative finisher of the team
                        $state['winner'] = $color;
                    }
                } else {
                    $winner = $color;
                    $state['winner'] = $color;
                }
            }

            // Decide turn flow. An extra turn (six / capture / reached-home) is
            // only granted while the moving color still has tokens in play; a
            // color that just brought its LAST token home has nothing left to
            // move, so its turn passes (advanceTurn skips finished colors). This
            // keeps team mode flowing to the partner instead of stalling on a
            // dead extra roll. Forfeits are handled in roll().
            $extraTurn = $result['extra_turn'] && $winner === null && ! $colorFinished;

            $turnPassed = false;
            if ($winner !== null) {
                // Match ends.
                $state['phase'] = 'finished';
                $state['dice'] = null;
                $this->finalizeMatch($match, $state, $color, $broadcasts);
            } elseif ($extraTurn) {
                // Same player rolls again.
                $state['phase'] = 'awaiting_roll';
                $state['dice'] = null;
                if ($dice !== 6) {
                    // Extra turn from capture/home (not a six) resets six streak.
                    $state['consecutive_sixes'] = 0;
                }
            } else {
                // Normal turn pass, OR a team-mode color that just finished and is
                // now skipped for the remainder of the match.
                $state['phase'] = 'awaiting_roll';
                $state['dice'] = null;
                $state['consecutive_sixes'] = 0;
                $state = $this->advanceTurn($match, $state, $broadcasts);
                $turnPassed = true;
            }

            // Stamp the idempotency receipt onto the snapshot so an identical
            // transport retry can be answered without moving again. state_seq
            // is the FINAL seq (after capture/turn events), matching what the
            // retry will read back under the row lock.
            $state['last_move']['action_hash'] = $actionId === null ? null : hash('sha256', $actionId);
            $state['last_move']['state_seq'] = (int) $state['seq'];
            $state['last_move']['turn_passed'] = $turnPassed;

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
                'replayed' => false,
                'state' => $state,
            ];
        });

        $this->flushBroadcasts($broadcasts);

        // Best-effort, off the request path: persist the ordered replay log only
        // AFTER the match-ending transaction has committed.
        if (($result['winner'] ?? null) !== null) {
            PersistMatchReplay::dispatch($match->id);
        }

        // If the move passed the turn to a bot, hand it to the server-side driver
        // (never when the match just ended, and never when the caller is the bot
        // driver itself).
        if ($dispatchBots && ($result['winner'] ?? null) === null) {
            $this->maybeDispatchBotTurn($match, $result['state'] ?? null);
        }

        return $result;
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
    private function advanceTurn(Matchup $match, array $state, array &$broadcasts): array
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
                $broadcasts[] = new TurnChanged($match->id, $next);

                return $state;
            }
        }

        // Everyone finished — leave as-is (match should have ended).
        return $state;
    }

    /**
     * If the current turn belongs to a bot seat and the match is still live,
     * hand control to the server-side bot driver (a queued PlayBotTurn job).
     * This is the ONLY thing that advances a bot's turn online — it never
     * depends on a human client. Called AFTER an action's transaction commits
     * so the job reloads a fully-committed authoritative state.
     *
     * @param  array<string,mixed>|null  $state  the post-action snapshot, if known
     */
    public function maybeDispatchBotTurn(Matchup $match, ?array $state = null): void
    {
        if (! is_array($state)) {
            $state = MatchState::where('match_id', $match->id)->first()?->state;
        }
        if (! is_array($state)) {
            return;
        }
        if (($state['winner'] ?? null) !== null || ($state['phase'] ?? null) === 'finished') {
            return;
        }

        $turnColor = $state['turn'] ?? null;
        if ($turnColor === null) {
            return;
        }

        // Is the seat whose turn it is a bot? (bots have is_bot = true / no user.)
        $isBot = (bool) $match->players()->where('color', $turnColor)->value('is_bot');
        if (! $isBot) {
            return;
        }

        PlayBotTurn::dispatch($match->id);
    }

    /**
     * Team-mode completion test: have ALL colors on the finisher's team brought
     * every one of their tokens home? A single teammate finishing is NOT enough
     * to win — this is what stops the old "one player finishes ⇒ both win" bug.
     *
     * @param  array<string,mixed>  $state
     */
    private function teamHasFinished(Matchup $match, array $state, string $color): bool
    {
        $team = $match->players()->where('color', $color)->value('team');
        if ($team === null) {
            // team_mode without an assigned team (should not happen) — fall back
            // to single-color completion so a match can still end.
            return true;
        }

        $teamColors = $match->players()->where('team', $team)->pluck('color')->all();
        foreach ($teamColors as $teamColor) {
            $teamColor = strtolower((string) $teamColor);
            $tokens = $state['tokens'][$teamColor] ?? null;
            if (! is_array($tokens) || ! $this->rules->isWinner($tokens)) {
                return false;
            }
        }

        return true;
    }

    /**
     * Finalize a completed match: mark the model, set winner, broadcast end,
     * and assign placements based on finished-token counts.
     */
    private function finalizeMatch(Matchup $match, array &$state, string $winnerColor, array &$broadcasts): void
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
        $this->recordRecentPlayers($match);

        $broadcasts[] = new GameEnded($match->id, $winnerColor, $winnerPlayer?->user_id);
    }

    /**
     * Record every pair of human participants (Facebook, Google, email, or
     * guest — identical treatment) as each other's "recent players" so they
     * can find and invite each other again after the match. Runs inside the
     * finalize transaction; upserts keep it idempotent per match pair.
     */
    private function recordRecentPlayers(Matchup $match): void
    {
        $humans = $match->players()
            ->whereNotNull('user_id')
            ->where('is_bot', false)
            ->pluck('user_id')
            ->unique()
            ->values();

        if ($humans->count() < 2) {
            return; // solo vs bots — nobody to remember.
        }

        $now = now();
        foreach ($humans as $a) {
            foreach ($humans as $b) {
                if ($a === $b) {
                    continue;
                }

                $row = RecentPlayer::firstOrNew([
                    'user_id' => $a,
                    'other_user_id' => $b,
                ]);
                $row->games = $row->exists ? $row->games + 1 : 1;
                $row->last_match_id = $match->id;
                $row->last_played_at = $now;
                $row->save();
            }
        }
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

    /**
     * Dispatch the events queued during a transaction. Called only AFTER the
     * surrounding DB::transaction has committed, so a peer reacting to an event
     * can never GET a pre-commit (or rolled-back) state, and a queued broadcast
     * worker can never run ahead of the commit.
     *
     * @param  array<int,\Illuminate\Contracts\Broadcasting\ShouldBroadcast>  $events
     */
    private function flushBroadcasts(array $events): void
    {
        foreach ($events as $event) {
            try {
                // The events are ShouldBroadcastNow, so they publish to Reverb
                // synchronously here. A bare broadcast() would dispatch on the
                // PendingBroadcast's __destruct — outside any try — so capture it
                // and unset() to force the send INSIDE this try. A broadcast /
                // Reverb hiccup is then logged and swallowed: it must never fail
                // an action whose authoritative state is already committed to the
                // database (peers still converge via the recovery poll).
                $pending = broadcast($event);
                unset($pending);
            } catch (\Throwable $e) {
                report($e);
            }
        }
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
