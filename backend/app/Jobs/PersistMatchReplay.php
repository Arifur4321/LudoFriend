<?php

namespace App\Jobs;

use App\Models\Matchup;
use App\Models\MatchEvent;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;
use Illuminate\Support\Facades\Storage;

/**
 * Non-critical async job: serialize a finished match's ordered event log to a
 * replay file. Useful for dispute resolution and "watch replay" features. This
 * is intentionally best-effort and runs off the request path.
 */
class PersistMatchReplay implements ShouldQueue
{
    use Queueable;

    public function __construct(public int $matchId)
    {
    }

    public function handle(): void
    {
        $match = Matchup::find($this->matchId);
        if (! $match) {
            return;
        }

        $events = MatchEvent::where('match_id', $this->matchId)
            ->orderBy('seq')
            ->get(['seq', 'actor_color', 'type', 'payload', 'server_time']);

        $replay = [
            'match_id' => $match->id,
            'mode' => $match->mode,
            'seed' => $match->seed,
            'rule_config' => $match->rule_config,
            'winner_user_id' => $match->winner_user_id,
            'started_at' => optional($match->started_at)->toIso8601String(),
            'ended_at' => optional($match->ended_at)->toIso8601String(),
            'events' => $events->toArray(),
        ];

        Storage::disk('local')->put(
            "replays/match-{$match->id}.json",
            json_encode($replay, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES)
        );
    }
}
