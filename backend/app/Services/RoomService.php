<?php

namespace App\Services;

use App\Events\GameStarted;
use App\Events\PlayerJoinedRoom;
use App\Events\PlayerLeftRoom;
use App\Models\GameRoom;
use App\Models\GameRoomPlayer;
use App\Models\Matchup;
use App\Models\MatchPlayer;
use App\Models\User;
use App\Services\Game\GameEngineService;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use RuntimeException;

/**
 * RoomService — lobby lifecycle: room creation with unique codes, seat/color
 * assignment, capacity enforcement, readiness, and promotion of a full+ready
 * lobby into a live Matchup with an authoritative initial state.
 */
class RoomService
{
    public function __construct(private readonly GameEngineService $engine)
    {
    }

    /**
     * Create a room and seat the host at seat 0 / first color.
     *
     * @param  array{mode?:string,visibility?:string,bot_fill?:bool,turn_timer_seconds?:int,settings?:array}  $attributes
     */
    public function create(User $host, array $attributes): GameRoom
    {
        return DB::transaction(function () use ($host, $attributes) {
            $room = GameRoom::create([
                'code' => $this->generateUniqueCode(),
                'host_user_id' => $host->id,
                'mode' => $attributes['mode'] ?? '4p',
                'visibility' => $attributes['visibility'] ?? 'private',
                'bot_fill' => $attributes['bot_fill'] ?? false,
                'turn_timer_seconds' => $attributes['turn_timer_seconds'] ?? config('ludo.turn_timer_seconds'),
                'status' => 'lobby',
                'settings' => $attributes['settings'] ?? null,
            ]);

            $this->seatPlayer($room, $host);

            return $room->fresh('players');
        });
    }

    /**
     * Join an existing lobby. Enforces capacity so users cannot join full
     * rooms, and prevents double-seating.
     *
     * @throws RuntimeException when the room is not joinable or already full.
     */
    public function join(GameRoom $room, User $user): GameRoomPlayer
    {
        return DB::transaction(function () use ($room, $user) {
            /** @var GameRoom $room */
            $room = GameRoom::whereKey($room->id)->lockForUpdate()->firstOrFail();

            if (! $room->isLobby()) {
                throw new RuntimeException('Room is not accepting players.');
            }

            $existing = $room->players()->where('user_id', $user->id)->first();
            if ($existing) {
                return $existing; // idempotent re-join
            }

            if ($room->isFull()) {
                throw new RuntimeException('Room is full.');
            }

            $player = $this->seatPlayer($room, $user);

            broadcast(new PlayerJoinedRoom($room->id, $player->id));

            return $player;
        });
    }

    /**
     * Leave a lobby. If the host leaves, ownership transfers to the next
     * seated human; if no humans remain the room is cancelled.
     */
    public function leave(GameRoom $room, User $user): void
    {
        DB::transaction(function () use ($room, $user) {
            $room = GameRoom::whereKey($room->id)->lockForUpdate()->firstOrFail();

            $seat = $room->players()->where('user_id', $user->id)->first();
            if (! $seat) {
                return;
            }

            $seatId = $seat->id;
            $seat->delete();
            broadcast(new PlayerLeftRoom($room->id, $seatId, $user->id));

            $remaining = $room->players()->whereNotNull('user_id')->where('is_bot', false)->get();

            if ($remaining->isEmpty()) {
                $room->update(['status' => 'cancelled']);

                return;
            }

            if ($room->host_user_id === $user->id) {
                $room->update(['host_user_id' => $remaining->first()->user_id]);
            }
        });
    }

    /**
     * Toggle / set readiness for a seated player.
     */
    public function setReady(GameRoom $room, User $user, bool $ready): GameRoomPlayer
    {
        $seat = $room->players()->where('user_id', $user->id)->firstOrFail();
        $seat->update(['is_ready' => $ready]);

        return $seat;
    }

