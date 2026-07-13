<?php

namespace Tests\Feature;

use App\Models\MatchState;
use App\Models\Matchup;
use App\Models\RecentPlayer;
use App\Models\User;
use App\Services\Game\GameEngineService;
use App\Services\RoomService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Bus;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Event;
use Tests\TestCase;

/**
 * After two players complete a match they are saved as each other's recent
 * players (regardless of auth type — Facebook, Google, email, or guest), can
 * see each other's online status, and can invite each other to a new room.
 */
class RecentPlayersTest extends TestCase
{
    use RefreshDatabase;

    /** Build, start, and complete a 2-player match between $a and $b ($a wins). */
    private function playCompleteMatch(User $a, User $b): Matchup
    {
        $rooms = app(RoomService::class);
        $room = $rooms->create($a, ['mode' => '2p', 'visibility' => 'private']);
        $rooms->join($room, $b);
        $rooms->setReady($room, $a, true);
        $rooms->setReady($room, $b, true);
        $match = $rooms->start($room);
        $match->load('players');

        $winnerColor = $match->players->firstWhere('user_id', $a->id)->color;
        $loserColor = $match->players->firstWhere('user_id', $b->id)->color;

        $row = MatchState::where('match_id', $match->id)->first();
        $row->state = array_replace($row->state, [
            'turn' => $winnerColor,
            'phase' => 'awaiting_move',
            'dice' => 1,
            'tokens' => [
                $winnerColor => [56, 56, 56, 55], // one step from winning
                $loserColor => [-1, -1, -1, -1],
            ],
        ]);
        $row->save();

        app(GameEngineService::class)->move($match, $winnerColor, 3);

        return $match;
    }

    protected function setUp(): void
    {
        parent::setUp();
        Event::fake();
        Bus::fake();
    }

    public function test_completing_a_match_records_recent_players_in_both_directions(): void
    {
        $fbUser = User::factory()->create();          // e.g. Facebook account
        $guest = User::factory()->create(['is_guest' => true, 'email' => null]);

        $match = $this->playCompleteMatch($fbUser, $guest);

        $ab = RecentPlayer::where('user_id', $fbUser->id)
            ->where('other_user_id', $guest->id)->first();
        $ba = RecentPlayer::where('user_id', $guest->id)
            ->where('other_user_id', $fbUser->id)->first();

        $this->assertNotNull($ab, 'winner remembers the guest');
        $this->assertNotNull($ba, 'guest remembers the winner');
        $this->assertSame(1, $ab->games);
        $this->assertSame($match->id, $ab->last_match_id);
        $this->assertNotNull($ab->last_played_at);

        // Never a self-pair, and nothing beyond the two directed rows.
        $this->assertSame(2, RecentPlayer::count());
        $this->assertSame(0, RecentPlayer::whereColumn('user_id', 'other_user_id')->count());
    }

    public function test_playing_again_increments_the_pair_instead_of_duplicating(): void
    {
        $a = User::factory()->create();
        $b = User::factory()->create();

        $this->playCompleteMatch($a, $b);
        $this->playCompleteMatch($a, $b);

        $rows = RecentPlayer::where('user_id', $a->id)
            ->where('other_user_id', $b->id)->get();

        $this->assertCount(1, $rows, 'unique(user, other_user) — updated, not duplicated');
        $this->assertSame(2, $rows->first()->games);
    }

    public function test_recent_endpoint_lists_opponent_with_online_and_friend_flags(): void
    {
        $a = User::factory()->create();
        $b = User::factory()->create();
        $this->playCompleteMatch($a, $b);

        // b is currently online (presence heartbeat cache key).
        Cache::put("presence:online:{$b->id}", true, 60);

        $data = $this->actingAs($a)
            ->getJson('/api/v1/friends/recent')
            ->assertOk()
            ->json('data');

        $this->assertCount(1, $data);
        $this->assertSame($b->id, $data[0]['id']);
        $this->assertTrue($data[0]['online']);
        $this->assertFalse($data[0]['is_friend'], 'recent player is not automatically a friend');
        $this->assertSame(1, $data[0]['games']);
    }

    public function test_recent_player_can_be_invited_to_a_room_without_a_friend_link(): void
    {
        $a = User::factory()->create();
        $b = User::factory()->create();
        $this->playCompleteMatch($a, $b);

        $rooms = app(RoomService::class);
        $room = $rooms->create($a, ['mode' => '2p', 'visibility' => 'private']);

        $this->actingAs($a)
            ->postJson('/api/v1/friends/invite-to-room', [
                'room_id' => $room->id,
                'friend_user_id' => $b->id,
            ])
            ->assertOk();
    }

    public function test_a_stranger_still_cannot_be_invited(): void
    {
        $a = User::factory()->create();
        $stranger = User::factory()->create();

        $rooms = app(RoomService::class);
        $room = $rooms->create($a, ['mode' => '2p', 'visibility' => 'private']);

        $this->actingAs($a)
            ->postJson('/api/v1/friends/invite-to-room', [
                'room_id' => $room->id,
                'friend_user_id' => $stranger->id,
            ])
            ->assertForbidden();
    }

}
