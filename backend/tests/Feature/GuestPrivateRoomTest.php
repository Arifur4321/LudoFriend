<?php

namespace Tests\Feature;

use App\Models\GuestSession;
use App\Models\SocialAccount;
use App\Models\User;
use App\Models\WalletTransaction;
use App\Services\Economy\WalletService;
use App\Services\RoomService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\Str;
use Tests\TestCase;

/**
 * Guest private rooms + the mixed-authentication matrix (Parts 2, 3, 9).
 *
 * The server treats guest / Google / Facebook / email users identically for
 * casual rooms — there is no per-provider branching — so these tests model the
 * provider only by how the account was created (a guest flag, or a linked
 * SocialAccount) and assert the same room behaviour for every combination.
 */
class GuestPrivateRoomTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        Event::fake(); // suppress broadcast side-effects
    }

    private function guest(string $name = 'Guest'): User
    {
        return User::factory()->guest()->create(['name' => $name]);
    }

    private function social(string $provider, string $name): User
    {
        $user = User::factory()->create(['is_guest' => false, 'name' => $name]);
        SocialAccount::create([
            'user_id' => $user->id,
            'provider' => $provider,
            'provider_user_id' => $provider.'-'.Str::random(10),
            'access_token' => 'graph-token',
        ]);

        return $user;
    }

    /* -----------------------------------------------------------------
     | Guest login regression (the actual root cause)
     | ----------------------------------------------------------------- */

    public function test_guest_login_persists_a_token_that_fits_the_column(): void
    {
        $res = $this->postJson('/api/v1/auth/guest', [
            'device_id' => 'device-guard',
            'guest_name' => 'Guard',
        ])->assertOk()->assertJsonPath('user.is_guest', true);

        $this->assertNotEmpty($res->json('token'));

        // Regression guard for the encrypted-token overflow: the stored guest
        // secret must comfortably fit guest_sessions.token (VARCHAR(128)).
        // SQLite does not enforce length, so we assert it explicitly here.
        $stored = GuestSession::where('device_id', 'device-guard')->firstOrFail();
        $this->assertLessThanOrEqual(128, strlen($stored->getRawOriginal('token')));
    }

    public function test_guest_login_then_create_room_over_http(): void
    {
        $token = $this->postJson('/api/v1/auth/guest', ['device_id' => 'device-e2e'])
            ->assertOk()->json('token');

        $this->withToken($token)
            ->postJson('/api/v1/rooms', ['mode' => '2p', 'visibility' => 'private'])
            ->assertCreated()
            ->assertJsonPath('data.board_tier', 'casual')
            ->assertJsonPath('data.status', 'lobby');
    }

    /* -----------------------------------------------------------------
     | Create / seat / code
     | ----------------------------------------------------------------- */

    public function test_guest_creates_casual_2p_room(): void
    {
        $res = $this->actingAs($this->guest())->postJson('/api/v1/rooms', [
            'mode' => '2p', 'visibility' => 'private',
        ])->assertCreated()
            ->assertJsonPath('data.mode', '2p')
            ->assertJsonPath('data.board_tier', 'casual')
            ->assertJsonPath('data.stake', 0)
            ->assertJsonPath('data.players.0.seat', 0);

        $this->assertMatchesRegularExpression('/^[A-Z0-9]{6}$/', $res->json('data.code'));
    }

    public function test_guest_creates_casual_4p_room(): void
    {
        $this->actingAs($this->guest())->postJson('/api/v1/rooms', [
            'mode' => '4p', 'visibility' => 'private',
        ])->assertCreated()
            ->assertJsonPath('data.mode', '4p')
            ->assertJsonPath('data.capacity', 4);
    }

    public function test_guest_room_codes_are_unique(): void
    {
        $rooms = app(RoomService::class);
        $codes = collect(range(1, 15))
            ->map(fn () => $rooms->create($this->guest(), ['mode' => '2p', 'visibility' => 'private'])->code);

        $this->assertCount(15, $codes->unique());
    }

    public function test_guest_host_is_seated_at_seat_zero(): void
    {
        $guest = $this->guest();
        $room = app(RoomService::class)->create($guest, ['mode' => '4p', 'visibility' => 'private']);

        $this->assertDatabaseHas('game_room_players', [
            'room_id' => $room->id, 'user_id' => $guest->id, 'seat' => 0, 'is_bot' => false,
        ]);
    }

    /* -----------------------------------------------------------------
     | View / ready / leave / start
     | ----------------------------------------------------------------- */

    public function test_guest_can_view_ready_and_leave(): void
    {
        $guest = $this->guest();
        $room = app(RoomService::class)->create($guest, ['mode' => '2p', 'visibility' => 'private']);

        $this->actingAs($guest)->getJson("/api/v1/rooms/{$room->id}")->assertOk()
            ->assertJsonPath('data.code', $room->code);

        $this->actingAs($guest)->postJson("/api/v1/rooms/{$room->id}/ready", ['ready' => true])
            ->assertOk()->assertJsonPath('is_ready', true);

        $this->actingAs($guest)->postJson("/api/v1/rooms/{$room->id}/leave")->assertOk();

        // Host left with no one else -> room cancelled.
        $this->assertSame('cancelled', $room->fresh()->status);
    }

    public function test_guest_host_can_start_casual_room_with_bot_fill(): void
    {
        $guest = $this->guest();
        $room = app(RoomService::class)->create($guest, [
            'mode' => '2p', 'visibility' => 'private', 'bot_fill' => true,
        ]);

        $this->actingAs($guest)->postJson("/api/v1/rooms/{$room->id}/ready", ['ready' => true])->assertOk();

        $this->actingAs($guest)->postJson("/api/v1/rooms/{$room->id}/start")
            ->assertCreated()
            ->assertJsonPath('data.status', 'active');

        $this->assertSame('in_progress', $room->fresh()->status);
    }

    public function test_two_guests_can_start_a_human_only_room(): void
    {
        $host = $this->guest('Host');
        $rooms = app(RoomService::class);
        $room = $rooms->create($host, ['mode' => '2p', 'visibility' => 'private']);
        $joiner = $this->guest('Joiner');
        $rooms->join($room, $joiner);

        $this->actingAs($host)->postJson("/api/v1/rooms/{$room->id}/ready", ['ready' => true])->assertOk();
        $this->actingAs($joiner)->postJson("/api/v1/rooms/{$room->id}/ready", ['ready' => true])->assertOk();

        $this->actingAs($host)->postJson("/api/v1/rooms/{$room->id}/start")->assertCreated();
    }

    /* -----------------------------------------------------------------
     | Mixed-login join matrix (Part 3)
     | ----------------------------------------------------------------- */

    /** @return array<string,array{0:callable,1:callable}> */
    public static function mixedPairs(): array
    {
        return [
            'guest host + google joiner' => ['guest', 'google'],
            'guest host + facebook joiner' => ['guest', 'facebook'],
            'google host + guest joiner' => ['google', 'guest'],
            'facebook host + guest joiner' => ['facebook', 'guest'],
            'guest host + guest joiner' => ['guest', 'guest'],
        ];
    }

    /** @dataProvider mixedPairs */
    public function test_mixed_login_2p_join(string $hostKind, string $joinKind): void
    {
        $host = $hostKind === 'guest' ? $this->guest('H') : $this->social($hostKind, 'H');
        $joiner = $joinKind === 'guest' ? $this->guest('J') : $this->social($joinKind, 'J');

        $room = app(RoomService::class)->create($host, ['mode' => '2p', 'visibility' => 'private']);

        $this->actingAs($joiner)
            ->postJson('/api/v1/rooms/join', ['code' => $room->code])
            ->assertOk();

        $this->assertDatabaseHas('game_room_players', [
            'room_id' => $room->id, 'user_id' => $joiner->id,
        ]);
    }

    public function test_mixed_4p_room_guest_google_facebook_guest(): void
    {
        $rooms = app(RoomService::class);
        $host = $this->guest('G1');
        $room = $rooms->create($host, ['mode' => '4p', 'visibility' => 'private']);

        foreach ([$this->social('google', 'GG'), $this->social('facebook', 'FB'), $this->guest('G2')] as $u) {
            $this->actingAs($u)->postJson('/api/v1/rooms/join', ['code' => $room->code])->assertOk();
        }

        $this->assertSame(4, $room->fresh()->players()->count());
    }

    /* -----------------------------------------------------------------
     | Idempotency / integrity / rejection (4xx not 500)
     | ----------------------------------------------------------------- */

    public function test_rejoin_is_idempotent_and_never_double_seats(): void
    {
        $rooms = app(RoomService::class);
        $room = $rooms->create($this->guest('H'), ['mode' => '4p', 'visibility' => 'private']);
        $joiner = $this->social('google', 'J');

        $this->actingAs($joiner)->postJson('/api/v1/rooms/join', ['code' => $room->code])->assertOk();
        $this->actingAs($joiner)->postJson('/api/v1/rooms/join', ['code' => $room->code])->assertOk();

        $this->assertSame(1, $room->fresh()->players()->where('user_id', $joiner->id)->count());
        $this->assertDatabaseCount('game_room_players', 2); // host + joiner
    }

    public function test_full_room_join_is_rejected_with_409(): void
    {
        $rooms = app(RoomService::class);
        $room = $rooms->create($this->guest('H'), ['mode' => '2p', 'visibility' => 'private']);
        $rooms->join($room, $this->guest('J'));

        $this->actingAs($this->guest('Late'))
            ->postJson('/api/v1/rooms/join', ['code' => $room->code])
            ->assertStatus(409)
            ->assertJsonPath('message', 'Room is full.');
    }

    public function test_started_room_join_is_rejected_with_409(): void
    {
        $rooms = app(RoomService::class);
        $host = $this->guest('H');
        $room = $rooms->create($host, ['mode' => '2p', 'visibility' => 'private', 'bot_fill' => true]);
        $rooms->setReady($room, $host, true);
        $rooms->start($room);

        $this->actingAs($this->social('facebook', 'Late'))
            ->postJson('/api/v1/rooms/join', ['code' => $room->code])
            ->assertStatus(409);
    }

    public function test_unknown_room_code_returns_422_not_500(): void
    {
        $this->actingAs($this->guest())
            ->postJson('/api/v1/rooms/join', ['code' => 'ZZZZZZ'])
            ->assertStatus(422); // exists:game_rooms,code validation
    }

    public function test_empty_board_tier_falls_back_to_casual_not_500(): void
    {
        $this->actingAs($this->guest())
            ->postJson('/api/v1/rooms', ['mode' => '2p', 'visibility' => 'private', 'board_tier' => ''])
            ->assertCreated()
            ->assertJsonPath('data.board_tier', 'casual');
    }

    /* -----------------------------------------------------------------
     | Economy guard rails stay intact (Part 2)
     | ----------------------------------------------------------------- */

    public function test_guest_cannot_host_staked_board_without_coins(): void
    {
        // A brand-new guest has the signup bonus only; a diamond board (20k) is
        // unaffordable. Expect a clean 422, never a 500, and no room created.
        $token = $this->postJson('/api/v1/auth/guest', ['device_id' => 'poor-guest'])->json('token');

        $this->withToken($token)->postJson('/api/v1/rooms', [
            'mode' => '4p', 'visibility' => 'private', 'board_tier' => 'diamond',
        ])->assertStatus(422)->assertJsonPath('message', 'Not enough coins to host this board.');

        $this->assertDatabaseCount('game_rooms', 0);
    }

    public function test_bots_are_not_allowed_on_staked_boards(): void
    {
        // Give the host enough coins so the failure is specifically the bot rule.
        $host = User::factory()->create();
        app(WalletService::class)->credit(
            $host->id, 100000, WalletTransaction::TYPE_SIGNUP_BONUS
        );

        $this->actingAs($host)->postJson('/api/v1/rooms', [
            'mode' => '4p', 'visibility' => 'private', 'board_tier' => 'classic', 'bot_fill' => true,
        ])->assertStatus(422)->assertJsonPath('message', 'Bots are not allowed on staked boards.');
    }
}
