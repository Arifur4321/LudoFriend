<?php

namespace Tests\Feature;

use App\Models\GameRoom;
use App\Models\User;
use App\Services\RoomService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Event;
use Tests\TestCase;

class RoomCreateJoinTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        Event::fake(); // suppress broadcast side-effects
    }

    public function test_host_can_create_room_and_is_seated(): void
    {
        $host = User::factory()->create();

        $response = $this->actingAs($host)->postJson('/api/v1/rooms', [
            'mode' => '4p',
            'visibility' => 'private',
        ]);

        $response->assertCreated()
            ->assertJsonPath('data.host_user_id', $host->id)
            ->assertJsonPath('data.status', 'lobby');

        $roomId = $response->json('data.id');
        $this->assertDatabaseHas('game_room_players', [
            'room_id' => $roomId,
            'user_id' => $host->id,
            'seat' => 0,
        ]);
    }

    public function test_player_can_join_room_by_code(): void
    {
        $host = User::factory()->create();
        $room = app(RoomService::class)->create($host, ['mode' => '4p', 'visibility' => 'private']);

        $joiner = User::factory()->create();

        $this->actingAs($joiner)
            ->postJson('/api/v1/rooms/join', ['code' => $room->code])
            ->assertOk();

        $this->assertDatabaseHas('game_room_players', [
            'room_id' => $room->id,
            'user_id' => $joiner->id,
        ]);
    }

    public function test_cannot_join_full_room(): void
    {
        $host = User::factory()->create();
        $rooms = app(RoomService::class);

        // 2-player room: host + 1 fills it.
        $room = $rooms->create($host, ['mode' => '2p', 'visibility' => 'private']);
        $rooms->join($room, User::factory()->create());

        $this->assertTrue($room->fresh()->isFull());

        $latecomer = User::factory()->create();
        $this->actingAs($latecomer)
            ->postJson('/api/v1/rooms/join', ['code' => $room->code])
            ->assertStatus(409)
            ->assertJsonPath('message', 'Room is full.');
    }

    public function test_join_is_idempotent_for_same_user(): void
    {
        $host = User::factory()->create();
        $room = app(RoomService::class)->create($host, ['mode' => '4p', 'visibility' => 'private']);
        $joiner = User::factory()->create();

        $this->actingAs($joiner)->postJson('/api/v1/rooms/join', ['code' => $room->code])->assertOk();
        $this->actingAs($joiner)->postJson('/api/v1/rooms/join', ['code' => $room->code])->assertOk();

        $this->assertDatabaseCount('game_room_players', 2); // host + joiner only
    }

    public function test_only_host_can_start(): void
    {
        $host = User::factory()->create();
        $rooms = app(RoomService::class);
        $room = $rooms->create($host, ['mode' => '2p', 'visibility' => 'private']);
        $other = User::factory()->create();
        $rooms->join($room, $other);

        // Non-host attempt is forbidden by RoomPolicy.
        $this->actingAs($other)
            ->postJson("/api/v1/rooms/{$room->id}/start")
            ->assertForbidden();
    }
}
