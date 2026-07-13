<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\FacebookLoginRequest;
use App\Http\Requests\GoogleLoginRequest;
use App\Http\Requests\GuestRequest;
use App\Http\Requests\LoginRequest;
use App\Http\Requests\RegisterRequest;
use App\Http\Resources\UserResource;
use App\Models\GuestSession;
use App\Models\PlayerProfile;
use App\Models\SocialAccount;
use App\Models\User;
use App\Services\Economy\WalletService;
use App\Services\FacebookService;
use App\Services\GoogleService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

class AuthController extends Controller
{
    public function __construct(
        private readonly FacebookService $facebook,
        private readonly GoogleService $google,
        private readonly WalletService $wallet,
    ) {
    }

    /**
     * Register a full account. Issues a Sanctum token.
     */
    public function register(RegisterRequest $request): JsonResponse
    {
        $user = DB::transaction(function () use ($request) {
            $user = User::create([
                'name' => $request->string('name'),
                'email' => $request->string('email'),
                'password' => Hash::make($request->string('password')),
                'avatar' => $request->input('avatar'),
                'is_guest' => false,
            ]);

            $this->ensureProfile($user);

            return $user;
        });

        return $this->tokenResponse($user, 'register', 201);
    }

    /**
     * Email/password login. Issues a Sanctum token.
     */
    public function login(LoginRequest $request): JsonResponse
    {
        $user = User::where('email', $request->string('email'))->first();

        if (! $user || ! $user->password || ! Hash::check($request->string('password'), $user->password)) {
            throw ValidationException::withMessages([
                'email' => ['These credentials do not match our records.'],
            ]);
        }

        if ($user->is_banned) {
            throw ValidationException::withMessages([
                'email' => ['This account has been banned.'],
            ]);
        }

        return $this->tokenResponse($user, $request->input('device_name', 'api'));
    }

    /**
     * Guest sign-in: re-use the same guest for a known device, otherwise mint a
     * fresh guest user + session. Issues a Sanctum token.
     */
    public function guest(GuestRequest $request): JsonResponse
    {
        $deviceId = $request->string('device_id');

        $user = DB::transaction(function () use ($request, $deviceId) {
            $session = GuestSession::where('device_id', $deviceId)->first();

            if ($session && $session->user) {
                $session->update(['last_seen_at' => now()]);

                return $session->user;
            }

            $user = User::create([
                'name' => $request->input('guest_name') ?: 'Guest-'.Str::upper(Str::random(5)),
                'avatar' => $request->input('avatar'),
                'is_guest' => true,
            ]);

            GuestSession::create([
                'user_id' => $user->id,
                'device_id' => $deviceId,
                'guest_name' => $user->name,
                'token' => Str::random(64),
                'last_seen_at' => now(),
            ]);

            $this->ensureProfile($user, $user->name);

            return $user;
        });

        return $this->tokenResponse($user, 'guest:'.$deviceId);
    }

