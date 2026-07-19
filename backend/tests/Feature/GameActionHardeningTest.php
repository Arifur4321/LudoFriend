<?php

namespace Tests\Feature;

use App\Models\MatchState;
use App\Models\Matchup;
use App\Models\User;
use App\Services\Game\GameEngineService;
use App\Services\RoomService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Bus;
use Illuminate\Support\Facades\Event;
use RuntimeException;
use Tests\TestCase;

/**
 * Actions that are invalid for the current turn / phase / state must surface as
 * clean domain errors (which the HTTP layer maps to 422) — never a null-deref or
 * type error that would render as a 500.
 */
class GameActionHardeningTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        Event::fake();
        Bus::fake();
    }

    private function twoPlayerMatch(): Matchup
    {
        $rooms = app(RoomService::class);
        $a = User::factory()->create();
        $b = User::factory()->create();
        $room = $rooms->create($a, ['mode' => '2p', 'visibility' => 'private']);
        $rooms->join($room, $b);
        $rooms->setReady($room, $a, true);
        $rooms->setReady($room, $b, true);

        return $rooms->start($room)->load('players');
    }

    public function test_missing_state_row_raises_a_domain_error_not_a_type_error(): void
    {
        $match = $this->twoPlayerMatch();
        $turn = MatchState::where('match_id', $match->id)->first()->state['turn'];
        MatchState::where('match_id', $match->id)->delete();

        $this->expectException(RuntimeException::class);
        app(GameEngineService::class)->roll($match, $turn);
    }

    public function test_rolling_on_the_wrong_turn_is_a_domain_error(): void
    {
        $match = $this->twoPlayerMatch();
        $turn = MatchState::where('match_id', $match->id)->first()->state['turn'];
        $other = $turn === 'red' ? 'yellow' : 'red'; // 2p colours are red / yellow

        $this->expectException(RuntimeException::class);
        app(GameEngineService::class)->roll($match, $other);
    }

    public function test_moving_during_the_roll_phase_is_a_domain_error(): void
    {
        $match = $this->twoPlayerMatch();
        // A freshly started match is awaiting_roll; a move is the wrong phase.
        $turn = MatchState::where('match_id', $match->id)->first()->state['turn'];

        $this->expectException(RuntimeException::class);
        app(GameEngineService::class)->move($match, $turn, 0);
    }
}
