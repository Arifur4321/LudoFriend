<?php

namespace Tests\Feature;

use App\Models\Matchup;
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

    public function test_winning_team_splits_the_pot_evenly(): void
    {
        $wallet = app(WalletService::class);
        $rooms = app(RoomService::class);

        // Seats 0..3 => colors red, green, yellow, blue. Teams: 0&2 vs 1&3.
        $p0 = $this->funded(500); // red   (team 0)
        $p1 = $this->funded(500); // green (team 1)
        $p2 = $this->funded(500); // yellow(team 0)
        $p3 = $this->funded(500); // blue  (team 1)

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

        // Pot = 4 x 200 = 800; everyone down to 300.
        $this->assertSame(800, (int) $match->fresh()->pot);
        foreach ([$p0, $p1, $p2, $p3] as $u) {
            $this->assertSame(300, $wallet->balance($u));
        }

        // Force a win for red (team 0).
        $match->load('players');
        $tokens = [
            'red' => [56, 56, 56, 55], 'green' => [-1, -1, -1, -1],
            'yellow' => [-1, -1, -1, -1], 'blue' => [-1, -1, -1, -1],
        ];
        $row = MatchState::where('match_id', $match->id)->first();
        $row->state = array_replace($row->state, [
            'turn' => 'red', 'phase' => 'awaiting_move', 'dice' => 1, 'tokens' => $tokens,
        ]);
        $row->save();
        app(GameEngineService::class)->move($match, 'red', 3);

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
}
