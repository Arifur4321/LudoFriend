<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;
use RuntimeException;

/**
 * GoogleService — verifies a Google Sign-In ID token and returns the basic
 * profile, mirroring FacebookService's shape so AuthController can treat both
 * providers uniformly.
 *
 * Verification uses Google's tokeninfo endpoint (simple and dependency-free).
 * For very high volume you would instead cache Google's JWKS and verify the
 * RS256 signature locally; tokeninfo is correct and sufficient here. The
 * feature stays inert until GOOGLE_LOGIN_ENABLED=true and a client id is set.
 *
 * @phpstan-type GoogleProfile array{id:string,name:?string,email:?string,avatar:?string}
 */
class GoogleService
{
    public function enabled(): bool
    {
        return (bool) config('economy.social.google.enabled', false);
    }

    /**
     * @return array{id:string,name:?string,email:?string,avatar:?string}
     *
     * @throws RuntimeException on a disabled feature or invalid token.
     */
    public function verifyIdToken(string $idToken): array
    {
        if (! $this->enabled()) {
            throw new RuntimeException('Google sign-in is not enabled.');
        }

        $clientIds = array_filter((array) config('economy.social.google.client_ids', []));
        if (empty($clientIds)) {
            throw new RuntimeException('Google client id is not configured.');
        }

        $response = Http::get('https://oauth2.googleapis.com/tokeninfo', [
            'id_token' => $idToken,
        ]);

        if ($response->failed()) {
            throw new RuntimeException('Invalid Google ID token.');
        }

        $data = $response->json();

        // Audience must be one of our configured OAuth client ids.
        if (! in_array($data['aud'] ?? null, $clientIds, true)) {
            throw new RuntimeException('Google token was issued for a different app.');
        }

        // Issuer must be Google.
        $iss = $data['iss'] ?? '';
        if (! in_array($iss, ['accounts.google.com', 'https://accounts.google.com'], true)) {
            throw new RuntimeException('Untrusted Google token issuer.');
        }

        if (empty($data['sub'])) {
            throw new RuntimeException('Google token missing subject.');
        }

        return [
            'id' => (string) $data['sub'],
            'name' => $data['name'] ?? ($data['email'] ?? 'Player'),
            'email' => $data['email'] ?? null,
            'avatar' => $data['picture'] ?? null,
        ];
    }
}
