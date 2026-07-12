<?php

use App\Http\Controllers\Api\AccountController;
use App\Http\Controllers\Api\AdminController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\BoardController;
use App\Http\Controllers\Api\ChatController;
use App\Http\Controllers\Api\FriendController;
use App\Http\Controllers\Api\GameController;
use App\Http\Controllers\Api\LeaderboardController;
use App\Http\Controllers\Api\MatchmakingController;
use App\Http\Controllers\Api\PresenceController;
use App\Http\Controllers\Api\ProfileController;
use App\Http\Controllers\Api\ReportController;
use App\Http\Controllers\Api\RoomController;
use App\Http\Controllers\Api\SpinController;
use App\Http\Controllers\Api\StoreController;
use App\Http\Controllers\Api\WalletController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| API Routes (versioned: /api/v1)
|--------------------------------------------------------------------------
|
| Laravel automatically prefixes this file with "/api", so the group below
| yields paths like /api/v1/auth/login. Throttle middleware:
|   - auth (login/register/guest/facebook): throttle:6,1  (RATE_LIMIT_AUTH)
|   - game actions + room join + matchmaking: throttle:30,1 (RATE_LIMIT_GAME)
|   - everything else authenticated:          throttle:60,1 (RATE_LIMIT_API)
|
*/

Route::prefix('v1')->group(function () {

    /* ---------------------------------------------------------------
     | Public auth (tight rate limit to deter brute force)
     | --------------------------------------------------------------- */
    Route::prefix('auth')->middleware('throttle:6,1')->group(function () {
        Route::post('register', [AuthController::class, 'register']);
        Route::post('login', [AuthController::class, 'login']);
        Route::post('guest', [AuthController::class, 'guest']);
        Route::post('facebook', [AuthController::class, 'facebook']);
        Route::post('google', [AuthController::class, 'google']);
    });

    /* ---------------------------------------------------------------
     | Authenticated, non-banned
     | --------------------------------------------------------------- */
    Route::middleware(['auth:sanctum', 'banned'])->group(function () {

        // Session
        Route::post('auth/logout', [AuthController::class, 'logout']);
        Route::get('me', [AuthController::class, 'me']);

        // Account deletion request (GDPR / Google Play "Delete account").
        // Non-destructive: records a pending request for manual/async
        // processing — see AccountController. Tight rate limit.
        Route::post('account/delete-request', [AccountController::class, 'deleteRequest'])
            ->middleware('throttle:6,1');

        // Profile (default api throttle)
        Route::middleware('throttle:60,1')->group(function () {
            Route::get('profile', [ProfileController::class, 'show']);
            Route::put('profile', [ProfileController::class, 'update']);
            Route::get('profile/stats', [ProfileController::class, 'stats']);
            Route::get('profile/matches', [ProfileController::class, 'matchHistory']);

            // Friends
            Route::get('friends', [FriendController::class, 'index']);
            Route::get('friends/facebook', [FriendController::class, 'facebook']);
            Route::post('friends/invite', [FriendController::class, 'invite']);
            Route::post('friends/accept', [FriendController::class, 'acceptByCode']);

            // Presence heartbeat (drives friends' online status).
            Route::post('presence/ping', [PresenceController::class, 'ping']);

            // Leaderboard
            Route::get('leaderboard', [LeaderboardController::class, 'index']);

            // Reports
            Route::post('reports', [ReportController::class, 'store']);

            // Economy — wallet, staked boards, coin store, spin availability.
            Route::get('wallet', [WalletController::class, 'show']);
            Route::get('wallet/transactions', [WalletController::class, 'transactions']);
            Route::get('boards', [BoardController::class, 'index']);
            Route::get('store/packs', [StoreController::class, 'packs']);
            Route::get('spin/status', [SpinController::class, 'status']);
        });

        // Economy mutations (tighter game-rate limit).
        Route::middleware('throttle:30,1')->group(function () {
            Route::post('spin', [SpinController::class, 'spin']);
            Route::post('store/purchase', [StoreController::class, 'purchase']);
        });

        // Rooms — creation/show at api rate; join at game rate.
        Route::middleware('throttle:60,1')->group(function () {
            Route::post('rooms', [RoomController::class, 'create']);
            // Preview a private room by code before joining (read-only, no seat).
            // Declared before the {room} id route so it never binds as an id.
            Route::get('rooms/lookup/{code}', [RoomController::class, 'lookup'])
                ->where('code', '[A-Za-z0-9]{4,8}');
            Route::get('rooms/{room}', [RoomController::class, 'show']);
            Route::post('rooms/{room}/leave', [RoomController::class, 'leave']);
            Route::post('rooms/{room}/ready', [RoomController::class, 'ready']);
            Route::post('rooms/{room}/start', [RoomController::class, 'start']);
        });

        Route::middleware('throttle:30,1')->group(function () {
            Route::post('rooms/join', [RoomController::class, 'join']);

            // Matchmaking
            Route::post('matchmaking/enqueue', [MatchmakingController::class, 'enqueue']);
            Route::post('matchmaking/cancel', [MatchmakingController::class, 'cancel']);
            Route::get('matchmaking/status', [MatchmakingController::class, 'status']);

            // In-match actions (server-authoritative)
            Route::post('matches/{match}/roll', [GameController::class, 'roll']);
            Route::post('matches/{match}/move', [GameController::class, 'move']);

            // In-match chat + emoji reactions.
            Route::post('matches/{match}/chat', [ChatController::class, 'message']);
            Route::post('matches/{match}/emoji', [ChatController::class, 'emoji']);

            // Friend "come play" room invite.
            Route::post('friends/invite-to-room', [FriendController::class, 'inviteToRoom']);
        });

        // Read-only match synchronization has its own allowance because every
        // active client periodically verifies authoritative state as a safety
        // net for missed realtime events. Mutating roll/move calls remain on
        // the tighter game-action limiter above.
        Route::middleware('throttle:120,1')->group(function () {
            Route::get('matches/{match}/state', [GameController::class, 'state']);
            Route::post('matches/{match}/reconnect', [GameController::class, 'reconnect']);
        });

        /* -----------------------------------------------------------
         | Admin-only back office
         | ----------------------------------------------------------- */
        Route::prefix('admin')->middleware('admin')->group(function () {
            Route::get('users', [AdminController::class, 'users']);
            Route::get('matches', [AdminController::class, 'matches']);
            Route::get('reports', [AdminController::class, 'reports']);
            Route::post('users/{user}/ban', [AdminController::class, 'banUser']);
            Route::post('users/{user}/unban', [AdminController::class, 'unbanUser']);
        });
    });
});
