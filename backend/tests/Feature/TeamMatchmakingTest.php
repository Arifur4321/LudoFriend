<?php

namespace Tests\Feature;

use App\Models\MatchmakingTicket;
use App\Models\Matchup;
use App\Models\User;
use App\Services\MatchmakingService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Bus;
use Illuminate\Support\Facades\Event;
use Tests\TestCase;

/**
 * Public 2v2 team matchmaking: only explicit team tickets enter the queue, it
 * waits for four real humans, never bot-fills, never mixes with free-for-all,
 * seats partners on opposite seats, and lands all four in the same match.
 */
class TeamMatchmakingTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        Event::fake();
        Bus::fake();
    }

    private function mm(): MatchmakingService
    {
        return app(MatchmakingService::class);
    }

    public function test_team_queue_waits_for_four_humans_then_matches_them_into_one_room(): void
    {
        $mm = $this->mm();
        $users = User::factory()->count(4)->create();

        // First three stay queued — no match may form with fewer than four.
        foreach ($users->take(3) as $u) {
            $this->assertSame('queued', $mm->enqueue($u, '4p', true)->status);
        }
        $this->assertSame(0, Matchup::count());

        // The fourth completes the team table.
        $last = $mm->enqueue($users[3], '4p', true);
        $this->assertSame('matched', $last->fresh()->status);

        $this->assertSame(1, Matchup::count());
        $match = Matchup::first();
        $this->assertTrue((bool) $match->team_mode);

        // All four tickets reference the same room; no bot was ever seated.
        $roomIds = MatchmakingTicket::whereNotNull('room_id')->pluck('room_id')->unique();
        $this->assertCount(1, $roomIds);
        $this->assertSame(4, $match->players()->count());
        $this->assertSame(0, $match->players()->where('is_bot', true)->count());
    }

    public function test_team_and_free_for_all_queues_do_not_mix(): void
    {
        $mm = $this->mm();
        // Two team + two free-for-all, all 4p: neither queue reaches four.
        $mm->enqueue(User::factory()->create(), '4p', true);
        $mm->enqueue(User::factory()->create(), '4p', true);
        $mm->enqueue(User::factory()->create(), '4p', false);
        $mm->enqueue(User::factory()->create(), '4p', false);

        $this->assertSame(0, Matchup::count());
        $this->assertSame(4, MatchmakingTicket::where('status', 'queued')->count());
    }

    public function test_team_matchmaking_assigns_opposite_seats(): void
    {
        $mm = $this->mm();
        foreach (User::factory()->count(4)->create() as $u) {
            $mm->enqueue($u, '4p', true);
        }

        $match = Matchup::firstOrFail();
        $bySeat = $match->players()->get()->keyBy('seat');
        // Seats 0 & 2 => Team A (0); seats 1 & 3 => Team B (1).
        $this->assertSame(0, (int) $bySeat[0]->team);
        $this->assertSame(1, (int) $bySeat[1]->team);
        $this->assertSame(0, (int) $bySeat[2]->team);
        $this->assertSame(1, (int) $bySeat[3]->team);
    }

    public function test_bot_fill_sweep_never_fills_team_tickets(): void
    {
        $mm = $this->mm();
        // Two team users left waiting well past the bot-fill cutoff.
        foreach (User::factory()->count(2)->create() as $u) {
            $mm->enqueue($u, '4p', true);
        }
        MatchmakingTicket::query()->update(['enqueued_at' => now()->subMinutes(5)]);

        $started = $mm->fillExpiredWithBots();

        $this->assertSame(0, $started);
        $this->assertSame(0, Matchup::count());
        $this->assertSame(2, MatchmakingTicket::where('status', 'queued')->count());
    }
}
