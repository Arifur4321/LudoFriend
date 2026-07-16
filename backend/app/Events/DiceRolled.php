<?php

namespace App\Events;

use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

// ShouldBroadcastNow (not ShouldBroadcast): in-game events are delivered
// synchronously after the transaction commits, so a turn/dice/move reaches the
// opponent's phone immediately instead of waiting behind other jobs on the
// shared queue workers (the "board feels delayed / different between phones"
// symptom). The send is fired from GameEngineService::flushBroadcasts AFTER
// commit and is wrapped so a broadcast hiccup can never fail the committed play.
class DiceRolled implements ShouldBroadcastNow
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public function __construct(
        public int $matchId,
        public string $color,
        public int $dice,
        public bool $forfeited = false,
    ) {
    }

    public function broadcastOn(): array
    {
        return [new PrivateChannel("match.{$this->matchId}")];
    }

    public function broadcastAs(): string
    {
        return 'game.dice_rolled';
    }

    public function broadcastWith(): array
    {
        return [
            'match_id' => $this->matchId,
            'color' => $this->color,
            'dice' => $this->dice,
            'forfeited' => $this->forfeited,
        ];
    }
}
