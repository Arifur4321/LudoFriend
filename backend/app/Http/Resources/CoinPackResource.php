<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** Wraps a plain coin-pack config array from config/economy.php. */
class CoinPackResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'product_id' => $this['product_id'],
            'label' => $this['label'] ?? null,
            'coins' => (int) $this['coins'],
            'bonus' => (int) ($this['bonus'] ?? 0),
            'total_coins' => (int) $this['coins'] + (int) ($this['bonus'] ?? 0),
            'price' => $this['price'] ?? null,
            'popular' => (bool) ($this['popular'] ?? false),
            'best_value' => (bool) ($this['best_value'] ?? false),
        ];
    }
}