    /**
     * Facebook login: verify the token, fetch the profile, link/create a user.
     *
     * Graph API failures (expired/invalid token, wrong app, network timeout)
     * surface as a clean 422 with a human-readable message — never a 500 —
     * so the app can show "session expired, try again" instead of a generic
     * error. The Facebook App Secret only ever lives in server config; it is
     * never logged or echoed back.
     */
    public function facebook(FacebookLoginRequest $request): JsonResponse
    {
        try {
            $profile = $this->facebook->verifyAndFetchProfile($request->string('access_token'));
        } catch (\Throwable $e) {
            throw ValidationException::withMessages([
                'access_token' => ['Facebook sign-in could not be verified. Please try again.'],
            ]);
        }

        if (empty($profile['id'])) {
            throw ValidationException::withMessages([
                'access_token' => ['Unable to resolve Facebook profile.'],
            ]);
        }

        $user = DB::transaction(function () use ($profile, $request) {
            $social = SocialAccount::where('provider', 'facebook')
                ->where('provider_user_id', $profile['id'])
                ->first();

            if ($social) {
                $user = $social->user;

                // Keep the linked social row's stored photo current.
                if (! empty($profile['avatar'])) {
                    $social->update(['avatar_url' => $profile['avatar']]);
                }
            } else {
                // Link to an existing email account if one exists, else create.
                $user = ($profile['email'] ? User::where('email', $profile['email'])->first() : null)
                    ?? User::create([
                        'name' => $profile['name'] ?? 'Player',
                        'email' => $profile['email'],
                        'avatar' => $profile['avatar'],
                        'is_guest' => false,
                    ]);

                // Two simultaneous first-logins for the same Facebook account
                // can race past the SELECT above. unique(provider,
                // provider_user_id) makes the second INSERT fail; recover by
                // re-reading the winner's row so exactly ONE user exists per
                // Facebook identity and both requests succeed.
                try {
                    SocialAccount::create([
                        'user_id' => $user->id,
                        'provider' => 'facebook',
                        'provider_user_id' => $profile['id'],
                        'avatar_url' => $profile['avatar'],
                        'access_token' => $request->string('access_token'),
                    ]);
                } catch (\Illuminate\Database\QueryException $e) {
                    $existing = SocialAccount::where('provider', 'facebook')
                        ->where('provider_user_id', $profile['id'])
                        ->first();
                    if (! $existing) {
                        throw $e;
                    }
                    if ($user->wasRecentlyCreated && $existing->user_id !== $user->id) {
                        $user->delete(); // discard the just-created duplicate shell
                    }
                    $user = $existing->user;
                }
            }

            // Refresh the account photo so returning users pick up the current
            // (and now stable) Facebook picture on the profile screen.
            if (! empty($profile['avatar']) && $user->avatar !== $profile['avatar']) {
                $user->update(['avatar' => $profile['avatar']]);
            }

            $this->ensureProfile($user, $profile['name'] ?? null, $profile['avatar'] ?? null);

            // Mirror the latest photo onto the player profile too.
            if (! empty($profile['avatar'])) {
                $user->profile()->update(['avatar' => $profile['avatar']]);
            }

            return $user;
        });

        return $this->tokenResponse($user, $request->input('device_name', 'facebook'));
    }

    /**
     * Google login: verify the ID token, fetch the profile, link/create a user.
     */
    public function google(GoogleLoginRequest $request): JsonResponse
    {
        try {
            $profile = $this->google->verifyIdToken($request->string('id_token'));
        } catch (\Throwable $e) {
            throw ValidationException::withMessages([
                'id_token' => ['Google sign-in could not be verified. Please try again.'],
            ]);
        }

        if (empty($profile['id'])) {
            throw ValidationException::withMessages([
                'id_token' => ['Unable to resolve Google profile.'],
            ]);
        }

        $user = DB::transaction(function () use ($profile) {
            $social = SocialAccount::where('provider', 'google')
                ->where('provider_user_id', $profile['id'])
                ->first();

            if ($social) {
                $user = $social->user;
            } else {
                // Link to an existing email account if one exists, else create.
                $user = ($profile['email'] ? User::where('email', $profile['email'])->first() : null)
                    ?? User::create([
                        'name' => $profile['name'] ?? 'Player',
                        'email' => $profile['email'],
                        'avatar' => $profile['avatar'],
                        'is_guest' => false,
                    ]);

                SocialAccount::create([
                    'user_id' => $user->id,
                    'provider' => 'google',
                    'provider_user_id' => $profile['id'],
                    'avatar_url' => $profile['avatar'],
                ]);
            }

            $this->ensureProfile($user, $profile['name'] ?? null, $profile['avatar'] ?? null);

            return $user;
        });

        return $this->tokenResponse($user, 'google');
    }

    /**
     * Revoke the current access token.
     */
    public function logout(Request $request): JsonResponse
    {
        $request->user()->currentAccessToken()->delete();

        return response()->json(['message' => 'Logged out.']);
    }

    /**
     * Return the authenticated user.
     */
    public function me(Request $request): UserResource
    {
        return new UserResource($request->user()->load('profile'));
    }

    /* =====================================================================
     | Helpers
     | ===================================================================== */

    private function ensureProfile(User $user, ?string $displayName = null, ?string $avatar = null): void
    {
        $profile = PlayerProfile::firstOrCreate(
            ['user_id' => $user->id],
            [
                'display_name' => $displayName ?? $user->name,
                'avatar' => $avatar ?? $user->avatar,
                'coins' => 0, // seeded below through the ledger
            ]
        );

        // Seed the starting balance once, as an auditable ledger entry, only for
        // freshly created profiles (idempotent guard inside the service too).
        if ($profile->wasRecentlyCreated) {
            $this->wallet->grantSignupBonus($user);
        }
    }

    private function tokenResponse(User $user, string $deviceName, int $status = 200): JsonResponse
    {
        $token = $user->createToken($deviceName)->plainTextToken;

        return response()->json([
            'token' => $token,
            'token_type' => 'Bearer',
            'user' => new UserResource($user->load('profile')),
        ], $status);
    }
}
