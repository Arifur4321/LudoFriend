<?php

namespace App\Services;

use App\Models\GameRoom;
use App\Models\GameRoomPlayer;
use App\Models\MatchmakingTicket;
use App\Models\Matchup;
use App\Models\User;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

/**
 * MatchmakingService — an explicit-queue matchmaker per mode (2p / 4p).
 *
 * Product rule: an "available online player" is a user who explicitly pressed
 * Play Online and holds a `queued` ticket. Presence heartbeats are NOT a signal
 * — only queued tickets are ever pulled into a match.
 *
 *   enqueue(): create or reuse ONE active ticket, then immediately form a room
 *              if a full table of humans is already waiting.
 *   cancel():  withdraw a queued ticket.
 *   status():  report the caller's latest ticket (+ room / match when matched).
 *   fillExpiredWithBots(): scheduled sweep — group long-waiting humans into as
 *              few rooms as possible and bot-fill only the leftover seats.
 *
 * Matchmaking rooms are casual (free, stake 0). Humans are auto-readied and the
 * match is auto-started, so nobody has to press a host-only "start" button.
 * Staked play is never matched here, so bots never touch a staked pot.
 */
class MatchmakingService
{
    /**
     * Upper bound on the candidate pool we ever load for random selection, so we
     * never run an unbounded ORDER BY RAND() over a hot production table.
     */
    private const CANDIDATE_POOL = 40;

    public function __construct(private readonly RoomService $rooms) {}

    private function seatsFor(string $mode): int
    {
        return $mode === '2p' ? 2 : 4;
    }

    /**
     * Enqueue a player for a mode. A user only ever holds one active ticket:
     * an existing `queued` ticket is reused, and a user still inside an ongoing
     * matched game keeps that ticket instead of being queued into a second room.
     */
    public function enqueue(User $user, string $mode): MatchmakingTicket
    {
        $ticket = DB::transaction(function () use ($user, $mode) {
            // Lock this user's active tickets so two taps can't create two.
            $active = MatchmakingTicket::where('user_id', $user->id)
                ->whereIn('status', ['queued', 'matched'])
                ->lockForUpdate()
                ->orderByDesc('id')
                ->get();

            // Reuse a live queue ticket (idempotent enqueue).
            if ($queued = $active->firstWhere('status', 'queued')) {
                return $queued;
            }

            // If the user is still inside a matched game that has not finished,
            // reuse that ticket rather than queueing them into a second match.
            if ($matched = $active->firstWhere('status', 'matched')) {
                if ($matched->room_id) {
                    $room = GameRoom::find($matched->room_id);
                    if ($room && in_array($room->status, ['lobby', 'in_progress'], true)) {
                        return $matched;
                    }
                }
            }

            return MatchmakingTicket::create([
                'user_id' => $user->id,
                'mode' => $mode,
                'status' => 'queued',
                'rating' => optional($user->stats()->forPeriod('all_time')->first())->rating
                    ?? config('ludo.rating_default'),
                'enqueued_at' => now(),
            ]);
        });

        Log::info('matchmaking.enqueue', [
            'ticket_id' => $ticket->id,
            'user_id' => $user->id,
            'mode' => $mode,
            'reused' => ! $ticket->wasRecentlyCreated,
        ]);

        // Only a fresh queue entry can complete a table right now.
        if ($ticket->status === 'queued') {
            $this->matchWaitingPlayers($mode);
            $ticket = $ticket->fresh() ?? $ticket;
        }

        return $ticket;
    }

    /**
     * Cancel the caller's queued ticket. Matched (in-progress) games are left
     * untouched. Safe to call repeatedly.
     */
    public function cancel(User $user): void
    {
        MatchmakingTicket::where('user_id', $user->id)
            ->where('status', 'queued')
            ->update(['status' => 'cancelled']);
    }

    /**
     * Report the status of the user's most recent ticket, including the room
     * code + match id once matched so the client can navigate straight in.
     *
     * @return array{status:string,room_code:?string,room_id:?int,match_id:?int}
     */
    public function status(User $user): array
    {
        $ticket = MatchmakingTicket::where('user_id', $user->id)
            ->latest('id')
            ->first();

        if (! $ticket) {
            return ['status' => 'none', 'room_code' => null, 'room_id' => null, 'match_id' => null];
        }

        $room = $ticket->room_id ? GameRoom::with('matchup')->find($ticket->room_id) : null;

        return [
            'status' => $ticket->status,
            'room_code' => $room?->code,
            'room_id' => $room?->id,
            'match_id' => $room?->matchup?->id,
        ];
    }