    /**
     * Start the match: optionally fill remaining seats with bots, require all
     * humans ready, create the Matchup + MatchPlayers, and initialize the
     * authoritative game state. Only the host may call this (enforced by policy
     * at the controller layer).
     *
     * @throws RuntimeException when prerequisites are unmet.
     */
    public function start(GameRoom $room): Matchup
    {
        return DB::transaction(function () use ($room) {
            $room = GameRoom::whereKey($room->id)->lockForUpdate()->firstOrFail();

            if (! $room->isLobby()) {
                throw new RuntimeException('Room has already started.');
            }

            if ($room->bot_fill) {
                $this->fillWithBots($room);
            }

            $players = $room->players()->orderBy('seat')->get();

            if ($players->count() < 2) {
                throw new RuntimeException('Need at least two players to start.');
            }

            $humansNotReady = $players->where('is_bot', false)->where('is_ready', false);
            if ($humansNotReady->isNotEmpty()) {
                throw new RuntimeException('All players must be ready.');
            }

            $match = Matchup::create([
                'room_id' => $room->id,
                'mode' => $room->mode,
                'status' => 'active',
                'rule_config' => config('ludo'),
                'seed' => random_int(1, PHP_INT_MAX),
                'started_at' => now(),
            ]);

            $turnOrder = [];
            foreach ($players as $p) {
                MatchPlayer::create([
                    'match_id' => $match->id,
                    'user_id' => $p->user_id,
                    'color' => $p->color,
                    'seat' => $p->seat,
                    'is_bot' => $p->is_bot,
                ]);
                $turnOrder[] = $p->color;
            }

            $this->engine->initializeState($match, $turnOrder);

            $room->update(['status' => 'in_progress']);

            broadcast(new GameStarted($room->id, $match->id, $turnOrder));

            return $match->fresh(['players', 'state']);
        });
    }

    /* =====================================================================
     | Internals
     | ===================================================================== */

    /**
     * Seat a user at the next free seat with the matching color for that seat.
     */
    private function seatPlayer(GameRoom $room, User $user, bool $isBot = false): GameRoomPlayer
    {
        $seat = $this->nextFreeSeat($room);

        return GameRoomPlayer::create([
            'room_id' => $room->id,
            'user_id' => $isBot ? null : $user->id,
            'seat' => $seat,
            'color' => $this->colorForSeat($room, $seat),
            'is_bot' => $isBot,
            'is_ready' => $isBot, // bots are always ready
            'joined_at' => now(),
        ]);
    }

    /**
     * Fill the remaining seats of a room with bot players.
     */
    private function fillWithBots(GameRoom $room): void
    {
        while (! $room->isFull()) {
            $seat = $this->nextFreeSeat($room);
            GameRoomPlayer::create([
                'room_id' => $room->id,
                'user_id' => null,
                'seat' => $seat,
                'color' => $this->colorForSeat($room, $seat),
                'is_bot' => true,
                'is_ready' => true,
                'joined_at' => now(),
            ]);
            $room->load('players');
        }
    }

    /**
     * The lowest unused seat index for the room's capacity.
     */
    private function nextFreeSeat(GameRoom $room): int
    {
        $taken = $room->players()->pluck('seat')->all();
        for ($seat = 0; $seat < $room->capacity(); $seat++) {
            if (! in_array($seat, $taken, true)) {
                return $seat;
            }
        }

        throw new RuntimeException('Room is full.');
    }

    /**
     * Map a seat index to a color. For 2-player matches we use the diagonally
     * opposed colors (red/yellow); for 4-player matches the canonical order.
     */
    private function colorForSeat(GameRoom $room, int $seat): string
    {
        $palette = $room->mode === '2p'
            ? config('ludo.colors_2p')
            : config('ludo.colors');

        return $palette[$seat % count($palette)];
    }

    /**
     * Generate a short, unguessable, collision-free room code.
     */
    private function generateUniqueCode(): string
    {
        do {
            // 6 uppercase alphanumerics, ambiguity-reduced alphabet.
            $code = strtoupper(Str::substr(str_replace(['0', 'O', '1', 'I', 'L'], '', Str::random(16)), 0, 6));
            if (strlen($code) < 6) {
                $code = strtoupper(Str::random(6));
            }
        } while (GameRoom::where('code', $code)->exists());

        return $code;
    }
}
