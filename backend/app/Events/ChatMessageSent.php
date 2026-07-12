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
 *
 * Carries the persisted `id` (stable ordering + de-duplication key) and the
 * originating `clientId` so the sender can reconcile its optimistic bubble with
 * the authoritative row instead of showing it twice. `name`/`avatar` are taken
 * from the authenticated user server-side — never from client input.
 */
class ChatMessageSent implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public function __construct(
        public int $matchId,
        public int $id,
        public ?string $clientId,
        public ?int $userId,
        public ?string $name,
        public ?string $avatar,
        public ?string $color,
        public string $body,
        public string $ts,
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
            'id' => $this->id,
            'client_id' => $this->clientId,
            'user_id' => $this->userId,
            'name' => $this->name,
            'avatar' => $this->avatar,
            'color' => $this->color,
            'body' => $this->body,
            'ts' => $this->ts,
        ];
    }
}
