<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AuthTest extends TestCase
{
    use RefreshDatabase;

    public function test_user_can_register_and_receive_token(): void
    {
        $response = $this->postJson('/api/v1/auth/register', [
            'name' => 'Arifur',
            'email' => 'arifur@example.com',
            'password' => 'Passw0rd!',
            'password_confirmation' => 'Passw0rd!',
        ]);

        $response->assertCreated()
            ->assertJsonStructure(['token', 'token_type', 'user' => ['id', 'name', 'profile']]);

        $this->assertDatabaseHas('users', ['email' => 'arifur@example.com', 'is_guest' => false]);
        $this->assertDatabaseHas('player_profiles', ['display_name' => 'Arifur']);
    }

    public function test_user_can_login_with_valid_credentials(): void
    {
        User::factory()->create(['email' => 'p@example.com']); // password = 'password'

        $response = $this->postJson('/api/v1/auth/login', [
            'email' => 'p@example.com',
            'password' => 'password',
        ]);

        $response->assertOk()->assertJsonStructure(['token']);
    }

    public function test_login_fails_with_invalid_credentials(): void
    {
        User::factory()->create(['email' => 'p@example.com']);

        $this->postJson('/api/v1/auth/login', [
            'email' => 'p@example.com',
            'password' => 'wrong-password',
        ])->assertStatus(422);
    }

    public function test_banned_user_cannot_login(): void
    {
        User::factory()->banned()->create(['email' => 'b@example.com']);

        $this->postJson('/api/v1/auth/login', [
            'email' => 'b@example.com',
            'password' => 'password',
        ])->assertStatus(422);
    }

    public function test_me_requires_authentication(): void
    {
        $this->getJson('/api/v1/me')->assertUnauthorized();
    }

    public function test_api_authentication_returns_json_without_accept_header(): void
    {
        $this->get('/api/v1/leaderboard')
            ->assertUnauthorized()
            ->assertJson(['message' => 'Unauthenticated.']);
    }
}
