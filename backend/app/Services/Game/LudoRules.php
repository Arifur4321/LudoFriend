<?php

namespace App\Services\Game;

/**
 * LudoRules — pure, side-effect-free implementation of the verified Ludo
 * ruleset. This class never touches the database, the request, or any
 * external state; it operates purely on plain arrays so it can be unit
 * tested in isolation and reused by the authoritative game engine.
 *
 * All rule constants are read from config('ludo') so the numbers are
 * single-sourced.
 *
 * Token relative position convention:
 *   -1     = in base
 *    0..50 = on the shared ring (relative to the color's start)
 *   51..56 = private home column
 *   56     = finished / home
 *
 * absolutePos(color, rel) = (start[color] + rel) % ringSize  for rel 0..50.
 */
class LudoRules
{
    private int $ringSize;
    private int $relBase;
    private int $relRingMin;
    private int $relRingMax;
    private int $relHomeMin;
    private int $relHome;
    private int $leaveBaseRoll;
    private int $extraTurnRoll;
    private int $maxConsecutiveSixes;
    private int $tokensPerPlayer;

    /** @var array<string,int> color => start offset on the ring */
    private array $startOffsets;

    /** @var int[] absolute ring indices that are safe from capture */
    private array $safeCells;

    public function __construct(?array $config = null)
    {
        $config ??= config('ludo');

        $this->ringSize            = (int) $config['ring_size'];
        $this->relBase             = (int) $config['rel_base'];
        $this->relRingMin          = (int) $config['rel_ring_min'];
        $this->relRingMax          = (int) $config['rel_ring_max'];
        $this->relHomeMin          = (int) $config['rel_home_min'];
        $this->relHome             = (int) $config['rel_home'];
        $this->leaveBaseRoll       = (int) $config['leave_base_roll'];
        $this->extraTurnRoll       = (int) $config['extra_turn_roll'];
        $this->maxConsecutiveSixes = (int) $config['max_consecutive_sixes'];
        $this->tokensPerPlayer     = (int) $config['tokens_per_player'];
        $this->startOffsets        = $config['start_offsets'];
        $this->safeCells           = $config['safe_cells'];
    }

    /**
     * Convert a relative position to an absolute ring index.
     *
     * @return int|null absolute index 0..ringSize-1 when on the shared ring,
     *                  or null when in base / home column / finished.
     */
    public function absolutePos(string $color, int $rel): ?int
    {
        if ($rel < $this->relRingMin || $rel > $this->relRingMax) {
            return null;
        }

        $start = $this->startOffsets[strtolower($color)] ?? null;
        if ($start === null) {
            return null;
        }

        return ($start + $rel) % $this->ringSize;
    }

    /**
     * Is the given absolute ring index a safe (capture-proof) cell?
     */
    public function isSafeCell(?int $absolute): bool
    {
        return $absolute !== null && in_array($absolute, $this->safeCells, true);
    }

    /**
     * Is a single move of `$dice` from relative position `$rel` legal,
     * considered purely on the geometry of one token (ignoring board occupancy)?
     *
     * Rules enforced:
     *   - A token in base (rel -1) may only move on a roll equal to leaveBaseRoll
     *     (6), landing on rel 0.
     *   - A finished token (rel 56) cannot move.
     *   - Otherwise r + dice must be <= relHome (56); overshooting home is illegal
     *     (you must land exactly on 56 to finish).
     */
    public function isLegalTokenMove(int $rel, int $dice): bool
    {
        // Already finished — immovable.
        if ($rel >= $this->relHome) {
            return false;
        }

        // In base: only a six releases a token, to rel 0.
        if ($rel === $this->relBase) {
            return $dice === $this->leaveBaseRoll;
        }

        // On ring or in home column: must not overshoot home.
        return ($rel + $dice) <= $this->relHome;
    }

    /**
     * Resulting relative position for a legal token move. Assumes the move
     * has already passed isLegalTokenMove().
     */
    public function destinationRel(int $rel, int $dice): int
    {
        if ($rel === $this->relBase) {
            return $this->relRingMin; // base -> start cell (rel 0)
        }

        return $rel + $dice;
    }

