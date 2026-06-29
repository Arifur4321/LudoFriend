<?php

namespace App\Events;

use App\Http\Resources\RoomPlayerResource;
use App\Models\GameRoomPlayer;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class PlayerJoinedRoom implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public function __construct(
        public int $roomId,
        public int $roomPlayerId,
    ) {
    }

    public function broadcastOn(): array
    {
        return [new PrivateChannel("room.{$this->roomId}")];
    }

    public function broadcastAs(): string
    {
        return 'room.player_joined';
    }

    public function broadcastWith(): array
    {
        $player = GameRoomPlayer::with('user')->find($this->roomPlayerId);

        return [
            'room_id' => $this->roomId,
            'player' => $player ? (new RoomPlayerResource($player))->resolve() : null,
        ];
    }
}
