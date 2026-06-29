<?php

namespace App\Events;

use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class TurnChanged implements ShouldBroadcast
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
        return 'game.turn_changed';
    }

    public function broadcastWith(): array
    {
        return [
            'match_id' => $this->matchId,
            'turn' => $this->color,
        ];
    }
}
