<?php

namespace App\Policies;

use App\Models\GameRoom;
use App\Models\User;

/**
 * RoomPolicy — lobby authorization.
 *
 *   - Only the host may start or (re)configure the room.
 *   - Only seated players may act on / view a private room.
 */
class RoomPolicy
{
    /** Anyone authenticated may view a public room; private rooms need a seat. */
    public function view(User $user, GameRoom $room): bool
    {
        if ($room->visibility === 'public') {
            return true;
        }

        return $this->isSeated($user, $room);
    }

    /** Only seated players may leave / toggle ready. */
    public function participate(User $user, GameRoom $room): bool
    {
        return $this->isSeated($user, $room);
    }

    /** Only the host may start the match. */
    public function start(User $user, GameRoom $room): bool
    {
        return $room->host_user_id === $user->id;
    }

    /** Only the host may change room configuration. */
    public function configure(User $user, GameRoom $room): bool
    {
        return $room->host_user_id === $user->id;
    }

    private function isSeated(User $user, GameRoom $room): bool
    {
        return $room->players()->where('user_id', $user->id)->exists();
    }
}
