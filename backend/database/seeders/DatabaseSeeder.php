<?php

namespace Database\Seeders;

use App\Models\AppSetting;
use App\Models\PlayerProfile;
use App\Models\PlayerStat;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        // Default feature flags / tunables.
        AppSetting::put('maintenance', ['enabled' => false]);
        AppSetting::put('min_client_version', ['ios' => '1.0.0', 'android' => '1.0.0']);

        // An admin account for the back office.
        $admin = User::firstOrCreate(
            ['email' => 'admin@ludofriends.app'],
            [
                'name' => 'Admin',
                'password' => Hash::make('password'),
                'is_admin' => true,
            ]
        );
        PlayerProfile::firstOrCreate(['user_id' => $admin->id], [
            'display_name' => 'Admin',
            'coins' => config('ludo.starting_coins'),
        ]);
        PlayerStat::firstOrCreate(
            ['user_id' => $admin->id, 'period' => 'all_time'],
            ['rating' => config('ludo.rating_default')]
        );

        // A handful of demo players for the leaderboard.
        User::factory()
            ->count(10)
            ->create()
            ->each(function (User $u) {
                PlayerProfile::factory()->create(['user_id' => $u->id]);
                PlayerStat::create([
                    'user_id' => $u->id,
                    'period' => 'all_time',
                    'wins' => fake()->numberBetween(0, 50),
                    'games' => fake()->numberBetween(50, 100),
                    'rating' => fake()->numberBetween(800, 1600),
                ]);
            });
    }
}
