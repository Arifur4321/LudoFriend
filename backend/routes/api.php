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
| yields paths such as /api/v1/auth/login.
|
| Rate-limit groups:
|   - Authentication:                 6 requests/minute
|   - Standard authenticated APIs:   60 requests/minute
|   - Lobby and matchmaking:         30 requests/minute
|   - Active roll/move actions:      120 requests/minute
|   - Match state synchronization:   300 requests/minute
|
| The game lobby, active actions, and state synchronization groups use
| separate limiter prefixes so their counters do not affect each other.
|
*/

Route::prefix('v1')->group(function () {

    /*
    |--------------------------------------------------------------------------
    | Public authentication
    |--------------------------------------------------------------------------
    */

    Route::prefix('auth')
        ->middleware('throttle:6,1')
        ->group(function () {
            Route::post('register', [AuthController::class, 'register']);
            Route::post('login', [AuthController::class, 'login']);
            Route::post('guest', [AuthController::class, 'guest']);
            Route::post('facebook', [AuthController::class, 'facebook']);
            Route::post('google', [AuthController::class, 'google']);
        });

    /*
    |--------------------------------------------------------------------------
    | Authenticated, non-banned users
    |--------------------------------------------------------------------------
    */

    Route::middleware(['auth:sanctum', 'banned'])->group(function () {

        /*
        |--------------------------------------------------------------------------
        | Session and account
        |--------------------------------------------------------------------------
        */

        Route::post('auth/logout', [AuthController::class, 'logout']);
        Route::get('me', [AuthController::class, 'me']);

        Route::post(
            'account/delete-request',
            [AccountController::class, 'deleteRequest']
        )->middleware('throttle:6,1');

        /*
        |--------------------------------------------------------------------------
        | Profile, friends, presence and read-only economy APIs
        |--------------------------------------------------------------------------
        */

        Route::middleware('throttle:60,1')->group(function () {

            // Profile
            Route::get('profile', [ProfileController::class, 'show']);
            Route::put('profile', [ProfileController::class, 'update']);
            Route::get('profile/stats', [ProfileController::class, 'stats']);
            Route::get(
                'profile/matches',
                [ProfileController::class, 'matchHistory']
            );

            // Friends
            Route::get('friends', [FriendController::class, 'index']);
            Route::get('friends/recent', [FriendController::class, 'recent']);
            Route::get(
                'friends/facebook',
                [FriendController::class, 'facebook']
            );
            Route::post('friends/invite', [FriendController::class, 'invite']);
            Route::post(
                'friends/accept',
                [FriendController::class, 'acceptByCode']
            );

            // Presence
            Route::post(
                'presence/ping',
                [PresenceController::class, 'ping']
            );

            // Leaderboard
            Route::get(
                'leaderboard',
                [LeaderboardController::class, 'index']
            );

            // Reports
            Route::post('reports', [ReportController::class, 'store']);

            // Economy
            Route::get('wallet', [WalletController::class, 'show']);
            Route::get(
                'wallet/transactions',
                [WalletController::class, 'transactions']
            );
            Route::get('boards', [BoardController::class, 'index']);
            Route::get('store/packs', [StoreController::class, 'packs']);
            Route::get('spin/status', [SpinController::class, 'status']);
        });

        /*
        |--------------------------------------------------------------------------
        | Economy mutations
        |--------------------------------------------------------------------------
        */

        Route::middleware('throttle:30,1,economy-action-')
            ->group(function () {
                Route::post('spin', [SpinController::class, 'spin']);
                Route::post(
                    'store/purchase',
                    [StoreController::class, 'purchase']
                );
            });

        /*
        |--------------------------------------------------------------------------
        | Rooms
        |--------------------------------------------------------------------------
        */

        Route::middleware('throttle:60,1')->group(function () {
            Route::post('rooms', [RoomController::class, 'create']);

            Route::get(
                'rooms/lookup/{code}',
                [RoomController::class, 'lookup']
            )->where('code', '[A-Za-z0-9]{4,8}');

            Route::get('rooms/{room}', [RoomController::class, 'show']);
            Route::post(
                'rooms/{room}/leave',
                [RoomController::class, 'leave']
            );
            Route::post(
                'rooms/{room}/ready',
                [RoomController::class, 'ready']
            );
            Route::post(
                'rooms/{room}/start',
                [RoomController::class, 'start']
            );
        });

        /*
        |--------------------------------------------------------------------------
        | Lobby, matchmaking and invitations
        |--------------------------------------------------------------------------
        |
        | This group has its own limiter counter. Lobby calls cannot consume
        | the active roll/move allowance.
        |
        */

        Route::middleware('throttle:30,1,game-lobby-')
            ->group(function () {
                Route::post(
                    'rooms/join',
                    [RoomController::class, 'join']
                );

                Route::post(
                    'matchmaking/enqueue',
                    [MatchmakingController::class, 'enqueue']
                );

                Route::post(
                    'matchmaking/cancel',
                    [MatchmakingController::class, 'cancel']
                );

                Route::get(
                    'matchmaking/status',
                    [MatchmakingController::class, 'status']
                );

                Route::post(
                    'friends/invite-to-room',
                    [FriendController::class, 'inviteToRoom']
                );
            });

        /*
        |--------------------------------------------------------------------------
        | Active in-match actions
        |--------------------------------------------------------------------------
        |
        | Roll and move have a dedicated counter. State polling, matchmaking,
        | profile requests and room requests cannot consume this allowance.
        |
        */

        Route::middleware('throttle:120,1,game-action-')
            ->group(function () {
                Route::post(
                    'matches/{match}/roll',
                    [GameController::class, 'roll']
                );

                Route::post(
                    'matches/{match}/move',
                    [GameController::class, 'move']
                );
            });

        /*
        |--------------------------------------------------------------------------
        | Match synchronization and reconnect
        |--------------------------------------------------------------------------
        |
        | Active clients poll authoritative state as a safety mechanism for
        | missed realtime events. This group therefore has a separate, higher
        | allowance and cannot block roll or move requests.
        |
        */

        Route::middleware('throttle:300,1,game-state-')
            ->group(function () {
                Route::get(
                    'matches/{match}/state',
                    [GameController::class, 'state']
                );

                Route::post(
                    'matches/{match}/reconnect',
                    [GameController::class, 'reconnect']
                );
            });

        /*
        |--------------------------------------------------------------------------
        | Match chat and emoji
        |--------------------------------------------------------------------------
        */

        Route::get(
            'matches/{match}/chat',
            [ChatController::class, 'history']
        )->middleware('throttle:60,1,game-chat-history-');

        Route::post(
            'matches/{match}/chat',
            [ChatController::class, 'message']
        )->middleware('throttle:chat');

        Route::post(
            'matches/{match}/emoji',
            [ChatController::class, 'emoji']
        )->middleware('throttle:emoji');

        /*
        |--------------------------------------------------------------------------
        | Admin back office
        |--------------------------------------------------------------------------
        */

        Route::prefix('admin')
            ->middleware('admin')
            ->group(function () {
                Route::get('users', [AdminController::class, 'users']);
                Route::get('matches', [AdminController::class, 'matches']);
                Route::get('reports', [AdminController::class, 'reports']);

                Route::post(
                    'users/{user}/ban',
                    [AdminController::class, 'banUser']
                );

                Route::post(
                    'users/{user}/unban',
                    [AdminController::class, 'unbanUser']
                );
            });
    });
});
