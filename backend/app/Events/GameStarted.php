<?php

namespace App\Events;

use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class GameStarted implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    /**
     * @param  string[]  $turnOrder
     */
    public function __construct(
        public int $roomId,
        public int $matchId,
        public array $turnOrder,
    ) {
    }

    public function broadcastOn(): array
    {
        return [new PrivateChannel("room.{$this->roomId}")];
    }

    public function broadcastAs(): string
    {
        return 'game.started';
    }

    public function broadcastWith(): array
    {
        return [
            'room_id' => $this->roomId,
            'match_id' => $this->matchId,
            'turn_order' => $this->turnOrder,
        ];
    }
}
