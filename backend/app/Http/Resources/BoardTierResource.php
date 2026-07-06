<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** Wraps a plain tier config array from config/economy.php. */
class BoardTierResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'key' => $this['key'],
            'name' => $this['name'],
            'stake' => (int) $this['stake'],
            'order' => (int) ($this['order'] ?? 0),
            'modes' => $this['modes'] ?? ['2p', '4p'],
            'team' => (bool) ($this['team'] ?? false),
            'accent' => $this['accent'] ?? null,
            'badge' => $this['badge'] ?? null,
            'description' => $this['description'] ?? null,
        ];
    }
}
