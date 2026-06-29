<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\MatchmakingService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class MatchmakingController extends Controller
{
    public function __construct(private readonly MatchmakingService $matchmaking)
    {
    }

    /** Enqueue the caller for a mode. */
    public function enqueue(Request $request): JsonResponse
    {
        $request->validate(['mode' => ['required', 'in:2p,4p']]);

        $ticket = $this->matchmaking->enqueue($request->user(), $request->string('mode'));

        return response()->json([
            'data' => [
                'ticket_id' => $ticket->id,
                'status' => $ticket->status,
                'room_id' => $ticket->room_id,
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
