<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class ProfileResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'user_id' => $this->user_id,
            'display_name' => $this->display_name,
            'avatar' => $this->avatar,
            'coins' => (int) $this->coins,
            'matches_played' => (int) $this->matches_played,
            'wins' => (int) $this->wins,
            'losses' => (int) $this->losses,
            'best_streak' => (int) $this->best_streak,
            'current_streak' => (int) $this->current_streak,
        ];
    }
}
