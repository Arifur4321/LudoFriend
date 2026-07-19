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
            'board_tier' => $this->board_tier,
            'stake' => (int) $this->stake,
            'pot' => (int) $this->pot,
            'team_mode' => (bool) $this->team_mode,
            'status' => $this->status,
            'winner_user_id' => $this->winner_user_id,
            'seed' => $this->seed,
            'started_at' => $this->started_at,
            'ended_at' => $this->ended_at,
            'players' => $this->whenLoaded('players', fn () => $this->players->map(fn ($p) => [
                'user_id' => $p->user_id,
                // Bots surface their persisted realistic display name (never a
                // generic "Bot"); humans use their linked account name.
                'name' => $p->is_bot ? ($p->display_name ?: 'Player') : optional($p->user)->name,
                'avatar' => $p->is_bot ? config('bots.default_avatar') : optional($p->user)->avatar,
                'is_guest' => $p->is_bot ? false : (bool) optional($p->user)->is_guest,
                'color' => $p->color,
                'team' => $p->team !== null ? (int) $p->team : null,
                'seat' => (int) $p->seat,
                'is_bot' => (bool) $p->is_bot,
                'placement' => $p->placement,
                'payout' => (int) $p->payout,
            ])),
            // Authoritative state snapshot (token map, turn, phase, dice...).
            'state' => $this->whenLoaded('state', fn () => optional($this->state)->state),
            'version' => $this->whenLoaded('state', fn () => optional($this->state)->version),
        ];
    }
}
