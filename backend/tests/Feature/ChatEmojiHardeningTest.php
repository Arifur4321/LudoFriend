<?php

namespace Tests\Feature;

use App\Events\ChatMessageSent;
use App\Events\EmojiReactionSent;
use App\Models\MatchMessage;
use App\Models\Matchup;
use App\Models\SocialAccount;
use App\Models\User;
use App\Services\RoomService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Event;
use Tests\TestCase;

/**
 * Companion to ChatFlowTest: the client-reconciliation contract of the send
 * response, guest quick-phrase rules, cursor pagination, mixed-login parity
 * (Facebook / Google / guest), and broadcast-only-after-persist ordering.
 */
class ChatEmojiHardeningTest extends TestCase
{
    use RefreshDatabase;

    private User $red;

    private User $green;

    private Matchup $match;

    protected function setUp(): void
    {
        parent::setUp();
        Event::fake();

        $this->red = User::factory()->create(['name' => 'Red Player']);
        $this->green = User::factory()->create(['name' => 'Green Player']);
        $this->match = $this->startMatch($this->red, $this->green);
    }

    private function startMatch(User $a, User $b): Matchup
    {
        $rooms = app(RoomService::class);
        $room = $rooms->create($a, ['mode' => '2p', 'visibility' => 'private']);
        $rooms->join($room, $b);
        $rooms->setReady($room, $a, true);
        $rooms->setReady($room, $b, true);

        return $rooms->start($room)->load('players');
    }

    private function chatUrl(): string
    {
        return "/api/v1/matches/{$this->match->id}/chat";
    }

    /* -------------------------------------------- send-response contract */

    public function test_send_response_carries_the_authoritative_message(): void
    {
        // The Flutter client reconciles its optimistic bubble from THIS
        // response whenever the Reverb echo is lost, so the shape is a
        // contract: id + client_id + name + ts must all be present.
        $data = $this->actingAs($this->red)
            ->postJson($this->chatUrl(), [
                'body' => 'hello there',
                'client_id' => 'tap-1',
            ])
            ->assertOk()
            ->json();

        $this->assertIsInt($data['data']['id']);
        $this->assertSame('tap-1', $data['data']['client_id']);
        $this->assertSame('Red Player', $data['data']['name']);
        $this->assertSame('hello there', $data['data']['body']);
        $this->assertNotEmpty($data['data']['ts']);
        $this->assertFalse($data['meta']['duplicate']);
    }

    public function test_duplicate_send_response_returns_same_message_for_reconcile(): void
    {
        // An idempotent retry broadcasts nothing, so its RESPONSE is the only
        // carrier of the stored id — it must match the original exactly.
        $first = $this->actingAs($this->red)
            ->postJson($this->chatUrl(), ['body' => 'once', 'client_id' => 'tap-2'])
            ->json('data');

        $second = $this->actingAs($this->red)
            ->postJson($this->chatUrl(), ['body' => 'once', 'client_id' => 'tap-2'])
            ->assertOk()
            ->json();

        $this->assertTrue($second['meta']['duplicate']);
        $this->assertSame($first['id'], $second['data']['id']);
        $this->assertSame(1, MatchMessage::where('match_id', $this->match->id)->count());
        Event::assertDispatchedTimes(ChatMessageSent::class, 1);
    }

    /* ------------------------------------------------------- guest rules */

    public function test_guest_can_send_an_approved_quick_phrase(): void
    {
        $guestMatch = $this->guestSeatedMatch($guest);

        $this->actingAs($guest)
            ->postJson("/api/v1/matches/{$guestMatch->id}/chat", [
                'body' => 'Good luck!',
            ])
            ->assertOk()
            ->assertJsonPath('data.body', 'Good luck!');
    }

    public function test_guest_free_text_is_rejected_and_not_broadcast(): void
    {
        $guestMatch = $this->guestSeatedMatch($guest);

        $this->actingAs($guest)
            ->postJson("/api/v1/matches/{$guestMatch->id}/chat", [
                'body' => 'free text from a guest',
            ])
            ->assertStatus(422);

        $this->assertSame(0, MatchMessage::where('match_id', $guestMatch->id)->count());
        Event::assertNotDispatched(ChatMessageSent::class);
    }

    /** Build a match where one seat is a guest; returns it and sets $guest. */
    private function guestSeatedMatch(?User &$guest): Matchup
    {
        $guest = User::factory()->create(['is_guest' => true, 'email' => null, 'name' => 'Guest 1']);
        $host = User::factory()->create();

        return $this->startMatch($guest, $host);
    }

