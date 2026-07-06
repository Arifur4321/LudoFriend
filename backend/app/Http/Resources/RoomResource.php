<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class RoomResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'code' => $this->code,
            'host_user_id' => $this->host_user_id,
            'mode' => $this->mode,
            'board_tier' => $this->board_tier,
            'stake' => (int) $this->stake,
            'team_mode' => (bool) $this->team_mode,
            'visibility' => $this->visibility,
            'bot_fill' => (bool) $this->bot_fill,
            'turn_timer_seconds' => (int) $this->turn_timer_seconds,
            'status' => $this->status,
            'capacity' => $this->capacity(),
            'settings' => $this->settings,
            'players' => RoomPlayerResource::collection($this->whenLoaded('players')),
            'match_id' => $this->whenLoaded('matchup', fn () => $this->matchup?->id),
            'created_at' => $this->created_at,
        ];
    }
}
