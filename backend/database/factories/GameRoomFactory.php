<?php

namespace Database\Factories;

use App\Models\GameRoom;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Str;

/**
 * @extends Factory<GameRoom>
 */
class GameRoomFactory extends Factory
{
    protected $model = GameRoom::class;

    public function definition(): array
    {
        return [
            'code' => strtoupper(Str::random(6)),
            'host_user_id' => User::factory(),
            'mode' => '4p',
            'visibility' => 'private',
            'bot_fill' => false,
            'turn_timer_seconds' => 20,
            'status' => 'lobby',
            'settings' => null,
        ];
    }

    public function twoPlayer(): static
    {
        return $this->state(fn () => ['mode' => '2p']);
    }

    public function public(): static
    {
        return $this->state(fn () => ['visibility' => 'public']);
    }
}
