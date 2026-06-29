<?php

namespace Tests\Feature;

use App\Models\MatchmakingTicket;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Event;
use Tests\TestCase;

class MatchmakingTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        Event::fake();
    }

    public function test_player_can_enqueue(): void
    {
        $user = User::factory()->create();

        $this->actingAs($user)
            ->postJson('/api/v1/matchmaking/enqueue', ['mode' => '2p'])
            ->assertCreated()
            ->assertJsonPath('data.status', 'queued');

        $this->assertDatabaseHas('matchmaking_tickets', [
            'user_id' => $user->id,
            'mode' => '2p',
            'status' => 'queued',
        ]);
    }

    public function test_two_players_in_2p_are_paired_into_a_room(): void
    {
        $a = User::factory()->create();
        $b = User::factory()->create();

        $this->actingAs($a)->postJson('/api/v1/matchmaking/enqueue', ['mode' => '2p'])->assertCreated();
        $this->actingAs($b)->postJson('/api/v1/matchmaking/enqueue', ['mode' => '2p'])->assertCreated();

        // Both tickets should now be matched to the same room.
        $tickets = MatchmakingTicket::all();
        $this->assertCount(2, $tickets);
        $this->assertTrue($tickets->every(fn ($t) => $t->status === 'matched'));
        $this->assertSame(1, $tickets->pluck('room_id')->unique()->count());
    }

    public function test_player_can_cancel(): void
    {
        $user = User::factory()->create();
        $this->actingAs($user)->postJson('/api/v1/matchmaking/enqueue', ['mode' => '4p'])->assertCreated();

        $this->actingAs($user)->postJson('/api/v1/matchmaking/cancel')->assertOk();

        $this->assertDatabaseHas('matchmaking_tickets', [
            'user_id' => $user->id,
            'status' => 'cancelled',
        ]);
    }

    public function test_status_reports_queue_state(): void
    {
        $user = User::factory()->create();
        $this->actingAs($user)->postJson('/api/v1/matchmaking/enqueue', ['mode' => '4p'])->assertCreated();

        $this->actingAs($user)
            ->getJson('/api/v1/matchmaking/status')
            ->assertOk()
            ->assertJsonPath('data.status', 'queued');
    }
}
