<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;
use RuntimeException;

/**
 * FacebookService — thin wrapper over the Facebook Graph API for login and the
 * "friends using this app" feature. It verifies an access token, fetches the
 * basic profile, and lists app-using friends. When the friends permission is
 * unavailable (most common case post-platform-changes), callers gracefully
 * fall back to invite links / room codes / deep links — this class simply
 * returns an empty friend list rather than throwing.
 */
class FacebookService
{
    private string $graphUrl;
    private string $version;

    public function __construct()
    {
        $this->graphUrl = rtrim(config('services.facebook.graph_url'), '/');
        $this->version = config('services.facebook.graph_version', 'v19.0');
    }

    /**
     * Verify a user access token against the configured app and return the
     * basic profile. Throws if the token is invalid or for the wrong app.
     *
     * @return array{id:string,name:?string,email:?string,avatar:?string}
     *
     * @throws RuntimeException on invalid token.
     */
    public function verifyAndFetchProfile(string $accessToken): array
    {
        $this->assertTokenAppMatches($accessToken);

        $response = Http::baseUrl($this->graphUrl)
            ->get("/{$this->version}/me", [
                'fields' => 'id,name,email,picture.type(large)',
                'access_token' => $accessToken,
            ]);

        if ($response->failed()) {
            throw new RuntimeException('Failed to fetch Facebook profile.');
        }

        $data = $response->json();

        return [
            'id' => (string) ($data['id'] ?? ''),
            'name' => $data['name'] ?? null,
            'email' => $data['email'] ?? null,
            'avatar' => data_get($data, 'picture.data.url'),
        ];
    }

    /**
     * List the user's friends who also use this app. Requires the
     * `user_friends` permission; if it is missing or the call fails, returns an
     * empty array so the caller can fall back to invite link / code / deep link.
     *
     * @return array<int,array{id:string,name:?string,avatar:?string}>
     */
    public function appFriends(string $accessToken): array
    {
        try {
            $response = Http::baseUrl($this->graphUrl)
                ->get("/{$this->version}/me/friends", [
                    'fields' => 'id,name,picture.type(normal)',
                    'access_token' => $accessToken,
                ]);

            if ($response->failed()) {
                return [];
            }

            return collect($response->json('data', []))
                ->map(fn ($f) => [
                    'id' => (string) ($f['id'] ?? ''),
                    'name' => $f['name'] ?? null,
                    'avatar' => data_get($f, 'picture.data.url'),
                ])
                ->all();
        } catch (\Throwable) {
            // Graceful fallback — no friends surfaced; client uses code/link.
            return [];
        }
    }

    /**
     * Validate that the token belongs to our app and is still valid using the
     * Graph debug_token endpoint and an app access token.
     *
     * @throws RuntimeException when the token is invalid or app-mismatched.
     */
    private function assertTokenAppMatches(string $accessToken): void
    {
        $appId = config('services.facebook.app_id');
        $appSecret = config('services.facebook.app_secret');

        if (empty($appId) || empty($appSecret)) {
            throw new RuntimeException('Facebook app credentials are not configured.');
        }

        $response = Http::baseUrl($this->graphUrl)
            ->get("/{$this->version}/debug_token", [
                'input_token' => $accessToken,
                'access_token' => "{$appId}|{$appSecret}",
            ]);

        $data = $response->json('data', []);

        if (($data['is_valid'] ?? false) !== true) {
            throw new RuntimeException('Invalid Facebook access token.');
        }

        if ((string) ($data['app_id'] ?? '') !== (string) $appId) {
            throw new RuntimeException('Facebook token does not belong to this application.');
        }
    }
}
