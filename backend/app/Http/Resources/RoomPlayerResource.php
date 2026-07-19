<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class RoomPlayerResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $isBot = (bool) $this->is_bot;
        $human = ! $isBot && $this->relationLoaded('user') && $this->user ? $this->user : null;

        return [
            'id' => $this->id,
            'seat' => (int) $this->seat,
            'color' => $this->color,
            'team' => $this->team !== null ? (int) $this->team : null,
            'is_bot' => $isBot,
            'is_ready' => (bool) $this->is_ready,
            // Seat-level label/photo that works for humans, bots and still-empty
            // seats alike. Bots surface their persisted realistic name (never a
            // generic "Bot"); the client renders initials when avatar is null.
            'display_name' => $isBot ? ($this->display_name ?: 'Player') : ($human?->name),
            'avatar' => $isBot ? config('bots.default_avatar') : ($human?->avatar),
            'user' => $this->when(
                (bool) $human,
                fn () => [
                    'id' => $this->user->id,
                    'name' => $this->user->name,
                    'avatar' => $this->user->avatar,
                    'is_guest' => (bool) $this->user->is_guest,
                ]
            ),
        ];
    }
}
