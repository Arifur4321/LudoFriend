<?php

namespace Tests\Feature;

use App\Events\TokenMoved;
use App\Events\TurnChanged;
use App\Models\MatchState;
use App\Models\Matchup;
use App\Models\SocialAccount;
use App\Models\User;
use App\Services\Game\GameEngineService;
use App\Services\RoomService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Event;
use RuntimeException;
use Tests\TestCase;

/**
 * Hardening guarantees for the Facebook-vs-Facebook online reproduction that the
 * previous suites did not cover directly:
 *
 *   - two Facebook-authenticated users seated in one match get DISTINCT seats and
 *     colours, and each may act only on their own colour,
 *   - a committed move broadcasts BOTH token_moved and turn_changed (so the peer
 *     phone updates immediately) — and a rejected move broadcasts nothing,
 *   - a reconnect landing on a pending move returns the pending dice so the
 *     resuming client can rebuild its highlights,
 *   - read-only state polling is on its own (higher) rate limiter, so a burst of
 *     recovery polls is never throttled at the roll/move action limit.
 *
 * Facebook / Google users are ordinary Laravel Users with a linked SocialAccount;
 * the game layer only ever keys off the Laravel user id + seat + colour, so these
 * guarantees are inherently provider-agnostic.
 */
class OnlineSyncHardeningTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        Event::fake();
    }

    /** A user who signed in with Facebook (a User + a linked SocialAccount). */
    private function facebookUser(): User
    {
        $user = User::factory()->create();
        SocialAccount::create([
            'user_id' => $user->id,
            'provider' => 'facebook',
            'provider_user_id' => 'fb-'.$user->id,
        ]);

        return $user;
    }

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

    private function stageAwaitingMove(Matchup $match, string $color, string $opponent, int $dice): void
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

    public function test_two_facebook_users_get_distinct_seats_and_colours_and_act_only_on_their_own(): void
    {
        $a = $this->facebookUser();
        $b = $this->facebookUser();
        $match = $this->startMatch($a, $b);

        $ca = $this->colorOf($a, $match);
        $cb = $this->colorOf($b, $match);

        // Never the same colour, and the canonical 2p palette (red/yellow).
        $this->assertNotSame($ca, $cb, 'two participants must never share a colour');
        $this->assertEqualsCanonicalizing(['red', 'yellow'], [$ca, $cb]);
        $this->assertEqualsCanonicalizing([0, 1], $match->players->pluck('seat')->all());

        // A may roll on their own colour on their turn.
        $this->forceTurn($match, $ca);
        $this->actingAs($a)
            ->postJson("/api/v1/matches/{$match->id}/roll", ['color' => $ca, 'action_id' => 'a-roll'])
            ->assertOk();

        // B may never act AS A's colour (seat-ownership policy), even on B's turn.
        $this->forceTurn($match, $cb);
        $this->actingAs($b)
            ->postJson("/api/v1/matches/{$match->id}/roll", ['color' => $ca])
            ->assertForbidden();

        // …but B rolls fine on their own colour: identity is resolved per seat.
        $this->actingAs($b)
            ->postJson("/api/v1/matches/{$match->id}/roll", ['color' => $cb, 'action_id' => 'b-roll'])
            ->assertOk();
    }

    public function test_a_committed_move_broadcasts_token_moved_and_turn_changed(): void
    {
        $a = $this->facebookUser();
        $b = $this->facebookUser();
        $match = $this->startMatch($a, $b);
        $ca = $this->colorOf($a, $match);
        $cb = $this->colorOf($b, $match);

        // Token 0 on cell 10, dice 3 → lands on 13, no six/capture → turn passes.
        $this->stageAwaitingMove($match, $ca, $cb, 3);

        app(GameEngineService::class)->move($match, $ca, 0);

        // Both are broadcast (ShouldBroadcastNow) only after the commit, so the
        // opponent's phone sees the move AND the turn hand-off without waiting on
        // a queue worker.
        Event::assertDispatched(TokenMoved::class);
        Event::assertDispatched(TurnChanged::class);
    }

    public function test_a_rejected_move_broadcasts_nothing(): void
    {
        $a = $this->facebookUser();
        $b = $this->facebookUser();
        $match = $this->startMatch($a, $b);
        $ca = $this->colorOf($a, $match);
        $cb = $this->colorOf($b, $match);

        // Dice 3, but token 1 is still in base — releasing needs a six, so this
        // move is illegal and the transaction rolls back before any flush.
        $this->stageAwaitingMove($match, $ca, $cb, 3);

        try {
            app(GameEngineService::class)->move($match, $ca, 1);
            $this->fail('An illegal move must be rejected.');
        } catch (RuntimeException) {
            // expected
        }

        Event::assertNotDispatched(TokenMoved::class);
        Event::assertNotDispatched(TurnChanged::class);
    }

    public function test_reconnect_during_a_pending_move_returns_the_pending_dice(): void
    {
        $a = $this->facebookUser();
        $b = $this->facebookUser();
        $match = $this->startMatch($a, $b);
        $ca = $this->colorOf($a, $match);
        $cb = $this->colorOf($b, $match);

        // A rolled a 1 and is mid-turn (awaiting the move) when the app drops.
        $this->stageAwaitingMove($match, $ca, $cb, 1);

        $data = $this->actingAs($a)
            ->postJson("/api/v1/matches/{$match->id}/reconnect")
            ->assertOk()
            ->json('data');

        // The snapshot still carries the pending dice + phase + turn, so the
        // resuming client resumes token selection instead of being asked to roll.
        $this->assertSame('awaiting_move', $data['state']['phase']);
        $this->assertSame(1, $data['state']['dice']);
        $this->assertSame($ca, $data['state']['turn']);
    }

    public function test_state_polling_is_not_throttled_by_the_action_limiter(): void
    {
        $a = $this->facebookUser();
        $b = $this->facebookUser();
        $match = $this->startMatch($a, $b);

        // 40 recovery polls in a row — well above the 30/min roll/move action
        // limit, below the 120/min polling limit. All must succeed: polling has
        // its own limiter, so it can neither starve nor be starved by actions.
        for ($i = 0; $i < 40; $i++) {
            $this->actingAs($a)
                ->getJson("/api/v1/matches/{$match->id}/state")
                ->assertOk();
        }
    }
}
