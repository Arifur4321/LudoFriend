<?php

use App\Jobs\AdvanceStuckBotTurns;
use App\Jobs\ExpireStaleMatches;
use App\Jobs\ExpireStaleRooms;
use App\Jobs\RecalculateLeaderboard;
use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Schedule;

Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote');

/*
|--------------------------------------------------------------------------
| Scheduled tasks
|--------------------------------------------------------------------------
*/

// Recovery safety net for online bot turns. The NORMAL path dispatches a bot
// turn within seconds of a human passing the turn to a bot (see
// GameEngineService::maybeDispatchBotTurn); this sweep only re-drives a bot turn
// that has been stuck (e.g. the queue worker was briefly down). It is NOT the
// normal bot cadence — online bots react through the queue/event flow.
Schedule::job(new AdvanceStuckBotTurns())->everyMinute()->withoutOverlapping();

// Expire abandoned lobbies and bot-fill long-waiting matchmaking tickets.
Schedule::job(new ExpireStaleRooms())->everyMinute()->withoutOverlapping();

// Abort idle in-progress matches and refund escrowed stakes.
Schedule::job(new ExpireStaleMatches())->everyFiveMinutes()->withoutOverlapping();

// Recompute leaderboards. Weekly board hourly; all-time a few times a day.
Schedule::job(new RecalculateLeaderboard('weekly'))->hourly();
Schedule::job(new RecalculateLeaderboard('all_time'))->everySixHours();
