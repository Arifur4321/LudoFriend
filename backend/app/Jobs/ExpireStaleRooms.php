<?php

namespace App\Jobs;

use App\Models\GameRoom;
use App\Services\MatchmakingService;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;

/**
 * Housekeeping job (scheduled every minute):
 *   - Cancels lobbies that have sat idle past config('ludo.room_stale_minutes').
 *   - Asks the matchmaking service to bot-fill long-waiting solo queuers.
 */
class ExpireStaleRooms implements ShouldQueue
{
    use Queueable;

    public function handle(MatchmakingService $matchmaking): void
    {
        $cutoff = now()->subMinutes(config('ludo.room_stale_minutes'));

        GameRoom::where('status', 'lobby')
            ->where('updated_at', '<=', $cutoff)
            ->update(['status' => 'cancelled']);

        // Pair up players who have waited too long with bots.
        $matchmaking->fillExpiredWithBots();
    }
}
