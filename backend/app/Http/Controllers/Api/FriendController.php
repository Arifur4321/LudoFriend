<?php

namespace App\Http\Controllers\Api;

use App\Events\FriendRoomInvite;
use App\Http\Controllers\Controller;
use App\Http\Requests\AcceptFriendByCodeRequest;
use App\Http\Requests\FriendInviteRequest;
use App\Http\Requests\InviteToRoomRequest;
use App\Http\Resources\UserResource;
use App\Models\FriendLink;
use App\Models\GameRoom;
use App\Models\SocialAccount;
use App\Models\User;
use App\Services\FacebookService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;

class FriendController extends Controller
{
    /** List the authenticated user's accepted friends. */
    public function index(Request $request): JsonResponse
    {
        $userId = $request->user()->id;

        $friendIds = FriendLink::where('user_id', $userId)
            ->accepted()
            ->pluck('friend_user_id');

        $friends = User::whereIn('id', $friendIds)->get()->map(fn (User $u) => [
            'id' => $u->id,
            'name' => $u->name,
            'avatar' => $u->avatar,
            'is_guest' => (bool) $u->is_guest,
            'online' => (bool) Cache::get("presence:online:{$u->id}", false),
        ])->values();

        return response()->json(['data' => $friends]);
    }

    /**
     * Send a friend invite (creates a pending directed link).
     */
    public function invite(FriendInviteRequest $request): JsonResponse
    {
        $userId = $request->user()->id;
        $friendId = (int) $request->input('friend_user_id');

        if ($friendId === $userId) {
            return response()->json(['message' => 'You cannot add yourself.'], 422);
        }

        $link = FriendLink::firstOrCreate(
            ['user_id' => $userId, 'friend_user_id' => $friendId],
            ['source' => $request->input('source', 'code'), 'status' => 'pending']
        );

        return response()->json([
            'message' => 'Invite sent.',
            'data' => ['id' => $link->id, 'status' => $link->status],
        ], 201);
    }

    /**
     * Accept a friend by code. The code resolves to a user id; this both marks
     * the inbound pending link accepted and creates the reciprocal accepted
     * link so the friendship is mutual.
     */
    public function acceptByCode(AcceptFriendByCodeRequest $request): JsonResponse
    {
        $userId = $request->user()->id;
        $inviterId = (int) $request->string('code')->toString();

        $inviter = User::find($inviterId);
        if (! $inviter || $inviter->id === $userId) {
            return response()->json(['message' => 'Invalid friend code.'], 422);
        }

        // Mark the inviter's outbound link accepted (if present), and create the
        // reciprocal link from the accepting user.
        FriendLink::where('user_id', $inviterId)
            ->where('friend_user_id', $userId)
            ->update(['status' => 'accepted']);

        FriendLink::updateOrCreate(
            ['user_id' => $userId, 'friend_user_id' => $inviterId],
            ['status' => 'accepted', 'source' => 'code']
        );

        return response()->json(['message' => 'Friend added.']);
    }

    /**
     * List the caller's Facebook friends who ALSO play this app (mapped to
     * internal users) with an online flag. Requires a linked Facebook account
     * with the user_friends permission; returns an empty list otherwise. This is
     * the only compliant way to surface FB friends — a full friend list is not
     * available from the Graph API.
     */
    public function facebook(Request $request, FacebookService $facebook): JsonResponse
    {
        $user = $request->user();
        $social = $user->socialAccounts()->where('provider', 'facebook')->first();

        if (! $social || ! $social->access_token) {
            return response()->json(['data' => []]);
        }

        $fbIds = collect($facebook->appFriends($social->access_token))
            ->pluck('id')->filter()->values();

        if ($fbIds->isEmpty()) {
            return response()->json(['data' => []]);
        }

        $friends = SocialAccount::where('provider', 'facebook')
            ->whereIn('provider_user_id', $fbIds->all())
            ->with('user')
            ->get()
            ->map(function (SocialAccount $a) use ($user) {
                $u = $a->user;
                if (! $u || $u->id === $user->id) {
                    return null;
                }

                // App-connected Facebook friends become mutual accepted friends
                // so they can be invited to rooms (idempotent).
                FriendLink::firstOrCreate(
                    ['user_id' => $user->id, 'friend_user_id' => $u->id],
                    ['status' => 'accepted', 'source' => 'facebook'],
                );
                FriendLink::firstOrCreate(
                    ['user_id' => $u->id, 'friend_user_id' => $user->id],
                    ['status' => 'accepted', 'source' => 'facebook'],
                );

                return [
                    'id' => $u->id,
                    'name' => $u->name,
                    'avatar' => $u->avatar,
                    'is_guest' => (bool) $u->is_guest,
                    'online' => (bool) Cache::get("presence:online:{$u->id}", false),
                ];
            })
            ->filter()
            ->values();

        return response()->json(['data' => $friends]);
    }

    /**
     * Invite a friend to the caller's room. The caller must be seated in the
     * room; the invite is delivered to the friend's private user channel so they
     * can one-tap join.
     */
    public function inviteToRoom(InviteToRoomRequest $request): JsonResponse
    {
        $user = $request->user();
        $room = GameRoom::find((int) $request->integer('room_id'));

        if (! $room) {
            return response()->json(['message' => 'Room not found.'], 404);
        }

        if (! $room->players()->where('user_id', $user->id)->exists()) {
            return response()->json(['message' => 'You are not in this room.'], 403);
        }

        $friendId = (int) $request->integer('friend_user_id');

        // Anti-spam: only accepted friends (either direction) may be invited.
        $areFriends = FriendLink::where('status', 'accepted')
            ->where(function ($q) use ($user, $friendId) {
                $q->where(function ($w) use ($user, $friendId) {
                    $w->where('user_id', $user->id)
                        ->where('friend_user_id', $friendId);
                })->orWhere(function ($w) use ($user, $friendId) {
                    $w->where('user_id', $friendId)
                        ->where('friend_user_id', $user->id);
                });
            })
            ->exists();

        if (! $areFriends) {
            return response()->json(['message' => 'You can only invite friends.'], 403);
        }

        broadcast(new FriendRoomInvite(
            $friendId,
            $room->id,
            $room->code,
            ['id' => $user->id, 'name' => $user->name, 'avatar' => $user->avatar],
        ));

        return response()->json(['message' => 'Invite sent.']);
    }
}
