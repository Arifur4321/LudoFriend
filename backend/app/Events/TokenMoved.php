<?php

namespace App\Events;

use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class TokenMoved implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    /**
     * @param  array<int,array{color:string,token:int}>  $captured
     */
    public function __construct(
        public int $matchId,
        public string $color,
        public int $token,
        public int $from,
        public int $to,
        public array $captured = [],
    ) {
    }

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
            'captured' => $this->captured,
        ];
    }
}
