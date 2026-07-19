<?php

namespace Tests\Feature;

use App\Models\GameRoom;
use App\Models\MatchmakingTicket;
use App\Models\SocialAccount;
use App\Models\User;
use App\Services\MatchmakingService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\Str;
use Tests\TestCase;

/**
 * Public Play-Online matchmaking (Parts 4, 5, 9): shared provider-agnostic
 * queue, human-first pairing, human grouping + bot-fill after the timeout,
 * concurrency safety, and automatic start.
 */
class MatchmakingFlowTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        Event::fake();
    }

    private MatchmakingService $mm;

    private function service(): MatchmakingService
    {
        return $this->mm ??= app(MatchmakingService::class);
    }

    private function guest(string $n = 'G'): User
    {
        return User::factory()->guest()->create(['name' => $n]);
    }

    private function social(string $provider, string $n): User
    {
        $u = User::factory()->create(['is_guest' => false, 'name' => $n]);
        SocialAccount::create([
            'user_id' => $u->id, 'provider' => $provider,
            'provider_user_id' => $provider.'-'.Str::random(8), 'access_token' => 't',
        ]);

        return $u;
    }

    /** Run the scheduled bot-fill sweep as if everyone had waited past the timeout. */
    private function sweepAfterTimeout(): int
    {
        MatchmakingTicket::where('status', 'queued')->update(['enqueued_at' => now()->subSeconds(60)]);

        return $this->service()->fillExpiredWithBots();
    }

    private function room(MatchmakingTicket $t): ?GameRoom
    {
        return $t->room_id ? GameRoom::find($t->room_id) : null;
    }

    private function humans(GameRoom $r): int
    {
        return $r->players()->where('is_bot', false)->count();
    }

    private function bots(GameRoom $r): int
    {
        return $r->players()->where('is_bot', true)->count();
    }

    /* -----------------------------------------------------------------
     | Enqueue + shared queue
     | ----------------------------------------------------------------- */

    public function test_guest_can_enqueue_for_2p_and_4p(): void
    {
        $this->actingAs($this->guest())->postJson('/api/v1/matchmaking/enqueue', ['mode' => '2p'])
            ->assertCreated()->assertJsonPath('data.status', 'queued');

        $this->actingAs($this->guest())->postJson('/api/v1/matchmaking/enqueue', ['mode' => '4p'])
            ->assertCreated()->assertJsonPath('data.status', 'queued');
    }

    public function test_all_providers_share_one_queue_and_match_together(): void
    {
        // guest + google + facebook + email user in the same 4p queue.
        $players = [$this->guest('G'), $this->social('google', 'GG'), $this->social('facebook', 'FB'), User::factory()->create()];
        foreach ($players as $u) {
            $this->service()->enqueue($u, '4p');
        }

        $rooms = MatchmakingTicket::pluck('room_id')->unique()->filter();
        $this->assertCount(1, $rooms, 'all four providers land in the SAME room');

        $room = GameRoom::find($rooms->first());
        $this->assertSame(4, $this->humans($room));
        $this->assertSame(0, $this->bots($room));
    }

    public function test_two_real_2p_users_are_matched_and_started(): void
    {
        $a = $this->guest('A');
        $b = $this->social('google', 'B');
        $this->service()->enqueue($a, '2p');
        $ticketB = $this->service()->enqueue($b, '2p');

        $tickets = MatchmakingTicket::all();
        $this->assertTrue($tickets->every(fn ($t) => $t->status === 'matched'));
        $this->assertCount(1, $tickets->pluck('room_id')->unique());

        // Auto-started: the room is in progress with an ACTIVE match, and every
        // human ticket points at the same match.
        $room = $this->room($ticketB->fresh());
        $this->assertSame('in_progress', $room->status);
        $this->assertNotNull($room->matchup);
        $this->assertSame('active', $room->matchup->status);
    }

    public function test_four_real_4p_users_are_matched(): void
    {
        foreach (range(1, 4) as $i) {
            $this->service()->enqueue($this->guest("U$i"), '4p');
        }
        $rooms = MatchmakingTicket::pluck('room_id')->unique();
        $this->assertCount(1, $rooms);
        $this->assertSame(4, $this->humans(GameRoom::find($rooms->first())));
    }

    public function test_all_humans_receive_the_same_match_id_via_status(): void
    {
        $a = $this->guest('A');
        $b = $this->guest('B');
        $this->actingAs($a)->postJson('/api/v1/matchmaking/enqueue', ['mode' => '2p'])->assertCreated();
        $this->actingAs($b)->postJson('/api/v1/matchmaking/enqueue', ['mode' => '2p'])->assertCreated();

        $sa = $this->actingAs($a)->getJson('/api/v1/matchmaking/status')->assertOk()->json('data');
        $sb = $this->actingAs($b)->getJson('/api/v1/matchmaking/status')->assertOk()->json('data');

        $this->assertSame('matched', $sa['status']);
        $this->assertSame('matched', $sb['status']);
        $this->assertNotNull($sa['match_id']);
        $this->assertSame($sa['match_id'], $sb['match_id']);
    }

    /* -----------------------------------------------------------------
     | Bot-fill thresholds after the timeout
     | ----------------------------------------------------------------- */

    public function test_one_human_becomes_human_plus_bot_in_2p(): void
    {
        $t = $this->service()->enqueue($this->guest('Solo'), '2p');
        $this->assertSame('queued', $t->fresh()->status); // not matched yet

        $started = $this->sweepAfterTimeout();
        $this->assertSame(1, $started);

        $room = $this->room($t->fresh());
        $this->assertSame('matched', $t->fresh()->status);
        $this->assertSame(1, $this->humans($room));
        $this->assertSame(1, $this->bots($room));
    }

    public function test_three_humans_become_three_humans_plus_one_bot_in_4p(): void
    {
        $users = [$this->guest('A'), $this->social('google', 'B'), $this->social('facebook', 'C')];
        foreach ($users as $u) {
            $this->service()->enqueue($u, '4p');
        }

        $started = $this->sweepAfterTimeout();
        $this->assertSame(1, $started, 'the three stale humans are grouped into ONE room');

        $rooms = MatchmakingTicket::pluck('room_id')->unique();
        $this->assertCount(1, $rooms);
        $room = GameRoom::find($rooms->first());
        $this->assertSame(3, $this->humans($room));
        $this->assertSame(1, $this->bots($room));
    }

    public function test_two_humans_become_two_humans_plus_two_bots_in_4p(): void
    {
        foreach ([$this->guest('A'), $this->guest('B')] as $u) {
            $this->service()->enqueue($u, '4p');
        }
        $this->assertSame(1, $this->sweepAfterTimeout());
        $room = GameRoom::find(MatchmakingTicket::pluck('room_id')->unique()->first());
        $this->assertSame(2, $this->humans($room));
        $this->assertSame(2, $this->bots($room));
    }

    public function test_one_human_becomes_one_plus_three_bots_in_4p(): void
    {
        $t = $this->service()->enqueue($this->guest('Solo'), '4p');
        $this->assertSame(1, $this->sweepAfterTimeout());
        $room = $this->room($t->fresh());
        $this->assertSame(1, $this->humans($room));
        $this->assertSame(3, $this->bots($room));
    }

    public function test_partial_humans_are_grouped_before_bot_filling(): void
    {
        // Three 4p humans waiting -> exactly one bot room, not three.
        foreach (range(1, 3) as $i) {
            $this->service()->enqueue($this->guest("U$i"), '4p');
        }
        $started = $this->sweepAfterTimeout();
        $this->assertSame(1, $started);
        $this->assertCount(1, MatchmakingTicket::pluck('room_id')->unique());
    }

    public function test_bot_fill_rooms_are_casual_and_human_only_boards_stay_stakeless(): void
    {
        $this->service()->enqueue($this->guest('Solo'), '2p');
        $this->sweepAfterTimeout();
        $room = GameRoom::first();
        // Bot-fill only ever happens on the free casual board (never a staked pot).
        $this->assertSame('casual', $room->board_tier);
        $this->assertSame(0, (int) $room->stake);
    }

    /* -----------------------------------------------------------------
     | Exclusions / integrity / concurrency
     | ----------------------------------------------------------------- */

    public function test_duplicate_active_tickets_are_prevented(): void
    {
        $u = $this->guest('Dup');
        $t1 = $this->service()->enqueue($u, '2p');
        $t2 = $this->service()->enqueue($u, '2p');

        $this->assertSame($t1->id, $t2->id, 'the same queued ticket is reused');
        $this->assertSame(1, MatchmakingTicket::where('user_id', $u->id)->count());
    }

    public function test_cancelled_tickets_are_ignored_by_matching(): void
    {
        $a = $this->guest('A');
        $this->service()->enqueue($a, '2p');
        $this->service()->cancel($a);

        // A fresh queuer must NOT be paired with the cancelled ticket.
        $b = $this->guest('B');
        $this->service()->enqueue($b, '2p');

        $this->assertSame('queued', MatchmakingTicket::where('user_id', $b->id)->first()->status);
        $this->assertSame('cancelled', MatchmakingTicket::where('user_id', $a->id)->first()->status);
    }

    public function test_matched_tickets_are_not_rematched_by_the_sweep(): void
    {
        // Two humans match immediately (in-progress). A later sweep must not
        // pull their matched tickets into another room.
        $a = $this->guest('A');
        $b = $this->guest('B');
        $this->service()->enqueue($a, '2p');
        $this->service()->enqueue($b, '2p');

        $roomsBefore = MatchmakingTicket::pluck('room_id')->unique();
        $this->sweepAfterTimeout();
        $roomsAfter = MatchmakingTicket::pluck('room_id')->unique();

        $this->assertEquals($roomsBefore->sort()->values(), $roomsAfter->sort()->values());
    }

    public function test_a_user_is_never_matched_into_two_rooms(): void
    {
        $a = $this->guest('A');
        $this->service()->enqueue($a, '4p');
        // Fill to start a room with A.
        foreach (range(1, 3) as $i) {
            $this->service()->enqueue($this->guest("U$i"), '4p');
        }
        // A second sweep must not give A a second room.
        $this->sweepAfterTimeout();

        $this->assertSame(1, MatchmakingTicket::where('user_id', $a->id)->where('status', 'matched')->count());
    }

    public function test_selected_tickets_all_reference_the_started_room(): void
    {
        foreach (range(1, 4) as $i) {
            $this->service()->enqueue($this->guest("U$i"), '4p');
        }
        $room = GameRoom::first();
        $matched = MatchmakingTicket::where('status', 'matched')->get();
        $this->assertCount(4, $matched);
        $this->assertTrue($matched->every(fn ($t) => $t->room_id === $room->id));
    }

    public function test_running_the_sweep_twice_does_not_double_consume(): void
    {
        $this->service()->enqueue($this->guest('Solo'), '2p');
        $first = $this->sweepAfterTimeout();
        $second = $this->service()->fillExpiredWithBots(); // nothing queued now

        $this->assertSame(1, $first);
        $this->assertSame(0, $second);
        $this->assertSame(1, GameRoom::count());
    }

    public function test_requeue_is_allowed_after_the_previous_game_finished(): void
    {
        $a = $this->guest('A');
        $this->service()->enqueue($a, '2p');
        $this->sweepAfterTimeout(); // matched into a bot room
        GameRoom::query()->update(['status' => 'finished']); // that game ends

        $fresh = $this->service()->enqueue($a, '2p');
        $this->assertSame('queued', $fresh->status);
        $this->assertSame(1, MatchmakingTicket::where('user_id', $a->id)->where('status', 'queued')->count());
    }
}
