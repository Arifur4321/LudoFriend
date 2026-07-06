<?php

namespace App\Http\Controllers\Api;

use App\Events\ReadyStatusChanged;
use App\Http\Controllers\Controller;
use App\Http\Requests\CreateRoomRequest;
use App\Http\Requests\JoinRoomRequest;
use App\Http\Resources\MatchResource;
use App\Http\Resources\RoomResource;
use App\Models\GameRoom;
use App\Services\RoomService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use RuntimeException;

class RoomController extends Controller
{
    public function __construct(private readonly RoomService $rooms)
    {
    }

    /** Create a room (the caller becomes host + seat 0). */
    public function create(CreateRoomRequest $request): JsonResponse
    {
        try {
            $room = $this->rooms->create($request->user(), $request->validated());
        } catch (RuntimeException $e) {
            // Staked-board guard rails (affordability, no bots, bad tier/mode).
            return response()->json(['message' => $e->getMessage()], 422);
        }

        return (new RoomResource($room->load('players.user')))
            ->response()
            ->setStatusCode(201);
    }

    /** Join a room by code. Enforces capacity (cannot join a full room). */
    public function join(JoinRoomRequest $request): JsonResponse
    {
        $room = GameRoom::where('code', $request->string('code'))->firstOrFail();

        try {
            $this->rooms->join($room, $request->user());
        } catch (RuntimeException $e) {
            return response()->json(['message' => $e->getMessage()], 409);
        }

        return (new RoomResource($room->fresh('players.user')))
            ->response()
            ->setStatusCode(200);
    }

    /** Leave a room. */
    public function leave(Request $request, GameRoom $room): JsonResponse
    {
        $this->authorize('participate', $room);

        $this->rooms->leave($room, $request->user());

        return response()->json(['message' => 'Left room.']);
    }

    /** Set readiness for the caller. */
    public function ready(Request $request, GameRoom $room): JsonResponse
    {
        $this->authorize('participate', $room);

        $request->validate(['ready' => ['required', 'boolean']]);

        $seat = $this->rooms->setReady($room, $request->user(), $request->boolean('ready'));

        broadcast(new ReadyStatusChanged($room->id, $seat->id, $seat->is_ready));

        return response()->json(['message' => 'Ready status updated.', 'is_ready' => $seat->is_ready]);
    }

    /** Start the match (host only). */
    public function start(Request $request, GameRoom $room): JsonResponse
    {
        $this->authorize('start', $room);

        try {
            $match = $this->rooms->start($room);
        } catch (RuntimeException $e) {
            return response()->json(['message' => $e->getMessage()], 422);
        }

        return (new MatchResource($match->load(['players', 'state'])))
            ->response()
            ->setStatusCode(201);
    }

    /** Show a room (seated players, or anyone for public rooms). */
    public function show(Request $request, GameRoom $room): RoomResource
    {
        $this->authorize('view', $room);

        return new RoomResource($room->load(['players.user', 'matchup']));
    }
}
