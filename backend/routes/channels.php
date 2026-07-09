<?php

use App\Models\GameRoom;
use App\Models\Matchup;
use App\Models\User;
use Illuminate\Support\Facades\Broadcast;

/*
|--------------------------------------------------------------------------
| Broadcast Channels
|--------------------------------------------------------------------------
|
| Private channels for rooms and matches. Authorization returns true only for
| users who are actually seated in the room / match (or, for public rooms, any
| authenticated user). Anything else is rejected by Reverb/Pusher auth.
|
*/

/**
 * room.{roomId} — lobby events (joins, leaves, ready, game start).
 * Allowed for seated players; also allowed for any authenticated user on a
 * public room so they can watch the lobby fill.
 */
Broadcast::channel('room.{roomId}', function (User $user, int $roomId) {
    $room = GameRoom::find($roomId);
    if (! $room) {
        return false;
    }

    if ($room->visibility === 'public') {
        return true;
    }

    return $room->players()->where('user_id', $user->id)->exists();
});

/**
 * match.{matchId} — in-game events (dice, moves, turn changes, end).
 * Allowed only for participants of that match.
 */
Broadcast::channel('match.{matchId}', function (User $user, int $matchId) {
    $match = Matchup::find($matchId);
    if (! $match) {
        return false;
    }

    return $match->players()->where('user_id', $user->id)->exists();
});

/**
 * user.{id} — a private channel for the user themselves. Used for directed
 * notifications like friend "come play" room invites.
 */
Broadcast::channel('user.{id}', function (User $user, int $id) {
    return (int) $user->id === (int) $id;
});
