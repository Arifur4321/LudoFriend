<?php

namespace App\Events;

use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

/**
 * A chat message on the match channel. Broadcast to every participant (the
 * sender included) so the log is a single authoritative stream.
 */
class ChatMessageSent implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public function __construct(
        public int $matchId,
        public ?int $userId,
        public ?string $name,
        public ?string $color,
        public string $body,
        public int $ts,
    ) {
    }

    public function broadcastOn(): array
    {
        return [new PrivateChannel("match.{$this->matchId}")];
    }

    public function broadcastAs(): string
    {
        return 'chat.message';
    }

    public function broadcastWith(): array
    {
        return [
            'match_id' => $this->matchId,
            'user_id' => $this->userId,
            'name' => $this->name,
            'color' => $this->color,
            'body' => $this->body,
            'ts' => $this->ts,
        ];
    }
}
