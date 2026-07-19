<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\GameRoom;
use App\Services\MatchmakingService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class MatchmakingController extends Controller
{
    public function __construct(private readonly MatchmakingService $matchmaking) {}

    /** Enqueue the caller for a mode. */
    public function enqueue(Request $request): JsonResponse
    {
        $request->validate([
            'mode' => ['required', 'in:2p,4p'],
            'team_mode' => ['sometimes', 'boolean'],
        ]);

        $mode = $request->string('mode')->toString();
        $teamMode = $request->boolean('team_mode');

        // Team 2v2 is a four-player-only queue.
        if ($teamMode && $mode !== '4p') {
            return response()->json(
                ['message' => 'Team 2v2 matchmaking requires 4-player mode.'],
                422,
            );
        }

        $ticket = $this->matchmaking->enqueue($request->user(), $mode, $teamMode);

        // When enqueue completed a full human table immediately, surface the
        // room + match so the client can navigate straight in.
        $matchId = null;
        if ($ticket->status === 'matched' && $ticket->room_id) {
            $matchId = optional(GameRoom::with('matchup')->find($ticket->room_id))->matchup?->id;
        }

        return response()->json([
            'data' => [
                'ticket_id' => $ticket->id,
                'status' => $ticket->status,
                'team_mode' => (bool) $ticket->team_mode,
                'room_id' => $ticket->room_id,
                'match_id' => $matchId,
            ],
        ], 201);
    }

    /** Cancel the caller's queued ticket. */
    public function cancel(Request $request): JsonResponse
    {
        $this->matchmaking->cancel($request->user());

        return response()->json(['message' => 'Matchmaking cancelled.']);
    }

    /** Poll matchmaking status (status + room code when matched). */
    public function status(Request $request): JsonResponse
    {
        return response()->json(['data' => $this->matchmaking->status($request->user())]);
    }
}
