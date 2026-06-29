<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

class MatchEventResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'seq' => (int) $this->seq,
            'actor_color' => $this->actor_color,
            'type' => $this->type,
            'payload' => $this->payload,
            'server_time' => $this->server_time,
        ];
    }
}
