<?php

namespace Tests\Feature;

use App\Models\MatchState;
use App\Models\Matchup;
use App\Models\PlayerProfile;
use App\Models\User;
use App\Services\Game\GameEngineService;
use App\Services\RoomService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Bus;
use Illuminate\Support\Facades\Event;
use RuntimeException;
use Tests\TestCase;

/**
 * Team 2v2 winner-gating, seat→team mapping, turn-skip, and the human-only
 * guards. The free-for-all winner path must remain unchanged.
 */
class TeamModeWinnerTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        Event::fake();
        Bus::fake();
    }

    private function funded(int $coins = 500): User
    {
        $u = User::factory()->create();
        PlayerProfile::factory()->create(['user_id' => $u->id, 'coins' => $coins]);

        return $u;
    }

    /** Four humans in a 4-player room, optionally team mode. */
    private function startFourHumans(bool $team): Matchup
    {
        $rooms = app(RoomService::class);
        $host = $this->funded();
        $room = $rooms->create($host, [
            'mode' => '4p',
            'visibility' => 'private',
            'board_tier' => $team ? 'classic' : 'casual',
            'team_mode' => $team,
        ]);
        $others = [$this->funded(), $this->funded(), $this->funded()];
        foreach ($others as $u) {
            $rooms->join($room, $u);
        }
        $rooms->setReady($room, $host, true);
        foreach ($others as $u) {
            $rooms->setReady($room, $u, true);
        }

        return $rooms->start($room)->load('players');
    }

    public function test_seats_0_and_2_are_team_a_and_1_and_3_are_team_b(): void
    {
        $match = $this->startFourHumans(team: true);

        // Colors by seat: 0=red, 1=green, 2=yellow, 3=blue.
        $this->assertSame(0, (int) $match->players()->where('color', 'red')->first()->team);
        $this->assertSame(0, (int) $match->players()->where('color', 'yellow')->first()->team);
        $this->assertSame(1, (int) $match->players()->where('color', 'green')->first()->team);
        $this->assertSame(1, (int) $match->players()->where('color', 'blue')->first()->team);
    }

    public function test_free_for_all_first_finisher_still_wins(): void
    {
        $match = $this->startFourHumans(team: false);

        $row = MatchState::where('match_id', $match->id)->first();
        $row->state = array_replace($row->state, [
            'turn' => 'red',
            'phase' => 'awaiting_move',
            'dice' => 1,
            'tokens' => [
                'red' => [56, 56, 56, 55],
                'green' => [-1, -1, -1, -1],
                'yellow' => [-1, -1, -1, -1],
                'blue' => [-1, -1, -1, -1],
            ],
        ]);
        $row->save();

        $result = app(GameEngineService::class)->move($match, 'red', 3);

        // Free-for-all: the very first color to finish wins immediately.
        $this->assertSame('red', $result['winner']);
        $this->assertSame('finished', $match->fresh()->status);
    }

    public function test_finished_player_is_skipped_in_the_turn_order(): void
    {
        $match = $this->startFourHumans(team: false);

        // green has already finished; red is about to pass its turn.
        $row = MatchState::where('match_id', $match->id)->first();
        $row->state = array_replace($row->state, [
            'turn' => 'red',
            'phase' => 'awaiting_move',
            'dice' => 1,
            'tokens' => [
                'red' => [5, -1, -1, -1],
                'green' => [56, 56, 56, 56],
                'yellow' => [-1, -1, -1, -1],
                'blue' => [-1, -1, -1, -1],
            ],
            'finished' => ['red' => false, 'green' => true, 'yellow' => false, 'blue' => false],
        ]);
        $row->save();

        app(GameEngineService::class)->move($match, 'red', 0);

        // Order is red→green→yellow→blue; green is finished, so the turn skips it.
        $fresh = MatchState::where('match_id', $match->id)->first()->state;
        $this->assertSame('yellow', $fresh['turn']);
    }

    public function test_team_mode_rejects_a_two_player_room(): void
    {
        $u = $this->funded();

        $this->expectException(RuntimeException::class);
        app(RoomService::class)->create($u, [
            'mode' => '2p',
            'team_mode' => true,
            'board_tier' => 'classic',
        ]);
    }

    public function test_team_mode_rejects_bot_fill_at_creation(): void
    {
        // Team tiers are staked and bots are never allowed on staked boards.
        $u = $this->funded();

        $this->expectException(RuntimeException::class);
        app(RoomService::class)->create($u, [
            'mode' => '4p',
            'team_mode' => true,
            'board_tier' => 'classic',
            'bot_fill' => true,
        ]);
    }

    public function test_team_mode_start_requires_four_human_players(): void
    {
        $rooms = app(RoomService::class);
        $host = $this->funded();
        $room = $rooms->create($host, [
            'mode' => '4p', 'team_mode' => true, 'board_tier' => 'classic', 'visibility' => 'private',
        ]);
        // Only two humans seated.
        $rooms->join($room, $this->funded());
        foreach ($room->fresh('players')->players as $p) {
            if ($p->user_id) {
                $rooms->setReady($room, User::find($p->user_id), true);
            }
        }

        $this->expectException(RuntimeException::class);
        $rooms->start($room);
    }
}
