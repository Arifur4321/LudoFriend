<?php

namespace Tests\Feature;

use App\Models\Matchup;
use App\Models\MatchState;
use App\Models\User;
use App\Services\Game\GameEngineService;
use App\Services\RoomService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Bus;
use Illuminate\Support\Facades\Event;
use Tests\TestCase;

class MatchCompletionTest extends TestCase
{
    use RefreshDatabase;

    public function test_finishing_all_four_tokens_wins_the_match(): void
    {
        Event::fake();
        Bus::fake(); // suppress the async PersistMatchReplay file I/O

        $red = User::factory()->create();
        $green = User::factory()->create();

        $rooms = app(RoomService::class);
        $room = $rooms->create($red, ['mode' => '2p', 'visibility' => 'private']);
        $rooms->join($room, $green);
        $rooms->setReady($room, $red, true);
        $rooms->setReady($room, $green, true);
        $match = $rooms->start($room);
        $match->load('players');

        $winnerColor = $match->players->firstWhere('user_id', $red->id)->color;
        $opponent = $winnerColor === 'red' ? 'yellow' : 'red';

        // Stage: three tokens already home, the fourth one move away.
        $row = MatchState::where('match_id', $match->id)->first();
        $row->state = array_replace($row->state, [
            'turn' => $winnerColor,
            'phase' => 'awaiting_move',
            'dice' => 1,
            'tokens' => [
                $winnerColor => [56, 56, 56, 55], // token3 needs exactly 1
                $opponent => [-1, -1, -1, -1],
            ],
        ]);
        $row->save();

        $engine = app(GameEngineService::class);
        $result = $engine->move($match, $winnerColor, 3);

        $this->assertSame($winnerColor, $result['winner']);

        $fresh = Matchup::find($match->id);
        $this->assertSame('finished', $fresh->status);
        $this->assertSame($red->id, $fresh->winner_user_id);

        // Winner gets placement 1.
        $this->assertSame(
            1,
            $match->players()->where('color', $winnerColor)->first()->placement
        );

        // A game_ended event was recorded.
        $this->assertDatabaseHas('match_events', [
            'match_id' => $match->id,
            'type' => 'game_ended',
        ]);

        // Winner's profile recorded a win; loser recorded a loss.
        $this->assertDatabaseHas('player_profiles', ['user_id' => $red->id, 'wins' => 1]);
        $this->assertDatabaseHas('player_profiles', ['user_id' => $green->id, 'losses' => 1]);

        // The async replay job was queued.
        Bus::assertDispatched(\App\Jobs\PersistMatchReplay::class);
    }
}
