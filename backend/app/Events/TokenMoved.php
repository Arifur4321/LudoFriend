<?php

namespace App\Events;

use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

// ShouldBroadcastNow: deliver the move to the opponent's phone immediately after
// commit rather than waiting on a queue worker (see DiceRolled for the rationale).
class TokenMoved implements ShouldBroadcastNow
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    /**
     * @param  int[]  $path
     * @param  array<int,array{color:string,token:int,from:int}>  $captured
     */
    public function __construct(
        public int $matchId,
        public string $color,
        public int $token,
        public int $from,
        public int $to,
        public array $path,
        public array $captured = [],
        public ?int $sequence = null,
    ) {}

    public function broadcastOn(): array
    {
        return [new PrivateChannel("match.{$this->matchId}")];
    }

    public function broadcastAs(): string
    {
        return 'game.token_moved';
    }

    public function broadcastWith(): array
    {
        return [
            'match_id' => $this->matchId,
            'color' => $this->color,
            'token' => $this->token,
            'from' => $this->from,
            'to' => $this->to,
            'path' => $this->path,
            'captured' => $this->captured,
            'move_seq' => $this->sequence,
        ];
    }
}
