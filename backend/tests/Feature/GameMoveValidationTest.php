<?php

namespace Tests\Feature;

use App\Models\GameRoom;
use App\Models\MatchState;
use App\Models\Matchup;
use App\Models\User;
use App\Services\Game\GameEngineService;
use App\Services\RoomService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Event;
use Tests\TestCase;

/**
 * End-to-end validation tests that exercise the server-authoritative engine
 * through the HTTP API. They assert the five required guarantees:
 *   - illegal move rejected
 *   - wrong-turn action rejected
 *   - replayed / out-of-order seq rejected
 *   - leave-base-only-on-6
 *   - exact landing required to finish (home)
 */
class GameMoveValidationTest extends TestCase
{
    use RefreshDatabase;

    private User $red;

    private User $green;

    private Matchup $match;

    protected function setUp(): void
    {
        parent::setUp();
        Event::fake();

        $this->red = User::factory()->create();
        $this->green = User::factory()->create();

        $rooms = app(RoomService::class);
        /** @var GameRoom $room */
        $room = $rooms->create($this->red, ['mode' => '2p', 'visibility' => 'private']);
        $rooms->join($room, $this->green);

        // Mark humans ready and start.
        $rooms->setReady($room, $this->red, true);
        $rooms->setReady($room, $this->green, true);
        $this->match = $rooms->start($room);

        // For 2p the colors are red/yellow per config; align green->the 2nd color.
        // RoomService seats seat0=red, seat1=yellow for 2p. Re-fetch actual colors.
        $this->match->load('players');
    }

    /** The color assigned to a given user in the current match. */
    private function colorOf(User $user): string
    {
        return $this->match->players->firstWhere('user_id', $user->id)->color;
    }

    /** Directly mutate the authoritative state for deterministic scenarios. */
    private function setState(array $mutate): void
    {
        $row = MatchState::where('match_id', $this->match->id)->first();
        $row->state = array_replace($row->state, $mutate);
        $row->save();
    }

    private function currentTurnUser(): User
    {
        $turn = MatchState::where('match_id', $this->match->id)->first()->state['turn'];

        return $this->colorOf($this->red) === $turn ? $this->red : $this->green;
    }

    public function test_wrong_turn_is_rejected(): void
    {
        // Force it to be the first seat's turn, then have the OTHER player roll.
        $row = MatchState::where('match_id', $this->match->id)->first();
        $turnColor = $row->state['turn'];

        $offTurnUser = $this->colorOf($this->red) === $turnColor ? $this->green : $this->red;

        $this->actingAs($offTurnUser)
            ->postJson("/api/v1/matches/{$this->match->id}/roll", ['color' => $this->colorOf($offTurnUser)])
            ->assertStatus(422)
            ->assertJsonPath('message', 'It is not your turn.');
    }

    public function test_acting_as_a_color_you_do_not_own_is_forbidden(): void
    {
        $user = $this->currentTurnUser();
        $notMyColor = $this->colorOf($user) === 'red' ? 'yellow' : 'red';

        // Even on your turn, you cannot claim another color — policy blocks it.
        $this->actingAs($user)
            ->postJson("/api/v1/matches/{$this->match->id}/roll", ['color' => $notMyColor])
            ->assertForbidden();
    }

    public function test_token_leaves_base_only_on_six(): void
    {
        $user = $this->currentTurnUser();
        $color = $this->colorOf($user);

        // Engine roll uses RNG; instead drive via the service with a forced 3.
        $engine = app(GameEngineService::class);
        $result = $engine->roll($this->match, $color, forcedDice: 3);

        // All tokens in base + a 3 => no legal move, turn passes.
        $this->assertSame([], $result['legal_moves']);
        $this->assertTrue($result['turn_passed']);

        // Reset to that player's turn and force a 6 => exactly one legal move
        // (release a token to rel 0).
        $this->setState(['turn' => $color, 'phase' => 'awaiting_roll', 'consecutive_sixes' => 0]);
        $result = $engine->roll($this->match, $color, forcedDice: 6);
        $this->assertNotEmpty($result['legal_moves']);
        $this->assertSame(0, $result['legal_moves'][0]['to']);
    }

    public function test_state_refresh_returns_pending_phase_and_legal_moves(): void
    {
        $user = $this->currentTurnUser();
        $color = $this->colorOf($user);
        $opponent = $color === 'red' ? 'yellow' : 'red';

        $this->setState([
            'turn' => $color,
            'phase' => 'awaiting_move',
            'dice' => 6,
            'tokens' => [$color => [-1, -1, -1, -1], $opponent => [-1, -1, -1, -1]],
        ]);

        $this->actingAs($user)
            ->getJson("/api/v1/matches/{$this->match->id}/state")
            ->assertOk()
            ->assertJsonPath('data.state.phase', 'awaiting_move')
            ->assertJsonPath('data.state.turn', $color)
            ->assertJsonPath('data.legal_moves.0.token', 0);
    }

    public function test_illegal_move_is_rejected_when_token_cannot_move(): void
    {
        $user = $this->currentTurnUser();
        $color = $this->colorOf($user);

        // Put one token near home needing an exact roll; set dice that overshoots.
        // token0 at rel 53 needs exactly 3 to finish; give dice 5 (would be 58).
        $tokens = [
            $color => [53, -1, -1, -1],
        ];
        // Fill the opponent color so the map is complete.
        $opponent = $color === 'red' ? 'yellow' : 'red';
        $tokens[$opponent] = [-1, -1, -1, -1];

        $this->setState([
            'turn' => $color,
            'phase' => 'awaiting_move',
            'dice' => 5,
            'tokens' => $tokens,
        ]);

        // token0 cannot legally move with a 5 (overshoots home) => rejected.
        $this->actingAs($user)
            ->postJson("/api/v1/matches/{$this->match->id}/move", ['color' => $color, 'token' => 0])
            ->assertStatus(422)
            ->assertJsonPath('message', 'Illegal move for the current dice value.');
    }

    public function test_exact_landing_finishes_a_token(): void
    {
        $user = $this->currentTurnUser();
        $color = $this->colorOf($user);
        $opponent = $color === 'red' ? 'yellow' : 'red';

        $this->setState([
            'turn' => $color,
            'phase' => 'awaiting_move',
            'dice' => 3,
            'tokens' => [$color => [53, -1, -1, -1], $opponent => [-1, -1, -1, -1]],
        ]);

        $this->actingAs($user)
            ->postJson("/api/v1/matches/{$this->match->id}/move", ['color' => $color, 'token' => 0])
            ->assertOk()
            ->assertJsonPath('data.to', 56)
            ->assertJsonPath('data.finished', true);
    }

    public function test_replayed_or_out_of_order_seq_is_rejected(): void
    {
        $user = $this->currentTurnUser();
        $color = $this->colorOf($user);
        $opponent = $color === 'red' ? 'yellow' : 'red';

        // A clean, legal move is available (token at rel 5 -> 8 with dice 3).
        $row = MatchState::where('match_id', $this->match->id)->first();
        $currentSeq = (int) $row->state['seq'];

        $this->setState([
            'turn' => $color,
            'phase' => 'awaiting_move',
            'dice' => 3,
            'tokens' => [$color => [5, -1, -1, -1], $opponent => [-1, -1, -1, -1]],
        ]);

        // Assert a stale seq (already-applied) => rejected as replay.
        $this->actingAs($user)
            ->postJson("/api/v1/matches/{$this->match->id}/move", [
                'color' => $color,
                'token' => 0,
                'seq' => $currentSeq, // not currentSeq+1 -> out of order
            ])
            ->assertStatus(422);
    }
}
