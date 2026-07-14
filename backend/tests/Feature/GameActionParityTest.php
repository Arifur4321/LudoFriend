<?php

namespace Tests\Feature;

use App\Models\MatchEvent;
use App\Models\MatchState;
use App\Models\Matchup;
use App\Models\SocialAccount;
use App\Models\User;
use App\Services\Game\GameEngineService;
use App\Services\RoomService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Event;
use Tests\TestCase;

/**
 * HTTP-level guarantees behind the dice / token-tap fix, proven identical for
 * Facebook, Google, and guest players:
 *
 *   - a full roll -> move cycle behaves the same regardless of login type,
 *   - two rapid distinct taps (different action ids) commit exactly one move,
 *   - a stale roll receipt can never replay after the state advanced,
 *   - GET /state exposes the pending dice-1 and its legal moves, so a client
 *     can always rebuild token highlights (no "dead" legal token).
 */
class GameActionParityTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        Event::fake();
    }

    /** Create a user authenticated the given way (guest / facebook / google). */
    private function userFor(string $provider): User
    {
        if ($provider === 'guest') {
            return User::factory()->guest()->create();
        }

        $user = User::factory()->create();
        SocialAccount::create([
            'user_id' => $user->id,
            'provider' => $provider,
            'provider_user_id' => "{$provider}-".$user->id,
        ]);

        return $user;
    }

    /** Start a 2p match between the two users and return it (players loaded). */
    private function startMatch(User $a, User $b): Matchup
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

    private function colorOf(User $user, Matchup $match): string
    {
        return $match->players->firstWhere('user_id', $user->id)->color;
    }

    /**
     * Put the match into $color's awaiting_roll with token 0 on ring cell 10
     * (movable by every dice value) and the rest in base.
     */
    private function stageAwaitingRoll(Matchup $match, string $color, string $opponent): void
    {
        $row = MatchState::where('match_id', $match->id)->first();
        $row->state = array_replace($row->state, [
            'turn' => $color,
            'phase' => 'awaiting_roll',
            'dice' => null,
            'consecutive_sixes' => 0,
            'tokens' => [
                $color => [10, -1, -1, -1],
                $opponent => [-1, -1, -1, -1],
            ],
        ]);
        $row->save();
    }

    /** Same, but mid-turn: dice 1 already rolled and awaiting the move. */
    private function stageAwaitingMove(Matchup $match, string $color, string $opponent, int $dice = 1): void
    {
        $row = MatchState::where('match_id', $match->id)->first();
        $row->state = array_replace($row->state, [
            'turn' => $color,
            'phase' => 'awaiting_move',
            'dice' => $dice,
            'consecutive_sixes' => 0,
            'tokens' => [
                $color => [10, -1, -1, -1],
                $opponent => [-1, -1, -1, -1],
            ],
        ]);
        $row->save();
    }

    public function test_facebook_google_and_guest_players_share_an_identical_roll_move_cycle(): void
    {
        $outcomes = [];

        foreach (['guest', 'facebook', 'google'] as $provider) {
            $player = $this->userFor($provider);
            $opponent = User::factory()->create();
            $match = $this->startMatch($player, $opponent);
            $color = $this->colorOf($player, $match);
            $other = $this->colorOf($opponent, $match);

            $this->stageAwaitingRoll($match, $color, $other);
            $seqBefore = MatchState::where('match_id', $match->id)->first()->state['seq'];

            // --- one tap = one authoritative roll -------------------------
            $roll = $this->actingAs($player)
                ->postJson("/api/v1/matches/{$match->id}/roll", [
                    'color' => $color,
                    'action_id' => "tap-roll-{$provider}",
                ])
                ->assertOk()
                ->json('data');

            $dice = $roll['dice'];
            $this->assertIsInt($dice);
            $this->assertGreaterThanOrEqual(1, $dice);
            $this->assertLessThanOrEqual(6, $dice);
            $this->assertFalse($roll['replayed']);
            $this->assertFalse($roll['forfeited']);
            // Token 0 sits on ring cell 10, so EVERY dice value has a legal
            // move — 1 included: the player enters token selection, never a
            // bogus "roll again".
            $this->assertFalse($roll['turn_passed']);
            $this->assertNotEmpty($roll['legal_moves']);
            $this->assertSame('awaiting_move', $roll['state']['phase']);
            $this->assertSame($dice, $roll['state']['dice']);
            $this->assertSame($seqBefore + 1, $roll['state']['seq']);
            $this->assertSame(
                1,
                MatchEvent::where('match_id', $match->id)->where('type', 'dice_rolled')->count(),
            );

            // --- one tap = one move, exactly `dice` steps ------------------
            $move = $this->actingAs($player)
                ->postJson("/api/v1/matches/{$match->id}/move", [
                    'color' => $color,
                    'token' => 0,
                    'action_id' => "tap-move-{$provider}",
                    'seq' => $roll['state']['seq'] + 1,
                ])
                ->assertOk()
                ->json('data');

            $this->assertSame(10, $move['from']);
            $this->assertSame(10 + $dice, $move['to']);
            $this->assertSame(range(11, 10 + $dice), $move['path']);
            $this->assertFalse($move['replayed']);
            $this->assertSame(
                10 + $dice,
                MatchState::where('match_id', $match->id)->first()->state['tokens'][$color][0],
                'the token must land exactly dice steps ahead and stay there',
            );
            $this->assertSame(
                1,
                MatchEvent::where('match_id', $match->id)->where('type', 'token_moved')->count(),
            );

            // Identical turn flow: a six earns an extra roll, else turn passes.
            $this->assertSame($dice === 6, $move['extra_turn']);
            $this->assertSame($dice !== 6, $move['turn_passed']);

            $outcomes[$provider] = [
                'roll_keys' => array_keys($roll),
                'move_keys' => array_keys($move),
                'roll_status_fields' => [$roll['replayed'], $roll['forfeited'], $roll['turn_passed']],
            ];
        }

        // The response contracts must be byte-identical across login types —
        // the game layer never branches on how the player authenticated.
        $this->assertSame($outcomes['guest'], $outcomes['facebook']);
        $this->assertSame($outcomes['guest'], $outcomes['google']);
    }

    public function test_two_rapid_distinct_taps_commit_exactly_one_move(): void
    {
        $player = $this->userFor('guest');
        $opponent = User::factory()->create();
        $match = $this->startMatch($player, $opponent);
        $color = $this->colorOf($player, $match);
        $other = $this->colorOf($opponent, $match);

        $this->stageAwaitingMove($match, $color, $other, dice: 3);

        // Two DIFFERENT physical taps race each other (unlike a transport
        // retry, each carries its own action id). The row lock serializes
        // them; the loser must be rejected, not applied twice.
        $first = $this->actingAs($player)
            ->postJson("/api/v1/matches/{$match->id}/move", [
                'color' => $color,
                'token' => 0,
                'action_id' => 'tap-A',
            ]);
        $second = $this->actingAs($player)
            ->postJson("/api/v1/matches/{$match->id}/move", [
                'color' => $color,
                'token' => 0,
                'action_id' => 'tap-B',
            ]);

        $first->assertOk();
        $second->assertStatus(422);

        $this->assertSame(
            13,
            MatchState::where('match_id', $match->id)->first()->state['tokens'][$color][0],
            'the token moved exactly once (10 + 3), never twice',
        );
        $this->assertSame(
            1,
            MatchEvent::where('match_id', $match->id)->where('type', 'token_moved')->count(),
        );
    }

    public function test_a_stale_roll_receipt_cannot_replay_after_the_state_advanced(): void
    {
        $player = $this->userFor('google');
        $opponent = User::factory()->create();
        $match = $this->startMatch($player, $opponent);
        $color = $this->colorOf($player, $match);
        $other = $this->colorOf($opponent, $match);

        $this->stageAwaitingRoll($match, $color, $other);

        // Roll (deterministically) and then move: the snapshot seq advances.
        $engine = app(GameEngineService::class);
        $engine->roll($match, $color, forcedDice: 1, actionId: 'stale-tap');
        $engine->move($match, $color, 0, actionId: 'the-move');

        // A very late duplicate of the ORIGINAL roll arrives (same action id).
        // Its receipt was stamped for an older seq, so it must NOT replay —
        // normal validation applies and rejects it (turn already passed).
        $this->actingAs($player)
            ->postJson("/api/v1/matches/{$match->id}/roll", [
                'color' => $color,
                'action_id' => 'stale-tap',
            ])
            ->assertStatus(422);

        $this->assertSame(
            1,
            MatchEvent::where('match_id', $match->id)->where('type', 'dice_rolled')->count(),
            'the stale duplicate must not roll again',
        );
    }

    public function test_state_endpoint_exposes_pending_dice_one_and_its_legal_moves(): void
    {
        $player = $this->userFor('facebook');
        $opponent = User::factory()->guest()->create();
        $match = $this->startMatch($player, $opponent);
        $color = $this->colorOf($player, $match);
        $other = $this->colorOf($opponent, $match);

        $this->stageAwaitingMove($match, $color, $other, dice: 1);

        // Both participants (any login type) read the same authoritative
        // snapshot: dice is the integer 1 (never coerced to null/false) and
        // the legal 1-step move is present, so every client can rebuild the
        // token highlights after a missed broadcast or reconnect.
        foreach ([$player, $opponent] as $viewer) {
            $data = $this->actingAs($viewer)
                ->getJson("/api/v1/matches/{$match->id}/state")
                ->assertOk()
                ->json('data');

            $this->assertSame('awaiting_move', $data['state']['phase']);
            $this->assertSame(1, $data['state']['dice']);
            $this->assertSame($color, $data['state']['turn']);
            $this->assertNotEmpty($data['legal_moves']);
            $this->assertSame(0, $data['legal_moves'][0]['token']);
            $this->assertSame(10, $data['legal_moves'][0]['from']);
            $this->assertSame(11, $data['legal_moves'][0]['to']);
        }
    }
}