    /* -------------------------------------------------------- pagination */

    public function test_history_cursor_pages_are_stable_and_non_overlapping(): void
    {
        foreach (range(1, 5) as $i) {
            $this->actingAs($this->red)
                ->postJson($this->chatUrl(), ['body' => "m{$i}", 'client_id' => "c{$i}"])
                ->assertOk();
        }

        $page1 = $this->actingAs($this->green)
            ->getJson($this->chatUrl().'?limit=2')
            ->assertOk()
            ->json();

        $this->assertSame(['m4', 'm5'], array_column($page1['data'], 'body'));
        $this->assertTrue($page1['meta']['has_more']);
        $before = $page1['meta']['next_before_id'];
        $this->assertNotNull($before);

        $page2 = $this->actingAs($this->green)
            ->getJson($this->chatUrl()."?limit=2&before_id={$before}")
            ->assertOk()
            ->json();

        $this->assertSame(['m2', 'm3'], array_column($page2['data'], 'body'));

        // No overlap between pages; ordering ascending within each page.
        $ids1 = array_column($page1['data'], 'id');
        $ids2 = array_column($page2['data'], 'id');
        $this->assertEmpty(array_intersect($ids1, $ids2));
        $this->assertSame($ids2, collect($ids2)->sort()->values()->all());
    }

    /* ----------------------------------------- broadcast-after-persist */

    public function test_chat_broadcast_happens_only_after_the_row_is_persisted(): void
    {
        $this->actingAs($this->red)
            ->postJson($this->chatUrl(), ['body' => 'ordered', 'client_id' => 'p1'])
            ->assertOk();

        // The event is dispatched with the persisted id — meaning the DB row
        // existed before the broadcast was queued (never the other way round).
        Event::assertDispatched(ChatMessageSent::class, function (ChatMessageSent $e) {
            return MatchMessage::whereKey($e->id)->exists()
                && $e->matchId === $this->match->id
                && $e->name === 'Red Player';
        });
    }

    public function test_invalid_message_broadcasts_nothing(): void
    {
        $this->actingAs($this->red)
            ->postJson($this->chatUrl(), ['body' => '   '])
            ->assertStatus(422);

        Event::assertNotDispatched(ChatMessageSent::class);
        $this->assertSame(0, MatchMessage::where('match_id', $this->match->id)->count());
    }

    /* ------------------------------------------------ mixed-login parity */

    public function test_facebook_google_and_guest_players_share_identical_emoji_rules(): void
    {
        // A 2p match per pairing keeps seats simple; the rule under test is
        // that PROVIDER never affects authorization or the allow-list.
        $fb = User::factory()->create(['name' => 'FB Player']);
        SocialAccount::create([
            'user_id' => $fb->id,
            'provider' => 'facebook',
            'provider_user_id' => 'fb-1',
        ]);

        $google = User::factory()->create(['name' => 'G Player']);
        SocialAccount::create([
            'user_id' => $google->id,
            'provider' => 'google',
            'provider_user_id' => 'g-1',
        ]);

        $guest = User::factory()->create(['is_guest' => true, 'email' => null]);

        $match = $this->startMatch($fb, $google);
        foreach ([$fb, $google] as $user) {
            $this->actingAs($user)
                ->postJson("/api/v1/matches/{$match->id}/emoji", ['emoji' => '🎉'])
                ->assertOk();
            $this->actingAs($user)
                ->postJson("/api/v1/matches/{$match->id}/emoji", ['emoji' => 'not-allowed'])
                ->assertStatus(422);
        }

        $guestMatch = $this->startMatch($guest, $fb);
        $this->actingAs($guest)
            ->postJson("/api/v1/matches/{$guestMatch->id}/emoji", ['emoji' => '🎉'])
            ->assertOk();
        $this->actingAs($guest)
            ->postJson("/api/v1/matches/{$guestMatch->id}/emoji", ['emoji' => 'nope'])
            ->assertStatus(422);

        Event::assertDispatchedTimes(EmojiReactionSent::class, 3);
    }

    public function test_emoji_event_ids_are_unique_per_send(): void
    {
        $ids = [];
        foreach (range(1, 3) as $i) {
            $ids[] = $this->actingAs($this->red)
                ->postJson("/api/v1/matches/{$this->match->id}/emoji", ['emoji' => '🔥'])
                ->assertOk()
                ->json('data.id');
        }

        $this->assertCount(3, array_unique($ids), 'every reaction needs its own stable id for client de-duplication');
    }
}
