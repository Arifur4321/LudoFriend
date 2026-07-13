<?php

namespace Tests\Feature;

use App\Models\MatchState;
use App\Models\Matchup;
use App\Models\User;
use App\Services\RoomService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Event;
use Tests\TestCase;

/**
 * Token-move idempotency and ordering over the HTTP API:
 *
 *   - one tap = one move: a transport retry carrying the same action_id gets
 *     the original receipt back instead of moving a second time,
 *   - a stale/duplicate request with an outdated seq is rejected,
 *   - a duplicate without idempotency info cannot double-apply either
 *     (phase validation catches it),
 *   - responses always expose the snapshot seq the client orders by.
 */
class MoveIdempotencyTest extends TestCase
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

        // Red is mid-turn: rolled a 3, token 0 on ring cell 10 awaiting the move.
        $row = MatchState::where('match_id', $this->match->id)->first();
        $row->state = array_replace($row->state, [
            'turn' => $this->redColor,
            'phase' => 'awaiting_move',
            'dice' => 3,
            'consecutive_sixes' => 0,
            'tokens' => [
                $this->redColor => [10, -1, -1, -1],
                $this->greenColor => [-1, -1, -1, -1],
            ],
        ]);
        $row->save();
    }

    private function tokensNow(): array
    {
        return MatchState::where('match_id', $this->match->id)->first()
            ->state['tokens'][$this->redColor];
    }

    public function test_retried_move_with_same_action_id_replays_instead_of_moving_again(): void
    {
        $payload = [
            'color' => $this->redColor,
            'token' => 0,
            'action_id' => 'tap-abc-123',
        ];

        $first = $this->actingAs($this->red)
            ->postJson("/api/v1/matches/{$this->match->id}/move", $payload)
            ->assertOk()
            ->json('data');

        $this->assertFalse($first['replayed']);
        $this->assertSame(13, $first['to']);
        $this->assertSame([13], array_values(array_slice($this->tokensNow(), 0, 1)));

        // The client (or a proxy) retries the SAME physical tap.
        $second = $this->actingAs($this->red)
            ->postJson("/api/v1/matches/{$this->match->id}/move", $payload)
            ->assertOk()
            ->json('data');

        $this->assertTrue($second['replayed'], 'the retry must be answered from the receipt');
        $this->assertSame($first['move_seq'], $second['move_seq']);
        $this->assertSame($first['to'], $second['to']);
        $this->assertSame([13], array_values(array_slice($this->tokensNow(), 0, 1)),
            'the token must not move a second time');
        $this->assertSame($first['state']['seq'], $second['state']['seq'],
            'no new events may be appended by a replay');
    }

    public function test_stale_seq_assertion_is_rejected(): void
    {
        $seq = MatchState::where('match_id', $this->match->id)->first()->state['seq'];

        // Client asserts an outdated expected-next-seq (e.g. a very old queued
        // request finally arriving) — rejected, nothing applied.
        $this->actingAs($this->red)
            ->postJson("/api/v1/matches/{$this->match->id}/move", [
                'color' => $this->redColor,
                'token' => 0,
                'seq' => $seq + 5,
            ])
            ->assertStatus(422);

        $this->assertSame([10, -1, -1, -1], $this->tokensNow());
    }

    public function test_duplicate_move_without_action_id_cannot_double_apply(): void
    {
        $body = ['color' => $this->redColor, 'token' => 0];

        $this->actingAs($this->red)
            ->postJson("/api/v1/matches/{$this->match->id}/move", $body)
            ->assertOk();

        // Same request again — phase already advanced, so it must 422 and the
        // board must stay exactly where the first move put it.
        $this->actingAs($this->red)
            ->postJson("/api/v1/matches/{$this->match->id}/move", $body)
            ->assertStatus(422);

        $this->assertSame([13, -1, -1, -1], $this->tokensNow());
    }

    public function test_move_response_exposes_ordered_state_snapshot(): void
    {
        $before = MatchState::where('match_id', $this->match->id)->first()->state['seq'];

        $data = $this->actingAs($this->red)
            ->postJson("/api/v1/matches/{$this->match->id}/move", [
                'color' => $this->redColor,
                'token' => 0,
                'action_id' => 'tap-seq-check',
            ])
            ->assertOk()
            ->json('data');

        $this->assertGreaterThan($before, $data['state']['seq'],
            'clients rely on a strictly-increasing seq to drop stale snapshots');
        $this->assertArrayHasKey('last_move', $data['state']);
        $this->assertSame($data['move_seq'], $data['state']['last_move']['move_seq']);
    }
}
