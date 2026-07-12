<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * A single persisted chat message. `name`/`avatar` come from the related user
 * (server-authoritative — never from client input) so the same identity is
 * shown to everyone regardless of how the sender authenticated.
 *
 * @mixin \App\Models\MatchMessage
 */
class MatchMessageResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => (int) $this->id,
            'client_id' => $this->client_id,
            'user_id' => $this->user_id,
            'name' => $this->whenLoaded('user', fn () => optional($this->user)->name),
            'avatar' => $this->whenLoaded('user', fn () => optional($this->user)->avatar),
            'color' => $this->color,
            'type' => $this->type,
            'body' => $this->body,
            'ts' => optional($this->created_at)->toIso8601String(),
        ];
    }
}
