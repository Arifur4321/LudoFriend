<?php

namespace App\Http\Controllers\Api;

use App\Events\PlayerReconnected;
use App\Http\Controllers\Controller;
use App\Http\Requests\MoveTokenRequest;
use App\Http\Requests\RollDiceRequest;
use App\Http\Resources\MatchResource;
use App\Models\Matchup;
use App\Services\Game\GameEngineService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use RuntimeException;

/**
 * GameController — thin HTTP layer over the server-authoritative
 * GameEngineService. Every action is authorized (MatchPolicy) and then handed
 * to the engine, which performs the real validation and state mutation.
 */
class GameController extends Controller
{
    public function __construct(private readonly GameEngineService $engine) {}

    /** Return the authoritative match state for a participant. */
    public function state(Request $request, Matchup $match): JsonResponse
    {
        $this->authorize('view', $match);

        $match->load(['players.user', 'state']);
        $payload = (new MatchResource($match))->resolve($request);
        $payload['legal_moves'] = $this->engine->legalMovesForState(
            $match->state?->state ?? [],
        );

        return response()->json(['data' => $payload]);
    }

    /** Roll the dice for the caller's color. */
    public function roll(RollDiceRequest $request, Matchup $match): JsonResponse
    {
        $color = $request->string('color')->lower()->toString();
        $this->authorize('act', [$match, $color]);

        try {
            $result = $this->engine->roll($match, $color);
        } catch (RuntimeException $e) {
            return response()->json(['message' => $e->getMessage()], 422);
        }

        return response()->json([
            'data' => [
                'dice' => $result['dice'],
                'forfeited' => $result['forfeited'],
                'legal_moves' => $result['legal_moves'],
                'turn_passed' => $result['turn_passed'],
                'state' => $result['state'],
            ],
        ]);
    }

    /** Move one of the caller's tokens (destination computed server-side). */
    public function move(MoveTokenRequest $request, Matchup $match): JsonResponse
    {
        $color = $request->string('color')->lower()->toString();
        $this->authorize('act', [$match, $color]);

        try {
            $result = $this->engine->move(
                $match,
                $color,
                (int) $request->integer('token'),
                $request->filled('seq') ? (int) $request->integer('seq') : null,
            );
        } catch (RuntimeException $e) {
            return response()->json(['message' => $e->getMessage()], 422);
        }

        return response()->json([
            'data' => [
                'from' => $result['from'],
                'to' => $result['to'],
                'captured' => $result['captured'],
                'finished' => $result['finished'],
                'extra_turn' => $result['extra_turn'],
                'winner' => $result['winner'],
                'turn_passed' => $result['turn_passed'],
                'state' => $result['state'],
            ],
        ]);
    }

    /**
     * Reconnect: mark the participant reconnected and return the full
     * authoritative snapshot so the client can resync.
     */
    public function reconnect(Request $request, Matchup $match): JsonResponse
    {
        $this->authorize('view', $match);

        $seat = $match->players()->where('user_id', $request->user()->id)->first();
        if ($seat) {
            $seat->update(['reconnected_at' => now(), 'disconnected_at' => null]);
            broadcast(new PlayerReconnected($match->id, $seat->color));
        }

        return response()->json([
            'data' => (new MatchResource($match->load(['players.user', 'state'])))->resolve(),
        ]);
    }
}
