<?php

namespace App\Events;

use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

/**
 * An ephemeral emoji reaction floated over the board. Not persisted.
 */
class EmojiReactionSent implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public function __construct(
        public int $matchId,
        public ?int $userId,
        public ?string $color,
        public string $emoji,
    ) {
    }

    public function broadcastOn(): array
    {
        return [new PrivateChannel("match.{$this->matchId}")];
    }

    public function broadcastAs(): string
    {
        return 'chat.emoji';
    }

    public function broadcastWith(): array
    {
        return [
            'match_id' => $this->matchId,
            'user_id' => $this->userId,
            'color' => $this->color,
            'emoji' => $this->emoji,
        ];
    }
}