    /**
     * Compute every legal move for `$color` given a dice value and the full
     * token map. Occupancy rules applied:
     *   - Own-token stacking is ALLOWED: a token may land on any cell already
     *     occupied by one of its OWN tokens (shared ring, its start cell, or
     *     the home column). Multiple own tokens may therefore share a square,
     *     and a base token may still leave on a six even when the start cell
     *     already holds one of its own tokens.
     *   - Only OPPONENT tokens are ever affected by a landing (see captures);
     *     own tokens on the destination are left untouched.
     *
     * Move legality is otherwise purely geometric (see isLegalTokenMove):
     * leave base only on a six, never overshoot home (land exactly on 56),
     * finished tokens are immovable. Every geometrically legal token is
     * therefore returned here.
     *
     * @param  array<string,int[]>  $tokens  color => [rel,rel,rel,rel]
     * @return array<int,array{token:int,from:int,to:int,captures:int[]}>
     *         indexed list of legal moves; `captures` lists opponent token
     *         indexes (within their own color array) that would be sent home.
     */
    public function legalMoves(string $color, int $dice, array $tokens): array
    {
        $color = strtolower($color);
        $moves = [];

        $own = $tokens[$color] ?? [];

        foreach ($own as $tokenIndex => $rel) {
            if (! $this->isLegalTokenMove($rel, $dice)) {
                continue;
            }

            $to = $this->destinationRel($rel, $dice);

            // Own-token stacking is allowed: landing on a cell occupied by one
            // of our own tokens is legal, so every geometrically legal token is
            // included. Only opponents are affected on arrival (see captures).
            $moves[] = [
                'token'    => $tokenIndex,
                'from'     => $rel,
                'to'       => $to,
                'captures' => $this->captureTargets($color, $to, $tokens),
            ];
        }

        return $moves;
    }

    /**
     * Does the moving color have ANY legal move for this dice value?
     */
    public function hasAnyLegalMove(string $color, int $dice, array $tokens): bool
    {
        return $this->legalMoves($color, $dice, $tokens) !== [];
    }

    /**
     * Apply a validated move and return the new token map plus metadata.
     *
     * The caller MUST have already confirmed the move is legal (e.g. via
     * legalMoves()). This method recomputes captures defensively but trusts
     * the geometry of (color, tokenIndex, dice).
     *
     * @param  array<string,int[]>  $tokens
     * @return array{
     *     tokens: array<string,int[]>,
     *     from: int,
     *     to: int,
     *     captured: array<int,array{color:string,token:int,from:int}>,
     *     finished: bool,
     *     extra_turn: bool
     * }
     *
     * @throws \InvalidArgumentException when the move is not legal.
     */
    public function applyMove(string $color, int $tokenIndex, int $dice, array $tokens): array
    {
        $color = strtolower($color);

        if (! isset($tokens[$color][$tokenIndex])) {
            throw new \InvalidArgumentException("Unknown token {$color}#{$tokenIndex}.");
        }

        $from = $tokens[$color][$tokenIndex];

        if (! $this->isLegalTokenMove($from, $dice)) {
            throw new \InvalidArgumentException('Illegal token move for the given dice.');
        }

        $to = $this->destinationRel($from, $dice);

        // Own-token stacking is allowed: there is no rejection when the
        // destination is already held by one of our own tokens (shared ring,
        // start cell, or home column). Only opponent tokens on the destination
        // are captured (resolved below); own tokens simply share the square.

        // Resolve captures (opponent tokens sharing the destination ring cell,
        // unless the cell is safe, and never inside home columns).
        $captured = [];
        $captureIndexes = $this->captureTargets($color, $to, $tokens);
        $destAbsolute = $this->absolutePos($color, $to);

        // Move the token.
        $tokens[$color][$tokenIndex] = $to;

        // Send captured opponents back to base.
        if ($destAbsolute !== null && ! empty($captureIndexes)) {
            foreach ($tokens as $oppColor => $oppTokens) {
                if ($oppColor === $color) {
                    continue;
                }
                foreach ($oppTokens as $i => $oppRel) {
                    $oppAbsolute = $this->absolutePos($oppColor, $oppRel);
                    if ($oppAbsolute !== null && $oppAbsolute === $destAbsolute) {
                        $tokens[$oppColor][$i] = $this->relBase;
                        $captured[] = [
                            'color' => $oppColor,
                            'token' => $i,
                            'from' => $oppRel,
                        ];
                    }
                }
            }
        }

        $finished = ($to === $this->relHome);
        $captureHappened = $captured !== [];

        return [
            'tokens'     => $tokens,
            'from'       => $from,
            'to'         => $to,
            'captured'   => $captured,
            'finished'   => $finished,
            'extra_turn' => $this->grantsExtraTurn($dice, $captureHappened, $finished),
        ];
    }

