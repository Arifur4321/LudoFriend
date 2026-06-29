<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class LeaderboardResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'rank' => $this->rank,
            'user' => [
                'id' => $this->user_id,
                'name' => $this->whenLoaded('user', fn () => $this->user?->name),
                'avatar' => $this->whenLoaded('user', fn () => $this->user?->avatar),
            ],
            'period' => $this->period,
            'wins' => (int) $this->wins,
            'games' => (int) $this->games,
            'rating' => (int) $this->rating,
        ];
    }
}
