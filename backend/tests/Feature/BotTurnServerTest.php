<?php

namespace Tests\Feature;

use App\Http\Resources\MatchResource;
use App\Jobs\AdvanceStuckBotTurns;
use App\Jobs\PlayBotTurn;
use App\Models\MatchEvent;
use App\Models\MatchState;
use App\Models\Matchup;
use App\Models\User;
use App\Services\Game\BotStrategyService;
use App\Services\Game\GameEngineService;
use App\Services\RoomService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Bus;
use Illuminate\Support\Facades\Event;
use Tests\TestCase;

/**
 * Server-authoritative online bot turns. Colours by seat: 0=red, 1=green,
 * 2=yellow (humans), 3=blue (the bot). A bot's turn must be driven entirely by
 * the server — never by a human client — and must stop the instant control
 * returns to a human.
 */
class BotTurnServerTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        Event::fake();
        Bus::fake();
    }

    /** 3 humans + 1 bot in a casual 4-player room (bot at seat 3 = blue). */
    private function startCasualWithBot(): Matchup
    {
        $rooms = app(RoomService::class);
        $host = User::factory()->create();
        $room = $rooms->create($host, [
            'mode' => '4p', 'visibility' => 'private', 'board_tier' => 'casual', 'bot_fill' => true,
        ]);
        $h2 = User::factory()->create();
        $h3 = User::factory()->create();
        $rooms->join($room, $h2);
        $rooms->join($room, $h3);
        $rooms->setReady($room, $host, true);
        $rooms->setReady($room, $h2, true);
        $rooms->setReady($room, $h3, true);

        return $rooms->start($room)->load('players');
    }

    private function setState(Matchup $match, array $overrides): void
    {
        $row = MatchState::where('match_id', $match->id)->first();
        $row->state = array_replace($row->state, $overrides);
        $row->save();
    }

    private function drive(Matchup $match): void
    {
        (new PlayBotTurn($match->id))->drive(
            app(GameEngineService::class),
            app(BotStrategyService::class),
        );
    }

    public function test_bot_turn_is_dispatched_when_a_human_passes_the_turn_to_a_bot(): void
    {
        $match = $this->startCasualWithBot();

        // yellow (human) makes a plain move → the turn passes to blue (bot).
        $this->setState($match, [
            'turn' => 'yellow', 'phase' => 'awaiting_move', 'dice' => 1,
            'tokens' => ['red' => [-1, -1, -1, -1], 'green' => [-1, -1, -1, -1], 'yellow' => [5, -1, -1, -1], 'blue' => [-1, -1, -1, -1]],
        ]);

        app(GameEngineService::class)->move($match, 'yellow', 0);

        Bus::assertDispatched(PlayBotTurn::class);
    }

    public function test_no_bot_turn_is_dispatched_when_the_next_player_is_human(): void
    {
        $match = $this->startCasualWithBot();

        // red (human) passes to green (human) — no bot involved.
        $this->setState($match, [
            'turn' => 'red', 'phase' => 'awaiting_move', 'dice' => 1,
            'tokens' => ['red' => [5, -1, -1, -1], 'green' => [-1, -1, -1, -1], 'yellow' => [-1, -1, -1, -1], 'blue' => [-1, -1, -1, -1]],
        ]);

        app(GameEngineService::class)->move($match, 'red', 0);

        Bus::assertNotDispatched(PlayBotTurn::class);
    }

    public function test_bot_driver_moves_once_and_passes_the_turn(): void
    {
        $match = $this->startCasualWithBot();
        $this->setState($match, [
            'turn' => 'blue', 'phase' => 'awaiting_move', 'dice' => 1,
            'tokens' => ['red' => [-1, -1, -1, -1], 'green' => [-1, -1, -1, -1], 'yellow' => [-1, -1, -1, -1], 'blue' => [5, -1, -1, -1]],
        ]);

        $this->drive($match);

        $moved = MatchEvent::where('match_id', $match->id)
            ->where('type', 'token_moved')->where('actor_color', 'blue')->count();
        $this->assertSame(1, $moved);

        $fresh = MatchState::where('match_id', $match->id)->first()->state;
        $this->assertSame([6, -1, -1, -1], $fresh['tokens']['blue']);
        $this->assertSame('red', $fresh['turn']); // blue → red (next in order)
    }

    public function test_bot_driver_selects_only_a_legal_move(): void
    {
        config(['bots.turn.max_actions' => 1]); // one action, then stop
        $match = $this->startCasualWithBot();

        // Dice 6, all four blue tokens in base → the ONLY legal move is to
        // release a token from base to rel 0.
        $this->setState($match, [
            'turn' => 'blue', 'phase' => 'awaiting_move', 'dice' => 6,
            'tokens' => ['red' => [-1, -1, -1, -1], 'green' => [-1, -1, -1, -1], 'yellow' => [-1, -1, -1, -1], 'blue' => [-1, -1, -1, -1]],
        ]);

        $this->drive($match);

        $blue = MatchState::where('match_id', $match->id)->first()->state['tokens']['blue'];
        $this->assertContains(0, $blue);                  // one token left base
        $this->assertSame(3, count(array_filter($blue, fn ($r) => $r === -1)));
    }

    public function test_running_the_bot_driver_twice_executes_the_turn_once(): void
    {
        $match = $this->startCasualWithBot();
        $this->setState($match, [
            'turn' => 'blue', 'phase' => 'awaiting_move', 'dice' => 1,
            'tokens' => ['red' => [-1, -1, -1, -1], 'green' => [-1, -1, -1, -1], 'yellow' => [-1, -1, -1, -1], 'blue' => [5, -1, -1, -1]],
        ]);

        // Two "workers" driving the same match must not double-apply.
        $this->drive($match);
        $this->drive($match);

        $moved = MatchEvent::where('match_id', $match->id)
            ->where('type', 'token_moved')->where('actor_color', 'blue')->count();
        $this->assertSame(1, $moved);
        $this->assertSame('red', MatchState::where('match_id', $match->id)->first()->state['turn']);
    }

    public function test_bot_driver_stops_at_a_human_and_never_leaves_the_turn_on_itself(): void
    {
        $match = $this->startCasualWithBot();
        // Bot has tokens in play so it can always act; dice is random here.
        $this->setState($match, [
            'turn' => 'blue', 'phase' => 'awaiting_roll', 'dice' => null,
            'tokens' => ['red' => [-1, -1, -1, -1], 'green' => [-1, -1, -1, -1], 'yellow' => [-1, -1, -1, -1], 'blue' => [10, 20, -1, -1]],
        ]);

        $this->drive($match);

        $fresh = MatchState::where('match_id', $match->id)->first()->state;
        // The bot rolled at least once and handed control back to a human.
        $rolled = MatchEvent::where('match_id', $match->id)
            ->where('type', 'dice_rolled')->where('actor_color', 'blue')->count();
        $this->assertGreaterThanOrEqual(1, $rolled);
        $this->assertContains($fresh['turn'], ['red', 'green', 'yellow']);
    }

    public function test_recovery_sweep_redispatches_a_stuck_bot_turn(): void
    {
        $match = $this->startCasualWithBot();
        $this->setState($match, ['turn' => 'blue', 'phase' => 'awaiting_roll', 'dice' => null]);

        // Make the state look stale (older than the recovery grace period).
        MatchState::where('match_id', $match->id)->update(['updated_at' => now()->subMinute()]);

        (new AdvanceStuckBotTurns())->handle(app(GameEngineService::class));

        Bus::assertDispatched(PlayBotTurn::class);
    }

    public function test_bot_name_is_persisted_and_exposed_in_match_resource(): void
    {
        $match = $this->startCasualWithBot();

        $bot = $match->players()->where('is_bot', true)->first();
        $this->assertNotNull($bot->display_name);
        $this->assertNotSame('Bot', $bot->display_name);

        $payload = (new MatchResource($match->load(['players.user', 'state'])))->resolve();
        $botEntry = collect($payload['players'])->firstWhere('is_bot', true);
        $this->assertSame($bot->display_name, $botEntry['name']);

        // Reconnect / refetch preserves the exact same persisted name.
        $again = Matchup::find($match->id)->players()->where('is_bot', true)->first();
        $this->assertSame($bot->display_name, $again->display_name);
    }

    public function test_two_bots_in_one_match_get_unique_names(): void
    {
        $rooms = app(RoomService::class);
        $host = User::factory()->create();
        $room = $rooms->create($host, [
            'mode' => '4p', 'visibility' => 'private', 'board_tier' => 'casual', 'bot_fill' => true,
        ]);
        $h2 = User::factory()->create();
        $rooms->join($room, $h2);
        $rooms->setReady($room, $host, true);
        $rooms->setReady($room, $h2, true);
        $match = $rooms->start($room)->load('players'); // seats 2 & 3 become bots

        $names = $match->players()->where('is_bot', true)->pluck('display_name');
        $this->assertSame(2, $names->count());
        $this->assertSame(2, $names->unique()->count());
    }
}
