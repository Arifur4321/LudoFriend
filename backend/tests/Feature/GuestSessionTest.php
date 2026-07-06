<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class GuestSessionTest extends TestCase
{
    use RefreshDatabase;

    public function test_guest_signin_creates_user_and_session(): void
    {
        $response = $this->postJson('/api/v1/auth/guest', [
            'device_id' => 'device-abc',
            'guest_name' => 'Anon',
        ]);

        $response->assertOk()->assertJsonStructure(['token', 'user' => ['id', 'is_guest']]);
        $response->assertJsonPath('user.is_guest', true);

        $this->assertDatabaseHas('guest_sessions', ['device_id' => 'device-abc']);
    }

    public function test_same_device_reuses_guest_account(): void
    {
        $first = $this->postJson('/api/v1/auth/guest', ['device_id' => 'device-xyz'])
            ->assertOk()->json('user.id');

        $second = $this->postJson('/api/v1/auth/guest', ['device_id' => 'device-xyz'])
            ->assertOk()->json('user.id');

        $this->assertSame($first, $second);
        $this->assertDatabaseCount('guest_sessions', 1);
    }

    public function test_guest_requires_device_id(): void
    {
        $this->postJson('/api/v1/auth/guest', [])->assertStatus(422);
    }

    public function test_guest_can_claim_hourly_free_spin(): void
    {
        $token = $this->postJson('/api/v1/auth/guest', [
            'device_id' => 'device-spin',
            'guest_name' => 'Spinner',
        ])->assertOk()->json('token');

        $this->withToken($token)->getJson('/api/v1/spin/status')
            ->assertOk()
            ->assertJsonPath('can_spin', true)
            ->assertJsonPath('interval_minutes', 60);

        $this->withToken($token)->postJson('/api/v1/spin')
            ->assertOk()
            ->assertJsonStructure(['reward', 'segment_index', 'balance', 'next_available_at']);

        $this->withToken($token)->getJson('/api/v1/spin/status')
            ->assertOk()
            ->assertJsonPath('can_spin', false);
    }
}
