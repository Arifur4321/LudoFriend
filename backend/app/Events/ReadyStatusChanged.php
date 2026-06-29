<?php

namespace App\Events;

use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class ReadyStatusChanged implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public function __construct(
        public int $roomId,
        public int $roomPlayerId,
        public bool $isReady,
    ) {
    }

    public function broadcastOn(): array
    {
        return [new PrivateChannel("room.{$this->roomId}")];
    }

    public function broadcastAs(): string
    {
        return 'room.ready_changed';
    }

    public function broadcastWith(): array
    {
        return [
            'room_id' => $this->roomId,
            'room_player_id' => $this->roomPlayerId,
            'is_ready' => $this->isReady,
        ];
    }
}
