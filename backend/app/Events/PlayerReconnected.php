<?php

namespace App\Events;

use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class PlayerReconnected implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public function __construct(
        public int $matchId,
        public string $color,
    ) {
    }

    public function broadcastOn(): array
    {
        return [new PrivateChannel("match.{$this->matchId}")];
    }

    public function broadcastAs(): string
    {
        return 'game.player_reconnected';
    }

    public function broadcastWith(): array
    {
        return [
            'match_id' => $this->matchId,
            'color' => $this->color,
        ];
    }
}
