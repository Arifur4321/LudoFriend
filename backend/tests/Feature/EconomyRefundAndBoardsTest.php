<?php

namespace Tests\Feature;

use App\Models\Matchup;
use App\Models\PlayerProfile;
use App\Models\User;
use App\Services\Economy\WalletService;
use App\Services\Game\GameEngineService;
use App\Services\RoomService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Bus;
use Illuminate\Support\Facades\Event;
use Tests\TestCase;

class EconomyRefundAndBoardsTest extends TestCase
{
    use RefreshDatabase;

    private function funded(int $coins): User
    {
        $u = User::factory()->create();
        PlayerProfile::factory()->create(['user_id' => $u->id, 'coins' => $coins]);

        return $u;
    }

    public function test_aborting_a_match_refunds_every_stake(): void
    {
        Event::fake();
        Bus::fake();
        $wallet = app(WalletService::class);
        $rooms = app(RoomService::class);

        $red = $this->funded(500);
        $green = $this->funded(500);
        $room = $rooms->create($red, ['mode' => '2p', 'visibility' => 'private', 'board_tier' => 'classic']);
        $rooms->join($room, $green);
        $rooms->setReady($room, $red, true);
        $rooms->setReady($room, $green, true);
        $match = $rooms->start($room);

        $this->assertSame(300, $wallet->balance($red)); // escrowed

        app(GameEngineService::class)->abortMatch($match, 'idle_timeout');

        // Both refunded to full; match marked abandoned; pot cleared.
        $this->assertSame(500, $wallet->balance($red));
        $this->assertSame(500, $wallet->balance($green));
        $fresh = Matchup::find($match->id);
        $this->assertSame('abandoned', $fresh->status);
        $this->assertSame(0, (int) $fresh->pot);
        $this->assertDatabaseHas('wallet_transactions', ['user_id' => $red->id, 'type' => 'refund', 'amount' => 200]);
    }

    public function test_boards_endpoint_lists_staked_tiers_with_affordability(): void
    {
        $u = $this->funded(500);

        $res = $this->actingAs($u)->getJson('/api/v1/boards')->assertOk()->json();

        $keys = array_column($res['tiers'], 'key');
        $this->assertContains('classic', $keys);
        $this->assertContains('diamond', $keys);
        $this->assertNotContains('casual', $keys, 'Casual/free tier must be hidden from the board list.');

        $byKey = collect($res['tiers'])->keyBy('key');
        $this->assertTrue($byKey['classic']['affordable']);   // 500 >= 200
        $this->assertFalse($byKey['diamond']['affordable']);  // 500 < 20000
    }

    public function test_google_login_requires_an_id_token(): void
    {
        $this->postJson('/api/v1/auth/google', [])
            ->assertStatus(422)
            ->assertJsonValidationErrors('id_token');
    }
}
