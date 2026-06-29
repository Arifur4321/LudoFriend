<?php

namespace App\Jobs;

use App\Models\PlayerStat;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;
use Illuminate\Support\Facades\DB;

/**
 * Recompute the rank column for a leaderboard period by ordering on rating.
 * Win/game/rating aggregates are maintained incrementally elsewhere; this job
 * only (re)assigns dense ranks so the API can sort cheaply.
 */
class RecalculateLeaderboard implements ShouldQueue
{
    use Queueable;

    public function __construct(public string $period = 'all_time')
    {
    }

    public function handle(): void
    {
        $rank = 0;

        DB::transaction(function () use (&$rank) {
            $rows = PlayerStat::forPeriod($this->period)
                ->orderByDesc('rating')
                ->orderByDesc('wins')
                ->lockForUpdate()
                ->get();

            foreach ($rows as $row) {
                $rank++;
                if ($row->rank !== $rank) {
                    $row->update(['rank' => $rank]);
                }
            }
        });
    }
}
