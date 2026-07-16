<?php

namespace App\Events;

use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

// ShouldBroadcastNow: the turn hand-off is the most latency-sensitive event —
// the next player's dice stays disabled until they learn it is their turn, so
// deliver it immediately after commit rather than via the shared queue.
class TurnChanged implements ShouldBroadcastNow
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
