<?php

namespace App\Events;

use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

/**
 * An ephemeral emoji reaction floated over the board. Not persisted.
 *
 * Carries a stable `id` (a per-send uuid) so every client — including the
 * sender — can de-duplicate the reaction and never play it twice. `name`/`color`
 * identify the sender authoritatively (from the seated player, not the client).
 */
class EmojiReactionSent implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public function __construct(
        public int $matchId,
        public string $id,
        public ?int $userId,
        public ?string $name,
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
            'id' => $this->id,
            'user_id' => $this->userId,
            'name' => $this->name,
            'color' => $this->color,
            'emoji' => $this->emoji,
        ];
    }
}
