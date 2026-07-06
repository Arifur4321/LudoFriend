<?php

namespace Tests\Feature;

use App\Exceptions\InsufficientCoinsException;
use App\Models\Matchup;
use App\Models\MatchState;
use App\Models\PlayerProfile;
use App\Models\User;
use App\Services\Economy\WalletService;
use App\Services\Game\GameEngineService;
use App\Services\RoomService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Bus;
use Illuminate\Support\Facades\Event;
use Tests\TestCase;

class StakedMatchTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        Event::fake();
        Bus::fake();
    }

    private function funded(int $coins): User
    {
        $u = User::factory()->create();
        PlayerProfile::factory()->create(['user_id' => $u->id, 'coins' => $coins]);

        return $u;
    }

    /** Drive an already-started match to a win for $winnerColor. */
    private function forceWin(Matchup $match, string $winnerColor): void
    {
        $colors = $match->players->pluck('color')->all();
        $tokens = [];
        foreach ($colors as $c) {
            $tokens[$c] = $c === $winnerColor ? [56, 56, 56, 55] : [-1, -1, -1, -1];
        }

        $row = MatchState::where('match_id', $match->id)->first();
        $row->state = array_replace($row->state, [
            'turn' => $winnerColor,
            'phase' => 'awaiting_move',
            'dice' => 1,
            'tokens' => $tokens,
        ]);
        $row->save();

        app(GameEngineService::class)->move($match, $winnerColor, 3); // move token idx 3 home
    }

    public function test_stake_is_escrowed_at_start_and_paid_in_full_to_winner(): void
    {
        $red = $this->funded(500);
        $green = $this->funded(500);
        $rooms = app(RoomService::class);
        $wallet = app(WalletService::class);

        $room = $rooms->create($red, ['mode' => '2p', 'visibility' => 'private', 'board_tier' => 'classic']);
        $rooms->join($room, $green);
        $rooms->setReady($room, $red, true);
        $rooms->setReady($room, $green, true);
        $match = $rooms->start($room);

        // Escrow: each debited the 200 stake, pot = 400.
        $this->assertSame(300, $wallet->balance($red));
        $this->assertSame(300, $wallet->balance($green));
        $this->assertSame(400, (int) $match->fresh()->pot);
        $this->assertDatabaseHas('wallet_transactions', ['user_id' => $red->id, 'type' => 'stake', 'amount' => -200]);

        $match->load('players');
        $winnerColor = $match->players->firstWhere('user_id', $red->id)->color;
        $this->forceWin($match, $winnerColor);

        // Pure winner-takes-all: red gets the whole 400 pot.
        $this->assertSame(700, $wallet->balance($red));
        $this->assertSame(300, $wallet->balance($green));
        $this->assertDatabaseHas('wallet_transactions', ['user_id' => $red->id, 'type' => 'prize', 'amount' => 400]);
    }

    public function test_start_is_atomic_when_a_player_cannot_afford(): void
    {
        $red = $this->funded(500);
        $green = $this->funded(500);
        $rooms = app(RoomService::class);
        $wallet = app(WalletService::class);

        $room = $rooms->create($red, ['mode' => '2p', 'visibility' => 'private', 'board_tier' => 'classic']);
        $rooms->join($room, $green);
        // Drain green below the stake AFTER joining.
        $wallet->debit($green, 400, 'adjustment'); // green now 100 < 200
        $rooms->setReady($room, $red, true);
        $rooms->setReady($room, $green, true);

        try {
            $rooms->start($room);
            $this->fail('Expected InsufficientCoinsException.');
        } catch (InsufficientCoinsException) {
            // expected
        }

        // Nothing escrowed; red's stake debit rolled back; no match created.
        $this->assertSame(500, $wallet->balance($red));
        $this->assertSame(100, $wallet->balance($green));
        $this->assertDatabaseCount('matches', 0);
    }

    public function test_hosting_a_staked_board_requires_affordability(): void
    {
        $poor = $this->funded(100);

        $this->actingAs($poor)->postJson('/api/v1/rooms', [
            'mode' => '2p', 'visibility' => 'private', 'board_tier' => 'classic',
        ])->assertStatus(422)->assertJsonPath('message', 'Not enough coins to host this board.');
    }

    public function test_bots_are_rejected_on_staked_boards(): void
    {
        $host = $this->funded(500);

        $this->actingAs($host)->postJson('/api/v1/rooms', [
            'mode' => '4p', 'visibility' => 'private', 'board_tier' => 'classic', 'bot_fill' => true,
        ])->assertStatus(422)->assertJsonPath('message', 'Bots are not allowed on staked boards.');
    }
}
