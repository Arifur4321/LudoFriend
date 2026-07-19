<?php

namespace App\Services\Game;

/**
 * BotStrategyService — chooses ONE legal token for a bot seat to move.
 *
 * Server-authoritative and deterministic given the same inputs. This does NOT
 * change any Ludo rule or dice probability; it only decides, among the moves
 * the engine has ALREADY validated as legal, which token the bot plays.
 *
 * Priority (a simple, sensible heuristic — not a change to the ruleset):
 *   1. Capture an opponent (prefer the move that captures the most tokens).
 *   2. Finish a token (land exactly on home).
 *   3. Release a token from base (get more tokens into play).
 *   4. Otherwise advance the token that is furthest along the track.
 * Ties break to the lowest token index for reproducibility across devices.
 */
class BotStrategyService
{
    /**
     * @param  array<int,array{token:int,from:int,to:int,captures?:array<int,mixed>}>  $legalMoves
     */
    public function chooseToken(array $legalMoves): int
    {
        if ($legalMoves === []) {
            throw new \InvalidArgumentException('No legal moves to choose from.');
        }

        $relHome = (int) config('ludo.rel_home', 56);
        $relBase = (int) config('ludo.rel_base', -1);

        $best = null;
        $bestScore = null;

        foreach ($legalMoves as $move) {
            $captures = count($move['captures'] ?? []);
            $finishes = ((int) $move['to'] === $relHome) ? 1 : 0;
            $leavesBase = ((int) $move['from'] === $relBase) ? 1 : 0;
            $progress = (int) $move['from'];

            // Lexicographic score: captures dominate, then finishing, then
            // leaving base, then raw progress.
            $score = [$captures, $finishes, $leavesBase, $progress];

            if ($bestScore === null || $this->greater($score, $bestScore)) {
                $bestScore = $score;
                $best = (int) $move['token'];
            }
        }

        return $best ?? (int) $legalMoves[0]['token'];
    }

    /**
     * Strict lexicographic comparison of two equal-length score vectors.
     *
     * @param  int[]  $a
     * @param  int[]  $b
     */
    private function greater(array $a, array $b): bool
    {
        $len = count($a);
        for ($i = 0; $i < $len; $i++) {
            if ($a[$i] !== $b[$i]) {
                return $a[$i] > $b[$i];
            }
        }

        // Equal → keep the earlier (lower token index) choice.
        return false;
    }
}
