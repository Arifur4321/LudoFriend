<?php

namespace Tests\Feature;

use App\Models\MatchState;
use App\Models\PlayerProfile;
use App\Models\User;
use App\Services\Economy\WalletService;
use App\Services\Game\GameEngineService;
use App\Services\RoomService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Bus;
use Illuminate\Support\Facades\Event;
use Tests\TestCase;

class TeamMatchPayoutTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        Event::fake();
        Bus::fake();
    }

    private function funded(int $coins): User
    {
        $u = User::factory()->create();
        PlayerProfile::factory()->create(['user_id' => $u->id, 'coins' => $coins]);

        return $u;
    }

    /**
     * @return array{0:\App\Models\Matchup,1:User,2:User,3:User,4:User}
     */
    private function startTeamMatch(): array
    {
        $rooms = app(RoomService::class);

        // Seats 0..3 => colors red, green, yellow, blue. Teams: 0&2 vs 1&3.
        $p0 = $this->funded(500); // red    (team 0 / A)
        $p1 = $this->funded(500); // green  (team 1 / B)
        $p2 = $this->funded(500); // yellow (team 0 / A)
        $p3 = $this->funded(500); // blue   (team 1 / B)

        $room = $rooms->create($p0, [
            'mode' => '4p', 'visibility' => 'private', 'board_tier' => 'classic', 'team_mode' => true,
        ]);
        foreach ([$p1, $p2, $p3] as $u) {
            $rooms->join($room, $u);
        }
        foreach ([$p0, $p1, $p2, $p3] as $u) {
            $rooms->setReady($room, $u, true);
        }

        $match = $rooms->start($room);

        return [$match, $p0, $p1, $p2, $p3];
    }

    public function test_winning_team_splits_the_pot_only_after_BOTH_teammates_finish(): void
    {
        $wallet = app(WalletService::class);
        [$match, $p0, $p1, $p2, $p3] = $this->startTeamMatch();

        // Pot = 4 x 200 = 800; everyone down to 300.
        $this->assertSame(800, (int) $match->fresh()->pot);
        foreach ([$p0, $p1, $p2, $p3] as $u) {
            $this->assertSame(300, $wallet->balance($u));
        }

        $match->load('players');

        // Red (team 0) has ALREADY finished; yellow (its partner) is one move
        // from home. Only when yellow also finishes may team 0 win + be paid.
        $row = MatchState::where('match_id', $match->id)->first();
        $row->state = array_replace($row->state, [
            'turn' => 'yellow',
            'phase' => 'awaiting_move',
            'dice' => 1,
            'tokens' => [
                'red' => [56, 56, 56, 56],
                'green' => [-1, -1, -1, -1],
                'yellow' => [56, 56, 56, 55],
                'blue' => [-1, -1, -1, -1],
            ],
            'finished' => ['red' => true, 'green' => false, 'yellow' => false, 'blue' => false],
        ]);
        $row->save();

        $result = app(GameEngineService::class)->move($match, 'yellow', 3);

        // The match ends now that both teammates are home.
        $this->assertSame('yellow', $result['winner']);
        $this->assertSame('finished', $match->fresh()->status);

        // Team 0 (red p0 + yellow p2) split 800 => 400 each: 300 + 400 = 700.
        $this->assertSame(700, $wallet->balance($p0));
        $this->assertSame(700, $wallet->balance($p2));
        // Team 1 stays at 300 (lost their stake).
        $this->assertSame(300, $wallet->balance($p1));
        $this->assertSame(300, $wallet->balance($p3));

        // Both winners placed 1st.
        $this->assertSame(1, $match->players()->where('color', 'red')->first()->placement);
        $this->assertSame(1, $match->players()->where('color', 'yellow')->first()->placement);
    }

    public function test_one_teammate_finishing_does_not_end_the_match_or_pay_out(): void
    {
        $wallet = app(WalletService::class);
        [$match, $p0, $p1, $p2, $p3] = $this->startTeamMatch();
        $match->load('players');

        // Red is one move from finishing; yellow (partner) is still all in base.
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
            'finished' => ['red' => false, 'green' => false, 'yellow' => false, 'blue' => false],
        ]);
        $row->save();

        $result = app(GameEngineService::class)->move($match, 'red', 3);

        // Red completed its tokens, but the TEAM is not done — no win, no payout.
        $this->assertNull($result['winner']);
        $this->assertSame('active', $match->fresh()->status);

        // Nobody has been paid a prize; every balance is still the post-stake 300.
        foreach ([$p0, $p1, $p2, $p3] as $u) {
            $this->assertSame(300, $wallet->balance($u));
        }

        // Red is now marked finished and the turn moved on to the next live seat.
        $fresh = MatchState::where('match_id', $match->id)->first()->state;
        $this->assertTrue($fresh['finished']['red']);
        $this->assertNotSame('red', $fresh['turn']);
        $this->assertNull($fresh['winner']);
    }
}
