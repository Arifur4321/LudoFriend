<?php

namespace Tests\Feature;

use App\Models\User;
use App\Services\RoomService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Event;
use Tests\TestCase;

class ReconnectTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        Event::fake();
    }

    public function test_participant_can_reconnect_and_receive_full_state(): void
    {
        $red = User::factory()->create();
        $green = User::factory()->create();

        $rooms = app(RoomService::class);
        $room = $rooms->create($red, ['mode' => '2p', 'visibility' => 'private']);
        $rooms->join($room, $green);
        $rooms->setReady($room, $red, true);
        $rooms->setReady($room, $green, true);
        $match = $rooms->start($room);

        $response = $this->actingAs($red)
            ->postJson("/api/v1/matches/{$match->id}/reconnect");

        $response->assertOk()
            ->assertJsonStructure(['data' => ['id', 'state', 'players']]);

        // The reconnect timestamp is recorded for the player's seat.
        $this->assertDatabaseHas('match_players', [
            'match_id' => $match->id,
            'user_id' => $red->id,
        ]);
        $this->assertNotNull(
            $match->players()->where('user_id', $red->id)->first()->reconnected_at
        );
    }

    public function test_non_participant_cannot_reconnect(): void
    {
        $red = User::factory()->create();
        $green = User::factory()->create();
        $stranger = User::factory()->create();

        $rooms = app(RoomService::class);
        $room = $rooms->create($red, ['mode' => '2p', 'visibility' => 'private']);
        $rooms->join($room, $green);
        $rooms->setReady($room, $red, true);
        $rooms->setReady($room, $green, true);
        $match = $rooms->start($room);

        $this->actingAs($stranger)
            ->postJson("/api/v1/matches/{$match->id}/reconnect")
            ->assertForbidden();
    }
}