    /**
     * Scheduled sweep: for each mode, while the OLDEST queued ticket has waited
     * past the configurable bot-fill timeout, pull as many currently-waiting
     * humans as fit into one room and bot-fill only the leftover seats — so
     * several stale humans are grouped into a single room instead of getting a
     * separate bot room each.
     *
     * @return int number of rooms started
     */
    public function fillExpiredWithBots(): int
    {
        $filled = 0;
        $cutoff = now()->subSeconds((int) config('ludo.matchmaking_bot_fill_seconds'));

        foreach (['2p', '4p'] as $mode) {
            // Keep forming rooms while a stale anchor remains for this mode.
            // A hard cap guards against any pathological loop.
            for ($guard = 0; $guard < self::CANDIDATE_POOL; $guard++) {
                $started = DB::transaction(function () use ($mode, $cutoff, &$filled) {
                    $needed = $this->seatsFor($mode);

                    $candidates = MatchmakingTicket::where('mode', $mode)
                        ->where('status', 'queued')
                        ->orderBy('enqueued_at')
                        ->limit(self::CANDIDATE_POOL)
                        ->lockForUpdate()
                        ->get();

                    // Fire only once the oldest waiter is past the timeout.
                    $anchor = $candidates->first();
                    if (! $anchor || $anchor->enqueued_at > $cutoff) {
                        return false;
                    }

                    // Combine all currently-waiting humans first (oldest first),
                    // then bots fill whatever seats remain.
                    $group = $candidates->take($needed);
                    $botFill = $group->count() < $needed;

                    $match = $this->formRoom($group, $mode, $botFill);
                    $filled++;

                    Log::info('matchmaking.bot_fill', [
                        'mode' => $mode,
                        'room_id' => $match->room_id,
                        'match_id' => $match->id,
                        'humans' => $group->count(),
                        'bots' => $needed - $group->count(),
                        'ticket_ids' => $group->pluck('id')->values()->all(),
                    ]);

                    return true;
                });

                if (! $started) {
                    break;
                }
            }
        }

        return $filled;
    }

    /**
     * Immediate pairing: if at least a full room of humans is already queued for
     * $mode, anchor on the oldest ticket and randomly select the remaining
     * humans from a bounded pool (fair, concurrency-safe, no ORDER BY RAND()).
     */
    private function matchWaitingPlayers(string $mode): void
    {
        DB::transaction(function () use ($mode) {
            $needed = $this->seatsFor($mode);

            $candidates = MatchmakingTicket::where('mode', $mode)
                ->where('status', 'queued')
                ->orderBy('enqueued_at')
                ->limit(self::CANDIDATE_POOL)
                ->lockForUpdate()
                ->get();

            if ($candidates->count() < $needed) {
                return; // not enough real players yet — the sweep will bot-fill
            }

            // Oldest ticket anchors the group; the remaining seats are filled by
            // a random pick from the (bounded, already-locked) candidate pool.
            $anchor = $candidates->first();
            $rest = $candidates->slice(1)->shuffle()->take($needed - 1);
            $group = collect([$anchor])->merge($rest);

            $match = $this->formRoom($group, $mode, botFill: false);

            Log::info('matchmaking.matched_humans', [
                'mode' => $mode,
                'room_id' => $match->room_id,
                'match_id' => $match->id,
                'ticket_ids' => $group->pluck('id')->values()->all(),
            ]);
        });
    }

    /**
     * Seat the given (already-locked) human tickets into a fresh public casual
     * room, auto-ready every human, bot-fill the leftover seats when asked,
     * auto-start the match, and point every selected ticket at the room.
     *
     * @param  Collection<int,MatchmakingTicket>  $tickets
     */
    private function formRoom(Collection $tickets, string $mode, bool $botFill): Matchup
    {
        $tickets = $tickets->values();
        $host = $tickets->first()->user;

        $room = $this->rooms->create($host, [
            'mode' => $mode,
            'visibility' => 'public',
            'board_tier' => 'casual', // matchmaking is always the free casual board
            'bot_fill' => $botFill,
        ]);

        foreach ($tickets->slice(1) as $ticket) {
            $this->rooms->join($room, $ticket->user);
        }

        // Matchmaking players never tap "ready" — auto-ready every human seat so
        // the auto-start below is not blocked by a host-only action.
        GameRoomPlayer::where('room_id', $room->id)
            ->where('is_bot', false)
            ->update(['is_ready' => true]);

        // Fills remaining seats with (named) bots when bot_fill is set, then
        // creates the Matchup + authoritative state and broadcasts GameStarted.
        $match = $this->rooms->start($room);

        // Every selected ticket references exactly this room (never a room its
        // holder was not seated in).
        MatchmakingTicket::whereIn('id', $tickets->pluck('id'))->update([
            'status' => 'matched',
            'room_id' => $room->id,
        ]);

        return $match;
    }
}
