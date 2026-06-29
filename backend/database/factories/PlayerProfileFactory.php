<?php

namespace Database\Factories;

use App\Models\PlayerProfile;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<PlayerProfile>
 */
class PlayerProfileFactory extends Factory
{
    protected $model = PlayerProfile::class;

    public function definition(): array
    {
        return [
            'user_id' => User::factory(),
            'display_name' => fake()->userName(),
            'avatar' => null,
            'coins' => 500,
            'matches_played' => 0,
            'wins' => 0,
            'losses' => 0,
            'best_streak' => 0,
            'current_streak' => 0,
        ];
    }
}
