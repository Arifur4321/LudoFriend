<?php

namespace App\Services;

use App\Models\GameRoom;
use App\Models\MatchmakingTicket;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use RuntimeException;

/**
 * MatchmakingService — a simple FIFO (optionally rating-aware) queue per mode.
 *
 * enqueue(): place a ticket; if enough queued players exist, pair them into a
 *            fresh public room and mark their tickets matched.
 * cancel():  withdraw a queued ticket.
 * status():  report a ticket's current state (queued/matched + room).
 *
 * Bot-fill: a queued ticket older than config('ludo.matchmaking_bot_fill_seconds')
 * is paired into a bot-filled room by the ExpireStaleRooms/matchmaking sweep
 * (see fillExpiredWithBots()).
 */
class MatchmakingService
{
    public function __construct(private readonly RoomService $rooms)
    {
    }

    /**
     * Enqueue a player for a mode. A user may only hold one active ticket.
     */
    public function enqueue(User $user, string $mode): MatchmakingTicket
    {
        return DB::transaction(function () use ($user, $mode) {
            $active = MatchmakingTicket::where('user_id', $user->id)
                ->whereIn('status', ['queued', 'matched'])
                ->lockForUpdate()
                ->first();

            if ($active) {
                return $active; // idempotent
            }

            $ticket = MatchmakingTicket::create([
                'user_id' => $user->id,
                'mode' => $mode,
                'status' => 'queued',
                'rating' => optional($user->stats()->forPeriod('all_time')->first())->rating
                    ?? config('ludo.rating_default'),
                'enqueued_at' => now(),
            ]);

            $this->tryPair($mode);

            return $ticket->fresh();
        });
    }

    /**
     * Cancel a queued ticket.
     */
    public function cancel(User $user): void
    {
        MatchmakingTicket::where('user_id', $user->id)
            ->where('status', 'queued')
            ->update(['status' => 'cancelled']);
    }

    /**
     * Report the status of a user's most recent ticket.
     *
     * @return array{status:string,room_code:?string,room_id:?int}
     */
    public function status(User $user): array
    {
        $ticket = MatchmakingTicket::where('user_id', $user->id)
            ->latest('id')
            ->first();

        if (! $ticket) {
            return ['status' => 'none', 'room_code' => null, 'room_id' => null];
        }

        $room = $ticket->room_id ? GameRoom::find($ticket->room_id) : null;

        return [
            'status' => $ticket->status,
            'room_code' => $room?->code,
            'room_id' => $room?->id,
        ];
    }

    /**
     * Attempt to pair the oldest queued tickets for a mode into a new room.
     */
    private function tryPair(string $mode): void
    {
        $needed = $mode === '2p' ? 2 : 4;

        $queued = MatchmakingTicket::where('mode', $mode)
            ->where('status', 'queued')
            ->orderBy('enqueued_at')
            ->lockForUpdate()
            ->limit($needed)
            ->get();

        if ($queued->count() < $needed) {
            return;
        }

        $host = $queued->first()->user;
        $room = $this->rooms->create($host, [
            'mode' => $mode,
            'visibility' => 'public',
            'bot_fill' => false,
        ]);

        foreach ($queued->slice(1) as $ticket) {
            $this->rooms->join($room, $ticket->user);
        }

        MatchmakingTicket::whereIn('id', $queued->pluck('id'))->update([
            'status' => 'matched',
            'room_id' => $room->id,
        ]);
    }

    /**
     * Sweep: pair long-waiting tickets into bot-filled rooms so solo queuers are
     * never stuck. Invoked by a scheduled job.
     */
    public function fillExpiredWithBots(): int
    {
        $cutoff = now()->subSeconds(config('ludo.matchmaking_bot_fill_seconds'));
        $filled = 0;

        $stale = MatchmakingTicket::where('status', 'queued')
            ->where('enqueued_at', '<=', $cutoff)
            ->get();

        foreach ($stale as $ticket) {
            DB::transaction(function () use ($ticket, &$filled) {
                $fresh = MatchmakingTicket::whereKey($ticket->id)->lockForUpdate()->first();
                if (! $fresh || $fresh->status !== 'queued') {
                    return;
                }

                $room = $this->rooms->create($fresh->user, [
                    'mode' => $fresh->mode,
                    'visibility' => 'public',
                    'bot_fill' => true,
                ]);

                $fresh->update(['status' => 'matched', 'room_id' => $room->id]);
                $filled++;
            });
        }

        return $filled;
    }
}
