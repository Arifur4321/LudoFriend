<?php

namespace Tests\Feature;

use App\Events\ChatMessageSent;
use App\Events\EmojiReactionSent;
use App\Models\MatchMessage;
use App\Models\Matchup;
use App\Models\User;
use App\Services\RoomService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\Facades\RateLimiter;
use Tests\TestCase;

/**
 * In-match chat + emoji: authorization, idempotency, ordering, pagination,
 * validation, rate limiting, sender authenticity, and cross-match isolation.
 */
class ChatFlowTest extends TestCase
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

    /* ------------------------------------------------------------------ chat */

    public function test_seated_player_can_send_a_message_and_it_persists(): void
    {
        $this->actingAs($this->red)
            ->postJson("/api/v1/matches/{$this->match->id}/chat", ['body' => 'Good luck!'])
            ->assertOk()
            ->assertJsonPath('data.body', 'Good luck!')
            ->assertJsonPath('data.name', 'Red Player')
            ->assertJsonPath('meta.duplicate', false);

        $this->assertDatabaseHas('match_messages', [
            'match_id' => $this->match->id,
            'user_id' => $this->red->id,
            'body' => 'Good luck!',
        ]);
        Event::assertDispatched(ChatMessageSent::class);
    }

    public function test_non_member_cannot_send(): void
    {
        $stranger = User::factory()->create();
        $this->actingAs($stranger)
            ->postJson("/api/v1/matches/{$this->match->id}/chat", ['body' => 'hello'])
            ->assertForbidden();
        Event::assertNotDispatched(ChatMessageSent::class);
    }

    public function test_non_member_cannot_read_history(): void
    {
        $stranger = User::factory()->create();
        $this->actingAs($stranger)
            ->getJson("/api/v1/matches/{$this->match->id}/chat")
            ->assertForbidden();
    }

    public function test_sender_identity_comes_from_auth_not_request(): void
    {
        // Attempt to spoof identity via extra body fields — they must be ignored.
        $this->actingAs($this->red)->postJson("/api/v1/matches/{$this->match->id}/chat", [
            'body' => 'hi',
            'user_id' => $this->green->id,
            'name' => 'Impersonated',
        ])->assertOk()->assertJsonPath('data.name', 'Red Player');

        $this->assertDatabaseHas('match_messages', [
            'match_id' => $this->match->id,
            'user_id' => $this->red->id, // stored from auth, not the request
        ]);
        $this->assertDatabaseMissing('match_messages', ['user_id' => $this->green->id]);
    }

    public function test_duplicate_client_id_stores_and_broadcasts_once(): void
    {
        $url = "/api/v1/matches/{$this->match->id}/chat";
        $payload = ['body' => 'Nice move!', 'client_id' => 'tap-abc'];

        $this->actingAs($this->red)->postJson($url, $payload)
            ->assertOk()->assertJsonPath('meta.duplicate', false);
        $this->actingAs($this->red)->postJson($url, $payload)
            ->assertOk()->assertJsonPath('meta.duplicate', true);

        $this->assertSame(1, MatchMessage::where('match_id', $this->match->id)
            ->where('client_id', 'tap-abc')->count());
        Event::assertDispatchedTimes(ChatMessageSent::class, 1);
    }

    public function test_history_is_returned_in_stable_ascending_order(): void
    {
        foreach (['one', 'two', 'three'] as $b) {
            $this->actingAs($this->red)->postJson("/api/v1/matches/{$this->match->id}/chat", ['body' => $b]);
        }

        $bodies = $this->actingAs($this->green)
            ->getJson("/api/v1/matches/{$this->match->id}/chat")
            ->assertOk()
            ->json('data.*.body');

        $this->assertSame(['one', 'two', 'three'], $bodies);
    }

    public function test_history_limit_is_capped(): void
    {
        for ($i = 0; $i < 55; $i++) {
            MatchMessage::create([
                'match_id' => $this->match->id,
                'user_id' => $this->red->id,
                'type' => 'text',
                'body' => "m{$i}",
            ]);
        }

        $res = $this->actingAs($this->red)
            ->getJson("/api/v1/matches/{$this->match->id}/chat?limit=100")
            ->assertOk();

        $this->assertLessThanOrEqual(config('chat.history_max', 50), count($res->json('data')));
        $this->assertTrue($res->json('meta.has_more'));
    }

    public function test_empty_or_whitespace_message_is_rejected(): void
    {
        $this->actingAs($this->red)
            ->postJson("/api/v1/matches/{$this->match->id}/chat", ['body' => "   \n\t "])
            ->assertStatus(422);
    }

    public function test_oversized_message_is_rejected(): void
    {
        $long = str_repeat('a', (int) config('chat.max_length', 200) + 50);
        $this->actingAs($this->red)
            ->postJson("/api/v1/matches/{$this->match->id}/chat", ['body' => $long])
            ->assertStatus(422);
    }

    public function test_unicode_content_is_preserved(): void
    {
        $unicode = 'নমস্কার 你好 こんにちは 🎉❤️ café';
        $this->actingAs($this->red)
            ->postJson("/api/v1/matches/{$this->match->id}/chat", ['body' => $unicode])
            ->assertOk()
            ->assertJsonPath('data.body', $unicode);

        $this->assertDatabaseHas('match_messages', ['body' => $unicode]);
    }

    public function test_control_characters_are_stripped_but_text_kept(): void
    {
        $this->actingAs($this->red)
            ->postJson("/api/v1/matches/{$this->match->id}/chat", ['body' => "he\x00l\x07lo"])
            ->assertOk()
            ->assertJsonPath('data.body', 'hello');
    }

    public function test_chat_rate_limit_is_enforced(): void
    {
        RateLimiter::for('chat', fn () => \Illuminate\Cache\RateLimiting\Limit::perMinute(1)->by('test'));

        $url = "/api/v1/matches/{$this->match->id}/chat";
        $this->actingAs($this->red)->postJson($url, ['body' => 'one'])->assertOk();
        $this->actingAs($this->red)->postJson($url, ['body' => 'two'])->assertStatus(429);
    }

    public function test_cross_match_message_access_is_blocked(): void
    {
        // A second match the red player is NOT part of.
        $x = User::factory()->create();
        $y = User::factory()->create();
        $other = $this->startMatch($x, $y);

        $this->actingAs($this->red)
            ->postJson("/api/v1/matches/{$other->id}/chat", ['body' => 'leak?'])
            ->assertForbidden();
        $this->actingAs($this->red)
            ->getJson("/api/v1/matches/{$other->id}/chat")
            ->assertForbidden();
    }

    public function test_all_login_types_follow_the_same_chat_authorization(): void
    {
        // Guest + registered (a Facebook/Google user is a non-guest User too):
        // both are authorized purely by their seat. Guests additionally may only
        // send approved quick-phrases — a content rule, not an auth-type one.
        $guest = User::factory()->guest()->create();
        $registered = User::factory()->create();
        $match = $this->startMatch($guest, $registered);

        // Registered: free text accepted.
        $this->actingAs($registered)
            ->postJson("/api/v1/matches/{$match->id}/chat", ['body' => 'free text ok'])
            ->assertOk();

        // Guest: a quick-phrase is accepted, arbitrary free text is not.
        $phrase = config('chat.quick_phrases')[0];
        $this->actingAs($guest)
            ->postJson("/api/v1/matches/{$match->id}/chat", ['body' => $phrase])
            ->assertOk();
        $this->actingAs($guest)
            ->postJson("/api/v1/matches/{$match->id}/chat", ['body' => 'arbitrary'])
            ->assertStatus(422);

        // Both can read history for their own match.
        $this->actingAs($guest)->getJson("/api/v1/matches/{$match->id}/chat")->assertOk();
        $this->actingAs($registered)->getJson("/api/v1/matches/{$match->id}/chat")->assertOk();
    }

    /* ----------------------------------------------------------------- emoji */

    public function test_member_can_send_an_approved_emoji_with_stable_id(): void
    {
        $emoji = config('chat.allowed_emojis')[0];
        $this->actingAs($this->red)
            ->postJson("/api/v1/matches/{$this->match->id}/emoji", ['emoji' => $emoji])
            ->assertOk()
            ->assertJsonPath('data.emoji', $emoji)
            ->assertJsonStructure(['data' => ['id', 'emoji']]);

        Event::assertDispatched(EmojiReactionSent::class, function (EmojiReactionSent $e) {
            return $e->name === 'Red Player' && $e->id !== '';
        });
    }

    public function test_invalid_emoji_is_rejected(): void
    {
        $this->actingAs($this->red)
            ->postJson("/api/v1/matches/{$this->match->id}/emoji", ['emoji' => '<script>'])
            ->assertStatus(422);
        Event::assertNotDispatched(EmojiReactionSent::class);
    }

    public function test_non_member_cannot_send_emoji(): void
    {
        $stranger = User::factory()->create();
        $this->actingAs($stranger)
            ->postJson("/api/v1/matches/{$this->match->id}/emoji", ['emoji' => config('chat.allowed_emojis')[0]])
            ->assertForbidden();
    }

    public function test_emoji_rate_limit_is_enforced(): void
    {
        RateLimiter::for('emoji', fn () => \Illuminate\Cache\RateLimiting\Limit::perMinute(1)->by('test'));

        $emoji = config('chat.allowed_emojis')[0];
        $url = "/api/v1/matches/{$this->match->id}/emoji";
        $this->actingAs($this->red)->postJson($url, ['emoji' => $emoji])->assertOk();
        $this->actingAs($this->red)->postJson($url, ['emoji' => $emoji])->assertStatus(429);
    }

    public function test_cross_match_emoji_is_blocked(): void
    {
        $x = User::factory()->create();
        $y = User::factory()->create();
        $other = $this->startMatch($x, $y);

        $this->actingAs($this->red)
            ->postJson("/api/v1/matches/{$other->id}/emoji", ['emoji' => config('chat.allowed_emojis')[0]])
            ->assertForbidden();
    }
}
