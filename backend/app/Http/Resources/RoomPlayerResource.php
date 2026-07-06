<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class RoomPlayerResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'seat' => (int) $this->seat,
            'color' => $this->color,
            'team' => $this->team !== null ? (int) $this->team : null,
            'is_bot' => (bool) $this->is_bot,
            'is_ready' => (bool) $this->is_ready,
            'user' => $this->when(
                ! $this->is_bot && $this->relationLoaded('user') && $this->user,
                fn () => [
                    'id' => $this->user->id,
                    'name' => $this->user->name,
                    'avatar' => $this->user->avatar,
                ]
            ),
        ];
    }
}
