<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class MatchResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'room_id' => $this->room_id,
            'mode' => $this->mode,
            'status' => $this->status,
            'winner_user_id' => $this->winner_user_id,
            'seed' => $this->seed,
            'started_at' => $this->started_at,
            'ended_at' => $this->ended_at,
            'players' => $this->whenLoaded('players', fn () => $this->players->map(fn ($p) => [
                'user_id' => $p->user_id,
                'color' => $p->color,
                'seat' => (int) $p->seat,
                'is_bot' => (bool) $p->is_bot,
                'placement' => $p->placement,
            ])),
            // Authoritative state snapshot (token map, turn, phase, dice...).
            'state' => $this->whenLoaded('state', fn () => optional($this->state)->state),
            'version' => $this->whenLoaded('state', fn () => optional($this->state)->version),
        ];
    }
}
