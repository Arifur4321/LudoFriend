<?php

namespace App\Events;

use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

/**
 * A "come play" invite delivered to a specific user's private channel so they
 * can one-tap join the inviter's room.
 *
 * @param  array{id:int,name:?string,avatar:?string}  $from
 */
class FriendRoomInvite implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public function __construct(
        public int $toUserId,
        public int $roomId,
        public string $code,
        public array $from,
    ) {
    }

    public function broadcastOn(): array
    {
        return [new PrivateChannel("user.{$this->toUserId}")];
    }

    public function broadcastAs(): string
    {
        return 'friend.invite';
    }

    public function broadcastWith(): array
    {
        return [
            'room_id' => $this->roomId,
            'code' => $this->code,
            'from' => $this->from,
        ];
    }
}
