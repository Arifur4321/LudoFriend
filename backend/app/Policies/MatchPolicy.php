<?php

namespace App\Policies;

use App\Models\Matchup;
use App\Models\User;

/**
 * MatchPolicy — in-match authorization.
 *
 *   - Only a seated participant may view match state.
 *   - Only the owner of a color may roll/move (the engine additionally checks
 *     that it is actually that color's turn).
 */
class MatchPolicy
{
    /** Any participant of the match may view its state. */
    public function view(User $user, Matchup $match): bool
    {
        return $this->seatOf($user, $match) !== null;
    }

    /** Only the human that owns `$color` may act on that color. */
    public function act(User $user, Matchup $match, string $color): bool
    {
        $seat = $this->seatOf($user, $match);

        return $seat !== null
            && ! $seat->is_bot
            && strtolower($seat->color) === strtolower($color);
    }

    /**
     * Return the user's match-player seat, or null if they are not in it.
     */
    private function seatOf(User $user, Matchup $match): ?\App\Models\MatchPlayer
    {
        return $match->players()->where('user_id', $user->id)->first();
    }
}
