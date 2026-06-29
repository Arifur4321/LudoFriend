<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\FacebookLoginRequest;
use App\Http\Requests\GuestRequest;
use App\Http\Requests\LoginRequest;
use App\Http\Requests\RegisterRequest;
use App\Http\Resources\UserResource;
use App\Models\GuestSession;
use App\Models\PlayerProfile;
use App\Models\SocialAccount;
use App\Models\User;
use App\Services\FacebookService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

class AuthController extends Controller
{
    public function __construct(private readonly FacebookService $facebook)
    {
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
     */
    public function facebook(FacebookLoginRequest $request): JsonResponse
    {
        $profile = $this->facebook->verifyAndFetchProfile($request->string('access_token'));

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
                    'provider' => 'facebook',
                    'provider_user_id' => $profile['id'],
                    'avatar_url' => $profile['avatar'],
                    'access_token' => $request->string('access_token'),
                ]);
            }

            $this->ensureProfile($user, $profile['name'] ?? null, $profile['avatar'] ?? null);

            return $user;
        });

        return $this->tokenResponse($user, $request->input('device_name', 'facebook'));
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
        PlayerProfile::firstOrCreate(
            ['user_id' => $user->id],
            [
                'display_name' => $displayName ?? $user->name,
                'avatar' => $avatar ?? $user->avatar,
                'coins' => config('ludo.starting_coins'),
            ]
        );
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
