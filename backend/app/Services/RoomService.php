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
use App\Models\WalletTransaction;
use App\Services\Economy\BoardService;
use App\Services\Economy\WalletService;
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
    public function __construct(
        private readonly GameEngineService $engine,
        private readonly WalletService $wallet,
        private readonly BoardService $boards,
    ) {
    }

    /**
     * Create a room and seat the host at seat 0 / first color.
     *
     * Staked rooms resolve their per-seat stake from the board tier and require
     * the host to be able to afford the buy-in up front (coins are only debited
     * at match start, not here).
     *
     * @param  array{mode?:string,board_tier?:string,team_mode?:bool,visibility?:string,bot_fill?:bool,turn_timer_seconds?:int,settings?:array}  $attributes
     */
    public function create(User $host, array $attributes): GameRoom
    {
        $mode = $attributes['mode'] ?? '4p';
        // Default to the free casual table; staked play passes an explicit tier.
        $tierKey = $attributes['board_tier'] ?? 'casual';
        $teamMode = (bool) ($attributes['team_mode'] ?? false);
        $botFill = (bool) ($attributes['bot_fill'] ?? false);

        $this->boards->assertPlayable($tierKey, $mode, $teamMode);
        $stake = $this->boards->stakeFor($tierKey);

        // Staked tables are human-only so the winner-takes-all pot is fair.
        if ($stake > 0 && $botFill) {
            throw new RuntimeException('Bots are not allowed on staked boards.');
        }

        // Host must be able to cover the buy-in before opening a staked table.
        if ($stake > 0 && $this->wallet->balance($host) < $stake) {
            throw new RuntimeException('Not enough coins to host this board.');
        }

        return DB::transaction(function () use ($host, $attributes, $mode, $tierKey, $teamMode, $botFill, $stake) {
            $room = GameRoom::create([
                'code' => $this->generateUniqueCode(),
                'host_user_id' => $host->id,
                'mode' => $mode,
                'board_tier' => $tierKey,
                'stake' => $stake,
                'team_mode' => $teamMode,
                'visibility' => $attributes['visibility'] ?? 'private',
                'bot_fill' => $botFill,
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

            // Must be able to cover the buy-in to sit at a staked table.
            if ($room->stake > 0 && $this->wallet->balance($user) < $room->stake) {
                throw new RuntimeException('Not enough coins to join this board.');
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

            // 2v2 team play requires a full, human-only 4-player table.
            if ($room->team_mode) {
                if ($room->mode !== '4p' || $players->count() !== 4) {
                    throw new RuntimeException('Team mode needs four players.');
                }
                if ($players->where('is_bot', true)->isNotEmpty()) {
                    throw new RuntimeException('Team mode does not allow bots.');
                }
            }

            $stake = (int) $room->stake;
            $match = Matchup::create([
                'room_id' => $room->id,
                'mode' => $room->mode,
                'board_tier' => $room->board_tier,
                'stake' => $stake,
                'pot' => 0, // accumulated as stakes are escrowed below
                'team_mode' => (bool) $room->team_mode,
                'status' => 'active',
                'rule_config' => config('ludo'),
                'seed' => random_int(1, PHP_INT_MAX),
                'started_at' => now(),
            ]);

            $pot = 0;
            $turnOrder = [];
            foreach ($players as $p) {
                // Teams: diagonal partners (seats 0&2 vs 1&3).
                $team = $room->team_mode ? ($p->seat % 2) : null;

                $stakePaid = 0;
                if ($stake > 0 && ! $p->is_bot && $p->user_id) {
                    // Debiting throws InsufficientCoinsException if a player can
                    // no longer afford the buy-in; the whole transaction (match,
                    // seats, other debits) rolls back — no partial escrow.
                    $this->wallet->debit($p->user_id, $stake, WalletTransaction::TYPE_STAKE, [
                        'reference_type' => 'match',
                        'reference_id' => $match->id,
                        'description' => 'Match buy-in',
                        'meta' => ['board_tier' => $room->board_tier, 'color' => $p->color],
                    ]);
                    $stakePaid = $stake;
                    $pot += $stake;
                }

                MatchPlayer::create([
                    'match_id' => $match->id,
                    'user_id' => $p->user_id,
                    'color' => $p->color,
                    'team' => $team,
                    'seat' => $p->seat,
                    'is_bot' => $p->is_bot,
                    'stake_paid' => $stakePaid,
                ]);
                $turnOrder[] = $p->color;
            }

            if ($pot > 0) {
                $match->update(['pot' => $pot]);
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