    /**
     * Extra turn is granted when ANY of:
     *   - dice == 6
     *   - a capture happened this move
     *   - a token reached home (rel 56)
     */
    public function grantsExtraTurn(int $dice, bool $captureHappened, bool $reachedHome): bool
    {
        return $dice === $this->extraTurnRoll || $captureHappened || $reachedHome;
    }

    /**
     * A color wins when all of its tokens are finished (rel 56).
     *
     * @param  int[]  $colorTokens
     */
    public function isWinner(array $colorTokens): bool
    {
        if (count($colorTokens) !== $this->tokensPerPlayer) {
            return false;
        }

        foreach ($colorTokens as $rel) {
            if ($rel !== $this->relHome) {
                return false;
            }
        }

        return true;
    }

    /**
     * Number of a color's tokens that have reached home — used for placement
     * ranking when a match ends early.
     *
     * @param  int[]  $colorTokens
     */
    public function finishedCount(array $colorTokens): int
    {
        return count(array_filter($colorTokens, fn ($rel) => $rel === $this->relHome));
    }

    /**
     * Should this roll forfeit the move because it is the Nth consecutive six?
     * When the player has already rolled (maxConsecutiveSixes - 1) sixes and
     * rolls another six, the move is forfeited and the turn ends.
     *
     * @param  int  $consecutiveSixesBeforeThisRoll  count of 6s already rolled this turn
     * @param  int  $dice                             the roll just made
     */
    public function isForfeitedThirdSix(int $consecutiveSixesBeforeThisRoll, int $dice): bool
    {
        return $dice === $this->extraTurnRoll
            && ($consecutiveSixesBeforeThisRoll + 1) >= $this->maxConsecutiveSixes;
    }

    /**
     * Opponent token indexes that would be captured if `$color` lands on
     * relative position `$to`. Captures occur only on shared-ring cells that
     * are NOT safe, and never inside home columns.
     *
     * The returned flat index list is intended for capture detection
     * ("did a capture happen / how many"); the authoritative apply step in
     * applyMove() resolves the precise (color, index) pairs to send to base.
     *
     * @param  array<string,int[]>  $tokens
     * @return int[]
     */
    private function captureTargets(string $color, int $to, array $tokens): array
    {
        $destAbsolute = $this->absolutePos($color, $to);

        // No captures off-ring or on safe cells.
        if ($destAbsolute === null || $this->isSafeCell($destAbsolute)) {
            return [];
        }

        $targets = [];
        foreach ($tokens as $oppColor => $oppTokens) {
            if (strtolower($oppColor) === $color) {
                continue;
            }
            foreach ($oppTokens as $i => $oppRel) {
                $oppAbsolute = $this->absolutePos($oppColor, $oppRel);
                if ($oppAbsolute !== null && $oppAbsolute === $destAbsolute) {
                    $targets[] = $i;
                }
            }
        }

        return $targets;
    }

    /**
     * Build the initial token map for a set of colors (all tokens in base).
     *
     * @param  string[]  $colors
     * @return array<string,int[]>
     */
    public function initialTokens(array $colors): array
    {
        $map = [];
        foreach ($colors as $color) {
            $map[strtolower($color)] = array_fill(0, $this->tokensPerPlayer, $this->relBase);
        }

        return $map;
    }
}
