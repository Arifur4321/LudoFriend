<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Storage;
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
            ->timeout(10)
            ->connectTimeout(5)
            ->get("/{$this->version}/me", [
                'fields' => 'id,name,email,picture.type(large)',
                'access_token' => $accessToken,
            ]);

        if ($response->failed()) {
            throw new RuntimeException('Failed to fetch Facebook profile.');
        }

        $data = $response->json();
        $fbId = (string) ($data['id'] ?? '');

        return [
            'id' => $fbId,
            'name' => $data['name'] ?? null,
            'email' => $data['email'] ?? null,
            'avatar' => $this->persistPicture($fbId, $data),
        ];
    }

    /**
     * Cache Facebook's current profile picture on our public disk.
     *
     * The Graph response's CDN URL is usable immediately but expires, while a
     * bare `/{app-scoped-id}/picture` redirect is not reliable for every client.
     * Serving a local copy gives room and match participants one stable HTTPS
     * URL without exposing any Facebook access token. If storage is temporarily
     * unavailable, fall back to the fresh CDN URL returned by Facebook.
     */
    private function persistPicture(string $fbId, array $data): ?string
    {
        $remoteUrl = data_get($data, 'picture.data.url');
        if ($fbId === '' || ! is_string($remoteUrl) || $remoteUrl === '') {
            return null;
        }

        if ((bool) data_get($data, 'picture.data.is_silhouette', false) === true) {
            return null;
        }

        try {
            $response = Http::timeout(10)->get($remoteUrl);
            if ($response->successful() && $response->body() !== '') {
                $contentType = strtolower((string) $response->header('Content-Type'));
                $extension = str_contains($contentType, 'png')
                    ? 'png'
                    : (str_contains($contentType, 'webp') ? 'webp' : 'jpg');
                $safeId = preg_replace('/[^A-Za-z0-9_-]/', '_', $fbId) ?: hash('sha256', $fbId);
                $path = "avatars/facebook/{$safeId}.{$extension}";

                if (Storage::disk('public')->put($path, $response->body())) {
                    return rtrim((string) config('app.url'), '/').'/storage/'.$path;
                }
            }
        } catch (\Throwable) {
            // The fresh Graph CDN URL below remains a safe best-effort fallback.
        }

        return $remoteUrl;
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
                ->timeout(10)
                ->connectTimeout(5)
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

        // The app access token ("app_id|app_secret") is composed here from
        // server-side config only — it is never logged and never leaves this
        // request. Timeouts keep a slow Graph API from hanging login requests.
        $response = Http::baseUrl($this->graphUrl)
            ->timeout(10)
            ->connectTimeout(5)
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
