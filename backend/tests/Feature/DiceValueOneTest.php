<?php

namespace Tests\Feature;

use App\Models\MatchState;
use App\Models\Matchup;
use App\Models\User;
use App\Services\Game\GameEngineService;
use App\Services\RoomService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Event;
use RuntimeException;
use Tests\TestCase;

/**
 * A dice result of 1 must behave exactly like any other value:
 *
 *   - with a legal move it enters the move phase (token-selection mode),
 *   - without a legal move the turn advances by the normal rules,
 *   - one tap = one authoritative roll: retries/polls can never re-roll it,
 *   - and 2–6 keep working identically.
 *
 * Guards against any regression that treats 1 as false/null/empty/unfinished.
 */
class DiceValueOneTest extends TestCase
{
    use RefreshDatabase;

    private User $red;

    private User $green;

    private Matchup $match;

    private string $redColor;

    private string $greenColor;

    protected function setUp(): void
    {
        parent::setUp();
        Event::fake();

        $this->red = User::factory()->create();
        $this->green = User::factory()->create();

        $rooms = app(RoomService::class);
        $room = $rooms->create($this->red, ['mode' => '2p', 'visibility' => 'private']);
        $rooms->join($room, $this->green);
        $rooms->setReady($room, $this->red, true);
        $rooms->setReady($room, $this->green, true);
        $this->match = $rooms->start($room);
        $this->match->load('players');

        $this->redColor = $this->match->players->firstWhere('user_id', $this->red->id)->color;
        $this->greenColor = $this->match->players->firstWhere('user_id', $this->green->id)->color;
    }

    /** Put the match in awaiting_roll for $color with the given token layout. */
    private function stage(string $color, array $tokens): void
    {
        $row = MatchState::where('match_id', $this->match->id)->first();
        $row->state = array_replace($row->state, [
            'turn' => $color,
            'phase' => 'awaiting_roll',
            'dice' => null,
            'consecutive_sixes' => 0,
            'tokens' => $tokens,
        ]);
        $row->save();
    }

    public function test_rolling_one_with_a_legal_move_enters_token_selection(): void
    {
        // One token on the ring: 1 is movable.
        $this->stage($this->redColor, [
            $this->redColor => [10, -1, -1, -1],
            $this->greenColor => [-1, -1, -1, -1],
        ]);

        $engine = app(GameEngineService::class);
        $result = $engine->roll($this->match, $this->redColor, forcedDice: 1);

        $this->assertSame(1, $result['dice']);
        $this->assertFalse($result['forfeited']);
        $this->assertFalse($result['turn_passed']);
        $this->assertNotEmpty($result['legal_moves'], 'a legal 1-step move must be offered');
        $this->assertSame('awaiting_move', $result['state']['phase']);
        $this->assertSame(1, $result['state']['dice'], 'the pending dice value 1 must be stored, not dropped');
        $this->assertSame($this->redColor, $result['state']['turn'], 'same player picks a token');
    }

    public function test_a_second_roll_attempt_while_one_is_pending_is_rejected(): void
    {
        $this->stage($this->redColor, [
            $this->redColor => [10, -1, -1, -1],
            $this->greenColor => [-1, -1, -1, -1],
        ]);

        $engine = app(GameEngineService::class);
        $engine->roll($this->match, $this->redColor, forcedDice: 1);

        // A duplicate tap / retry / poll-triggered re-roll must NOT roll again.
        $this->expectException(RuntimeException::class);
        $engine->roll($this->match, $this->redColor, forcedDice: 4);
    }

    public function test_rolling_one_with_no_legal_move_passes_the_turn(): void
    {
        // Everything still in base: only a six could move, so 1 has no move.
        $this->stage($this->redColor, [
            $this->redColor => [-1, -1, -1, -1],
            $this->greenColor => [-1, -1, -1, -1],
        ]);

        $engine = app(GameEngineService::class);
        $result = $engine->roll($this->match, $this->redColor, forcedDice: 1);

        $this->assertSame(1, $result['dice']);
        $this->assertSame([], $result['legal_moves']);
        $this->assertTrue($result['turn_passed']);
        $this->assertSame($this->greenColor, $result['state']['turn'], 'turn advances by the existing rules');
        $this->assertSame('awaiting_roll', $result['state']['phase']);
        $this->assertNull($result['state']['dice']);
    }

    public function test_moving_after_a_one_applies_exactly_one_step(): void
    {
        $this->stage($this->redColor, [
            $this->redColor => [10, -1, -1, -1],
            $this->greenColor => [-1, -1, -1, -1],
        ]);

        $engine = app(GameEngineService::class);
        $engine->roll($this->match, $this->redColor, forcedDice: 1);
        $move = $engine->move($this->match, $this->redColor, 0);

        $this->assertSame(10, $move['from']);
        $this->assertSame(11, $move['to']);
        $this->assertSame([11], $move['path'], 'a 1-step walk has a single path cell');
        $this->assertFalse($move['extra_turn']);
        $this->assertTrue($move['turn_passed']);
    }

    public function test_values_two_to_six_still_work_identically(): void
    {
        $engine = app(GameEngineService::class);

        foreach ([2, 3, 4, 5, 6] as $value) {
            $this->stage($this->redColor, [
                $this->redColor => [10, -1, -1, -1],
                $this->greenColor => [-1, -1, -1, -1],
            ]);

            $result = $engine->roll($this->match, $this->redColor, forcedDice: $value);

            $this->assertSame($value, $result['dice']);
            $this->assertNotEmpty($result['legal_moves'], "dice {$value} must offer the ring move");
            $this->assertSame('awaiting_move', $result['state']['phase']);

            $move = $engine->move($this->match, $this->redColor, 0);
            $this->assertSame(10 + $value, $move['to'], "dice {$value} must move exactly {$value} steps");
        }
    }

    public function test_snapshot_seq_advances_once_per_roll(): void
    {
        $this->stage($this->redColor, [
            $this->redColor => [10, -1, -1, -1],
            $this->greenColor => [-1, -1, -1, -1],
        ]);

        $before = MatchState::where('match_id', $this->match->id)->first()->state['seq'];
        $engine = app(GameEngineService::class);
        $result = $engine->roll($this->match, $this->redColor, forcedDice: 1);

        $this->assertSame($before + 1, $result['state']['seq'], 'exactly one event per roll — clients order snapshots by this');
    }
}
