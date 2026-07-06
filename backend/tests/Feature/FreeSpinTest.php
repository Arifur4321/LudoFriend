<?php

namespace Tests\Feature;

use App\Models\PlayerProfile;
use App\Models\User;
use App\Services\Economy\WalletService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class FreeSpinTest extends TestCase
{
    use RefreshDatabase;

    private function user(int $coins = 500): User
    {
        $u = User::factory()->create();
        PlayerProfile::factory()->create(['user_id' => $u->id, 'coins' => $coins]);

        return $u;
    }

    public function test_spin_awards_a_configured_reward_and_credits_coins(): void
    {
        $u = $this->user(500);
        $rewards = array_column(config('economy.free_spin.segments'), 'reward');

        $res = $this->actingAs($u)->postJson('/api/v1/spin')->assertOk()->json();

        $this->assertContains($res['reward'], $rewards);
        $this->assertSame(500 + $res['reward'], $res['balance']);
        $this->assertSame(500 + $res['reward'], app(WalletService::class)->balance($u));
        $this->assertArrayHasKey('next_available_at', $res);
        $this->assertDatabaseHas('daily_spins', ['user_id' => $u->id, 'reward' => $res['reward']]);
        $this->assertDatabaseHas('wallet_transactions', ['user_id' => $u->id, 'type' => 'spin']);
    }

    public function test_spin_is_blocked_during_the_cooldown(): void
    {
        $u = $this->user(500);

        $this->actingAs($u)->postJson('/api/v1/spin')->assertOk();
        // Immediately again — still within the 60-minute interval.
        $this->actingAs($u)->postJson('/api/v1/spin')->assertStatus(422);

        $this->actingAs($u)->getJson('/api/v1/spin/status')->assertOk()
            ->assertJsonPath('can_spin', false)
            ->assertJsonPath('interval_minutes', 60);

        $this->assertSame(1, \App\Models\DailySpin::where('user_id', $u->id)->count());
    }

    public function test_spin_becomes_available_after_the_interval(): void
    {
        $u = $this->user(500);

        $this->actingAs($u)->postJson('/api/v1/spin')->assertOk();
        $this->actingAs($u)->getJson('/api/v1/spin/status')->assertJsonPath('can_spin', false);

        // Advance past the cooldown window.
        $this->travel(61)->minutes();

        $this->actingAs($u)->getJson('/api/v1/spin/status')->assertJsonPath('can_spin', true);
        $this->actingAs($u)->postJson('/api/v1/spin')->assertOk();

        $this->assertSame(2, \App\Models\DailySpin::where('user_id', $u->id)->count());

        $this->travelBack();
    }

    public function test_weighted_distribution_stays_within_bounds(): void
    {
        $service = app(\App\Services\Economy\FreeSpinService::class);
        $rewards = array_column(config('economy.free_spin.segments'), 'reward');

        $ref = new \ReflectionMethod($service, 'pickWeighted');
        $ref->setAccessible(true);

        $jackpots = 0;
        for ($i = 0; $i < 200; $i++) {
            [$reward] = $ref->invoke($service);
            $this->assertContains($reward, $rewards);
            if ($reward === 20000) {
                $jackpots++;
            }
        }
        $this->assertLessThan(30, $jackpots, 'Jackpot should be rare.');
    }
}
