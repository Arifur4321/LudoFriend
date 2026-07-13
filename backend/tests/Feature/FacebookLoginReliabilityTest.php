<?php

namespace Tests\Feature;

use App\Models\SocialAccount;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

/**
 * Reliability contract for POST /auth/facebook and the session lifecycle:
 *
 *   - an invalid/expired Facebook token is a clean 422 (never a 500),
 *   - a Graph API outage/timeout is a clean 422 (never a 500),
 *   - the same Facebook account never creates a second user,
 *   - the issued Sanctum token authenticates GET /me (session restore),
 *   - logout revokes it (restore must fail with 401 afterwards).
 */
class FacebookLoginReliabilityTest extends TestCase
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

    private function fakeValidGraph(string $fbId = '90001'): void
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

    public function test_successful_login_issues_a_working_session_token(): void
    {
        $this->fakeValidGraph();

        $login = $this->postJson('/api/v1/auth/facebook', ['access_token' => 'valid'])
            ->assertOk()
            ->json();

        $this->assertNotEmpty($login['token']);

        // Exactly what the app does at startup: validate the stored token.
        $this->getJson('/api/v1/me', ['Authorization' => "Bearer {$login['token']}"])
            ->assertOk()
            ->assertJsonPath('data.name', 'FB Player')
            ->assertJsonPath('data.is_guest', false);
    }

    public function test_expired_or_invalid_facebook_token_is_a_clean_422(): void
    {
        Http::fake([
            'https://graph.facebook.com/*/debug_token*' => Http::response([
                'data' => ['is_valid' => false],
            ]),
        ]);

        $this->postJson('/api/v1/auth/facebook', ['access_token' => 'expired'])
            ->assertStatus(422);

        $this->assertSame(0, User::count(), 'no user shell may be created');
    }

    public function test_token_for_a_different_app_is_rejected(): void
    {
        Http::fake([
            'https://graph.facebook.com/*/debug_token*' => Http::response([
                'data' => ['is_valid' => true, 'app_id' => '999'],
            ]),
        ]);

        $this->postJson('/api/v1/auth/facebook', ['access_token' => 'foreign'])
            ->assertStatus(422);
    }

    public function test_graph_api_outage_is_a_clean_422_not_a_500(): void
    {
        Http::fake(function () {
            throw new ConnectionException('Connection timed out');
        });

        $this->postJson('/api/v1/auth/facebook', ['access_token' => 'whatever'])
            ->assertStatus(422);
    }

    public function test_the_same_facebook_account_never_creates_a_duplicate_user(): void
    {
        $this->fakeValidGraph('90007');

        $first = $this->postJson('/api/v1/auth/facebook', ['access_token' => 't1'])
            ->assertOk()->json();
        $second = $this->postJson('/api/v1/auth/facebook', ['access_token' => 't2'])
            ->assertOk()->json();

        $this->assertSame($first['user']['id'], $second['user']['id']);
        $this->assertSame(1, User::count());
        $this->assertSame(1, SocialAccount::where('provider', 'facebook')
            ->where('provider_user_id', '90007')->count());
    }

    public function test_logout_revokes_the_token_so_restore_returns_401(): void
    {
        $this->fakeValidGraph('90008');

        $token = $this->postJson('/api/v1/auth/facebook', ['access_token' => 'ok'])
            ->json('token');

        $this->postJson('/api/v1/auth/logout', [], [
            'Authorization' => "Bearer {$token}",
        ])->assertOk();

        // App relaunch after logout: the stored token must be rejected so the
        // client clears it and shows the login screen.
        $this->getJson('/api/v1/me', ['Authorization' => "Bearer {$token}"])
            ->assertUnauthorized();
    }

    public function test_me_without_any_token_is_unauthorized(): void
    {
        $this->getJson('/api/v1/me')->assertUnauthorized();
    }
}
