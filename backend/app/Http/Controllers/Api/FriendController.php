<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\AcceptFriendByCodeRequest;
use App\Http\Requests\FriendInviteRequest;
use App\Http\Resources\UserResource;
use App\Models\FriendLink;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class FriendController extends Controller
{
    /** List the authenticated user's accepted friends. */
    public function index(Request $request): JsonResponse
    {
        $userId = $request->user()->id;

        $friendIds = FriendLink::where('user_id', $userId)
            ->accepted()
            ->pluck('friend_user_id');

        $friends = User::whereIn('id', $friendIds)->with('profile')->get();

        return response()->json([
            'data' => UserResource::collection($friends),
        ]);
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
}
