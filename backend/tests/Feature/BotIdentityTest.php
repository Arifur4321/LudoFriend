<?php

namespace Tests\Feature;

use App\Models\GameRoomPlayer;
use App\Models\User;
use App\Services\Game\BotIdentityService;
use App\Services\RoomService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Event;
use Tests\TestCase;

/**
 * Bot identities (Parts 7, 9): realistic, persisted, stable, unique names that
 * surface in both the room and match payloads — without changing bot AI.
 */
class BotIdentityTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        Event::fake();
    }

    /** Create a casual bot-filled room, start it, return [host, room, match]. */
    private function startBotRoom(string $mode = '4p'): array
    {
        $host = User::factory()->create(['name' => 'RealHost']);
        $rooms = app(RoomService::class);
        $room = $rooms->create($host, ['mode' => $mode, 'visibility' => 'private', 'bot_fill' => true]);
        $rooms->setReady($room, $host, true);
        $match = $rooms->start($room);

        return [$host, $room->fresh('players'), $match];
    }

    public function test_bot_names_come_from_the_configured_pool(): void
    {
        $pool = app(BotIdentityService::class)->pool();
        $this->assertContains('Rakib', $pool);
        $this->assertContains('Samuel', $pool);

        [, $room] = $this->startBotRoom('4p');
        foreach ($room->players()->where('is_bot', true)->get() as $bot) {
            $this->assertNotNull($bot->display_name);
            $this->assertNotSame('Bot', $bot->display_name);
            $this->assertContains($bot->display_name, $pool);
        }
    }

    public function test_bot_names_are_persisted_on_room_and_match_seats(): void
    {
        [, $room, $match] = $this->startBotRoom('4p');

        $roomBots = $room->players()->where('is_bot', true)->pluck('display_name')->filter();
        $this->assertCount(3, $roomBots);

        foreach ($match->players()->where('is_bot', true)->get() as $mp) {
            $this->assertNotNull($mp->display_name, 'match seat carries the persisted bot name');
        }

        // Same name for the same seat across room and match tables.
        foreach ($match->players()->where('is_bot', true)->get() as $mp) {
            $roomSeat = GameRoomPlayer::where('room_id', $room->id)->where('seat', $mp->seat)->first();
            $this->assertSame($roomSeat->display_name, $mp->display_name);
        }
    }

    public function test_bot_names_are_unique_within_a_match(): void
    {
        [, $room] = $this->startBotRoom('4p'); // 1 human + 3 bots
        $names = $room->players()->where('is_bot', true)->pluck('display_name');
        $this->assertCount(3, $names);
        $this->assertCount(3, $names->unique(), 'no two bots share a name');
    }

    public function test_bot_names_appear_in_match_resource(): void
    {
        [$host, , $match] = $this->startBotRoom('4p');

        $players = $this->actingAs($host)
            ->getJson("/api/v1/matches/{$match->id}/state")
            ->assertOk()
            ->json('data.players');

        $bots = collect($players)->where('is_bot', true);
        $this->assertCount(3, $bots);
        foreach ($bots as $b) {
            $this->assertNotEmpty($b['name']);
            $this->assertNotSame('Bot', $b['name']);
        }
    }

    public function test_bot_names_appear_in_room_resource(): void
    {
        [$host, $room] = $this->startBotRoom('4p');

        $players = $this->actingAs($host)
            ->getJson("/api/v1/rooms/{$room->id}")
            ->assertOk()
            ->json('data.players');

        $bots = collect($players)->where('is_bot', true);
        $this->assertCount(3, $bots);
        foreach ($bots as $b) {
            $this->assertNotEmpty($b['display_name']);
        }
    }

    public function test_bot_names_are_stable_across_state_refreshes(): void
    {
        [$host, , $match] = $this->startBotRoom('4p');

        $first = collect($this->actingAs($host)->getJson("/api/v1/matches/{$match->id}/state")->json('data.players'))
            ->where('is_bot', true)->pluck('name', 'color');
        $second = collect($this->actingAs($host)->getJson("/api/v1/matches/{$match->id}/state")->json('data.players'))
            ->where('is_bot', true)->pluck('name', 'color');

        $this->assertEquals($first, $second, 'a reconnect / refresh shows identical bot names');
    }

    public function test_bots_are_ready_and_remain_in_the_turn_rotation(): void
    {
        [, $room, $match] = $this->startBotRoom('4p');

        // Bot seats are ready.
        $this->assertSame(0, $room->players()->where('is_bot', true)->where('is_ready', false)->count());

        // Bot AI still gets turns: every bot colour is part of the authoritative
        // turn order (bot turn/dice/movement logic itself is untouched).
        $match->load('state');
        $turnOrder = $match->state->state['turn_order'];
        foreach ($match->players()->where('is_bot', true)->get() as $bot) {
            $this->assertContains($bot->color, $turnOrder);
        }
    }
}
