<?php

namespace Tests\Feature;

use App\Models\SocialAccount;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

/**
 * Covers the Facebook profile-photo handling: we persist and return a stable,
 * tokenless Graph picture URL (not the short-lived lookaside CDN link), refresh
 * it for returning users, and skip default silhouettes.
 */
class FacebookAvatarTest extends TestCase
{
    use RefreshDatabase;

    private const STABLE = 'https://graph.facebook.com/55501/picture?type=large&width=256&height=256';

    protected function setUp(): void
    {
        parent::setUp();

        config([
            'services.facebook.app_id' => '123',
            'services.facebook.app_secret' => 'secret',
        ]);
    }

    private function fakeGraph(string $fbId, bool $silhouette = false): void
    {
        Http::fake([
            'https://graph.facebook.com/*/debug_token*' => Http::response([
                'data' => ['is_valid' => true, 'app_id' => '123'],
            ]),
            'https://graph.facebook.com/*/me*' => Http::response([
                'id' => $fbId,
                'name' => 'Arifur Rahman Sojib',
                'email' => "fb{$fbId}@example.com",
                'picture' => ['data' => [
                    // Short-lived CDN URL that we intentionally do NOT store.
                    'url' => 'https://lookaside.fbsbx.com/platform/profilepic/expiring',
                    'is_silhouette' => $silhouette,
                ]],
            ]),
        ]);
    }

    public function test_facebook_login_stores_and_returns_a_stable_avatar_url(): void
    {
        $this->fakeGraph('55501');

        $response = $this->postJson('/api/v1/auth/facebook', [
            'access_token' => 'valid-token',
        ]);

        $response->assertOk()
            ->assertJsonPath('user.name', 'Arifur Rahman Sojib')
            ->assertJsonPath('user.avatar', self::STABLE);

        $this->assertDatabaseHas('users', ['avatar' => self::STABLE]);
        $this->assertDatabaseHas('player_profiles', ['avatar' => self::STABLE]);
        $this->assertDatabaseHas('social_accounts', [
            'provider' => 'facebook',
            'provider_user_id' => '55501',
            'avatar_url' => self::STABLE,
        ]);
    }

    public function test_returning_facebook_user_gets_a_previously_broken_avatar_refreshed(): void
    {
        $user = User::factory()->create(['avatar' => 'https://old/broken-lookaside.jpg']);
        SocialAccount::create([
            'user_id' => $user->id,
            'provider' => 'facebook',
            'provider_user_id' => '55501',
            'avatar_url' => 'https://old/broken-lookaside.jpg',
        ]);

        $this->fakeGraph('55501');

        $this->postJson('/api/v1/auth/facebook', ['access_token' => 'valid-token'])
            ->assertOk()
            ->assertJsonPath('user.avatar', self::STABLE);

        $this->assertDatabaseHas('users', ['id' => $user->id, 'avatar' => self::STABLE]);
        $this->assertDatabaseHas('social_accounts', [
            'provider_user_id' => '55501',
            'avatar_url' => self::STABLE,
        ]);
    }

    public function test_default_silhouette_is_not_stored_so_the_app_shows_its_own_avatar(): void
    {
        $this->fakeGraph('55502', silhouette: true);

        $this->postJson('/api/v1/auth/facebook', ['access_token' => 'valid-token'])
            ->assertOk()
            ->assertJsonPath('user.avatar', null);

        $this->assertDatabaseHas('users', ['avatar' => null]);
    }
}
