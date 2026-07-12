<?php

namespace Tests\Feature;

use App\Events\DiceRolled;
use App\Models\MatchEvent;
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
 * Focused coverage for the server-authoritative dice flow and the guarantees
 * the duplicate/multi-tap fix depends on:
 *
 *   - exactly one committed roll per logical action (idempotency by action_id),
 *   - no second roll can commit while a move is pending,
 *   - turn / phase / seat authorization is identical for every login type,
 *   - broadcasts happen only after the transaction commits (a rejected action
 *     broadcasts nothing).
 */
class DiceRollFlowTest extends TestCase
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
        $this->match = $this->startTwoPlayerMatch($this->red, $this->green);
    }

    /** Build a started 2p match between two users and return it (players loaded). */
    private function startTwoPlayerMatch(User $a, User $b): Matchup
    {
        $rooms = app(RoomService::class);
        $room = $rooms->create($a, ['mode' => '2p', 'visibility' => 'private']);
        $rooms->join($room, $b);
        $rooms->setReady($room, $a, true);
        $rooms->setReady($room, $b, true);
        $match = $rooms->start($room);
        $match->load('players');

        return $match;
    }

    private function colorOf(User $user, ?Matchup $match = null): string
    {
        $match ??= $this->match;

        return $match->players->firstWhere('user_id', $user->id)->color;
    }

    private function forceTurn(Matchup $match, string $color): void
    {
        $row = MatchState::where('match_id', $match->id)->first();
        $row->state = array_replace($row->state, [
            'turn' => $color,
            'phase' => 'awaiting_roll',
            'dice' => null,
            'consecutive_sixes' => 0,
        ]);
        $row->save();
    }

    private function currentTurnUser(): User
    {
        $turn = MatchState::where('match_id', $this->match->id)->first()->state['turn'];

        return $this->colorOf($this->red) === $turn ? $this->red : $this->green;
    }

    /* ===================================================================== */

    public function test_valid_player_rolls_once_and_snapshot_exposes_seq(): void
    {
        $user = $this->currentTurnUser();
        $color = $this->colorOf($user);

        $response = $this->actingAs($user)->postJson(
            "/api/v1/matches/{$this->match->id}/roll",
            ['color' => $color, 'action_id' => 'tap-1'],
        );

        $response->assertOk()
            ->assertJsonPath('data.replayed', false);

        // The authoritative snapshot must carry the monotonic `seq` the client
        // uses to order/ignore stale refreshes.
        $seq = $response->json('data.state.seq');
        $this->assertIsInt($seq);
        $this->assertGreaterThanOrEqual(1, $seq);

        // Exactly one dice roll was recorded and the state advanced one version.
        $this->assertSame(
            1,
            MatchEvent::where('match_id', $this->match->id)->where('type', 'dice_rolled')->count(),
        );
        $this->assertSame(1, (int) MatchState::where('match_id', $this->match->id)->value('version'));
    }

    public function test_duplicate_request_with_same_action_id_commits_one_roll(): void
    {
        $user = $this->currentTurnUser();
        $color = $this->colorOf($user);
        $url = "/api/v1/matches/{$this->match->id}/roll";

        $first = $this->actingAs($user)->postJson($url, ['color' => $color, 'action_id' => 'same-tap']);
        $first->assertOk()->assertJsonPath('data.replayed', false);

        $seqAfterFirst = MatchState::where('match_id', $this->match->id)->first()->state['seq'];
        $versionAfterFirst = (int) MatchState::where('match_id', $this->match->id)->value('version');

        // The transport retries the identical request.
        $retry = $this->actingAs($user)->postJson($url, ['color' => $color, 'action_id' => 'same-tap']);

        $retry->assertOk()
            ->assertJsonPath('data.replayed', true)
            ->assertJsonPath('data.dice', $first->json('data.dice'))
            // A duplicate/retried request returns the authoritative current state.
            ->assertJsonPath('data.state.seq', $seqAfterFirst);

        // No second roll, no extra event, no extra version bump.
        $this->assertSame(
            1,
            MatchEvent::where('match_id', $this->match->id)->where('type', 'dice_rolled')->count(),
        );
        $this->assertSame(
            $versionAfterFirst,
            (int) MatchState::where('match_id', $this->match->id)->value('version'),
        );
    }

    public function test_second_roll_cannot_commit_while_a_move_is_pending(): void
    {
        // Two near-simultaneous rolls are serialized by the row lock; the first
        // enters the move phase and the second must be rejected — only one
        // committed result is possible.
        $user = $this->currentTurnUser();
        $color = $this->colorOf($user);
        $engine = app(GameEngineService::class);

        $first = $engine->roll($this->match, $color, forcedDice: 6);
        $this->assertNotEmpty($first['legal_moves']); // a 6 releases a token
        $this->assertSame(
            'awaiting_move',
            MatchState::where('match_id', $this->match->id)->first()->state['phase'],
        );

        try {
            $engine->roll($this->match, $color, forcedDice: 6);
            $this->fail('A second roll must not be accepted while a move is pending.');
        } catch (RuntimeException $e) {
            $this->assertStringContainsStringIgnoringCase('phase', $e->getMessage());
        }

        $this->assertSame(
            1,
            MatchEvent::where('match_id', $this->match->id)->where('type', 'dice_rolled')->count(),
        );
    }

    public function test_player_cannot_roll_outside_their_turn(): void
    {
        $turnColor = MatchState::where('match_id', $this->match->id)->first()->state['turn'];
        $offTurn = $this->colorOf($this->red) === $turnColor ? $this->green : $this->red;

        $this->actingAs($offTurn)
            ->postJson("/api/v1/matches/{$this->match->id}/roll", ['color' => $this->colorOf($offTurn)])
            ->assertStatus(422)
            ->assertJsonPath('message', 'It is not your turn.');
    }

    public function test_player_cannot_roll_during_token_selection_phase(): void
    {
        $user = $this->currentTurnUser();
        $color = $this->colorOf($user);
        $opponent = $color === 'red' ? 'yellow' : 'red';

        // A dice value is already pending a move — the dice must stay locked.
        $row = MatchState::where('match_id', $this->match->id)->first();
        $row->state = array_replace($row->state, [
            'turn' => $color,
            'phase' => 'awaiting_move',
            'dice' => 6,
            'tokens' => [$color => [-1, -1, -1, -1], $opponent => [-1, -1, -1, -1]],
        ]);
        $row->save();

        $this->actingAs($user)
            ->postJson("/api/v1/matches/{$this->match->id}/roll", ['color' => $color])
            ->assertStatus(422)
            ->assertJsonPath('message', 'Invalid action for the current phase (awaiting_move).');
    }

    public function test_non_participant_cannot_roll(): void
    {
        $stranger = User::factory()->create();
        $turnColor = MatchState::where('match_id', $this->match->id)->first()->state['turn'];

        $this->actingAs($stranger)
            ->postJson("/api/v1/matches/{$this->match->id}/roll", ['color' => $turnColor])
            ->assertForbidden();
    }

    public function test_all_login_types_share_the_same_roll_authorization(): void
    {
        // Facebook / Google players are simply non-guest Users with a linked
        // SocialAccount; a guest is a User with is_guest = true. The game layer
        // never branches on how a user authenticated — only on seat + turn — so
        // both must behave identically here.
        $guest = User::factory()->guest()->create();
        $registered = User::factory()->create();
        $match = $this->startTwoPlayerMatch($guest, $registered);

        foreach ([$guest, $registered] as $i => $user) {
            $color = $this->colorOf($user, $match);
            $notOwned = $color === 'red' ? 'yellow' : 'red';
            $this->forceTurn($match, $color);

            // On their turn, with their own color: accepted.
            $this->actingAs($user)
                ->postJson("/api/v1/matches/{$match->id}/roll", ['color' => $color, 'action_id' => "tap-$i"])
                ->assertOk();

            // Claiming a color they do not own: forbidden — same for both types.
            $this->actingAs($user)
                ->postJson("/api/v1/matches/{$match->id}/roll", ['color' => $notOwned])
                ->assertForbidden();
        }
    }

    public function test_dice_rolled_is_broadcast_after_a_successful_roll(): void
    {
        $user = $this->currentTurnUser();
        $color = $this->colorOf($user);

        app(GameEngineService::class)->roll($this->match, $color, forcedDice: 6);

        Event::assertDispatched(DiceRolled::class);
    }

    public function test_no_dice_rolled_broadcast_when_the_action_is_rejected(): void
    {
        // A rejected roll throws inside the transaction, which rolls back before
        // the queued broadcasts are flushed — so nothing is ever broadcast.
        $user = $this->currentTurnUser();
        $color = $this->colorOf($user);

        // Put the match in the move phase so a roll is invalid.
        $row = MatchState::where('match_id', $this->match->id)->first();
        $row->state = array_replace($row->state, ['turn' => $color, 'phase' => 'awaiting_move', 'dice' => 6]);
        $row->save();

        try {
            app(GameEngineService::class)->roll($this->match, $color, forcedDice: 6);
            $this->fail('Rolling during the move phase must be rejected.');
        } catch (RuntimeException) {
            // expected
        }

        Event::assertNotDispatched(DiceRolled::class);
    }
}
