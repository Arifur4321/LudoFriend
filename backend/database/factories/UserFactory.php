<?php

namespace Database\Factories;

use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

/**
 * @extends Factory<User>
 */
class UserFactory extends Factory
{
    protected $model = User::class;

    protected static ?string $password = null;

    public function definition(): array
    {
        return [
            'name' => fake()->name(),
            'email' => fake()->unique()->safeEmail(),
            'email_verified_at' => now(),
            'password' => static::$password ??= Hash::make('password'),
            'avatar' => null,
            'is_guest' => false,
            'is_admin' => false,
            'is_banned' => false,
            'remember_token' => Str::random(10),
        ];
    }

    public function guest(): static
    {
        return $this->state(fn () => [
            'is_guest' => true,
            'email' => null,
            'password' => null,
            'name' => 'Guest-'.Str::upper(Str::random(5)),
        ]);
    }

    public function admin(): static
    {
        return $this->state(fn () => ['is_admin' => true]);
    }

    public function banned(string $reason = 'Cheating'): static
    {
        return $this->state(fn () => [
            'is_banned' => true,
            'banned_reason' => $reason,
            'banned_at' => now(),
        ]);
    }
}
