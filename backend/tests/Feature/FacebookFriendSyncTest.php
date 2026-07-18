<?php

namespace Tests\Feature;

use App\Models\FriendLink;
use App\Models\SocialAccount;
use App\Models\User;
use App\Services\FacebookService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Log\Events\MessageLogged;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

/**
 * Contract for the Facebook friend-sync fix:
 *
 *   - a Facebook login always refreshes the stored (encrypted) access token,
 *   - GET /friends/facebook never returns a 500 for a corrupt/undecryptable
 *     token — it returns 200 + {data:[], meta:{reauth_required:true}},
 *   - a missing token / declined permission returns an empty list safely,
 *   - syncing repeatedly never duplicates FriendLink rows,
 *   - the raw access token never appears in a response body or the logs.
 */
class FacebookFriendSyncTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        config([
            'app.url' => 'https://api.example.test',
            'services.facebook.app_id' => '123',
            'services.facebook.app_secret' => 'secret',
        ]);
        Storage::fake('public');
    }

    /** Fake a valid Graph login for the given Facebook id. */
    private function fakeGraph(string $fbId): void
    {
        Http::fake([
            'https://lookaside.fbsbx.com/*' => Http::response(
                'fake-jpeg-bytes',
                200,
                ['Content-Type' => 'image/jpeg'],
            ),
            'https://graph.facebook.com/*/debug_token*' => Http::response([
                'data' => ['is_valid' => true, 'app_id' => '123'],
            ]),
            'https://graph.facebook.com/*/me*' => Http::response([
                'id' => $fbId,
                'name' => 'FB Player',
                'email' => "fb{$fbId}@example.com",
                'picture' => ['data' => [
                    'url' => 'https://lookaside.fbsbx.com/platform/profilepic/x',
                    'is_silhouette' => false,
                ]],
            ]),
        ]);
    }

    public function test_existing_facebook_account_receives_the_newest_access_token(): void
    {
        $user = User::factory()->create();
        SocialAccount::create([
            'user_id' => $user->id,
            'provider' => 'facebook',
            'provider_user_id' => '55501',
            'access_token' => 'stale-old-token',
        ]);

        $this->fakeGraph('55501');

        $this->postJson('/api/v1/auth/facebook', [
            'access_token' => 'newest-token-abc',
        ])->assertOk();

        // Exactly one linked row, and it now decrypts to the newest token.
        $this->assertSame(1, SocialAccount::where('provider', 'facebook')
            ->where('provider_user_id', '55501')->count());

        $fresh = SocialAccount::where('provider_user_id', '55501')->first();
        $this->assertSame('newest-token-abc', $fresh->access_token);
    }

    public function test_corrupt_encrypted_token_does_not_produce_a_500(): void
    {
        $user = User::factory()->create();
        $social = SocialAccount::create([
            'user_id' => $user->id,
            'provider' => 'facebook',
            'provider_user_id' => '55502',
            'access_token' => 'readable-token',
        ]);

        // Simulate a token encrypted under a rotated APP_KEY by writing an
        // undecryptable value straight to the column (bypassing the cast).
        DB::table('social_accounts')->where('id', $social->id)
            ->update(['access_token' => 'not-a-valid-encrypted-payload']);

        $this->actingAs($user)
            ->getJson('/api/v1/friends/facebook')
            ->assertOk()
            ->assertJsonPath('data', [])
            ->assertJsonPath('meta.reauth_required', true);
    }

    public function test_missing_token_or_no_link_returns_reauth_required_safely(): void
    {
        // No linked Facebook account at all.
        $noLink = User::factory()->create();
        $this->actingAs($noLink)
            ->getJson('/api/v1/friends/facebook')
            ->assertOk()
            ->assertJsonPath('data', [])
            ->assertJsonPath('meta.reauth_required', true);

        // Linked, but the token column is null (e.g. cleared after corruption).
        $nullToken = User::factory()->create();
        SocialAccount::create([
            'user_id' => $nullToken->id,
            'provider' => 'facebook',
            'provider_user_id' => '55503',
        ]);
        $this->actingAs($nullToken)
            ->getJson('/api/v1/friends/facebook')
            ->assertOk()
            ->assertJsonPath('data', [])
            ->assertJsonPath('meta.reauth_required', true);
    }

    public function test_declined_permission_returns_an_empty_list_safely(): void
    {
        $user = User::factory()->create();
        SocialAccount::create([
            'user_id' => $user->id,
            'provider' => 'facebook',
            'provider_user_id' => '55504',
            'access_token' => 'readable-token',
        ]);

        // user_friends not granted (or no app-friends): Graph yields nothing.
        $this->mock(FacebookService::class, function ($mock) {
            $mock->shouldReceive('appFriends')->andReturn([]);
        });

        // Readable token + empty friends → a plain empty list, no reauth flag.
        $this->actingAs($user)
            ->getJson('/api/v1/friends/facebook')
            ->assertOk()
            ->assertExactJson(['data' => []]);
    }

    public function test_repeated_sync_does_not_duplicate_friend_links(): void
    {
        $me = User::factory()->create();
        SocialAccount::create([
            'user_id' => $me->id,
            'provider' => 'facebook',
            'provider_user_id' => 'ME_FB',
            'access_token' => 'readable-token',
        ]);

        $friend = User::factory()->create();
        SocialAccount::create([
            'user_id' => $friend->id,
            'provider' => 'facebook',
            'provider_user_id' => 'FRIEND_FB',
            'access_token' => 'friend-token',
        ]);

        $this->mock(FacebookService::class, function ($mock) {
            $mock->shouldReceive('appFriends')->andReturn([
                ['id' => 'FRIEND_FB', 'name' => 'Friend', 'avatar' => null],
            ]);
        });

        // Sync twice — the second call must not create a second link row.
        $this->actingAs($me)->getJson('/api/v1/friends/facebook')
            ->assertOk()->assertJsonCount(1, 'data');
        $this->actingAs($me)->getJson('/api/v1/friends/facebook')
            ->assertOk()->assertJsonCount(1, 'data');

        $this->assertSame(1, FriendLink::where('user_id', $me->id)
            ->where('friend_user_id', $friend->id)->count());
        $this->assertSame(1, FriendLink::where('user_id', $friend->id)
            ->where('friend_user_id', $me->id)->count());
        $this->assertSame(2, FriendLink::count());
    }

    public function test_no_access_token_appears_in_logs_or_responses(): void
    {
        $user = User::factory()->create();
        SocialAccount::create([
            'user_id' => $user->id,
            'provider' => 'facebook',
            'provider_user_id' => '55505',
            'access_token' => 'stale-old-token',
        ]);

        $this->fakeGraph('55505');

        $captured = [];
        Event::listen(MessageLogged::class, function (MessageLogged $e) use (&$captured) {
            $captured[] = $e->message.' '.json_encode($e->context);
        });

        $secret = 'super-secret-fb-token-9999';

        $login = $this->postJson('/api/v1/auth/facebook', [
            'access_token' => $secret,
        ])->assertOk();

        // The raw Facebook token must never be echoed back to the client...
        $this->assertStringNotContainsString($secret, $login->getContent());

        // ...nor written to the application logs.
        foreach ($captured as $line) {
            $this->assertStringNotContainsString($secret, $line);
        }

        // And the model hides it from any serialization.
        $this->assertArrayNotHasKey(
            'access_token',
            SocialAccount::where('provider_user_id', '55505')->first()->toArray(),
        );
    }
}
