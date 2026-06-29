<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\MatchResource;
use App\Http\Resources\UserResource;
use App\Models\Matchup;
use App\Models\Report;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

/**
 * AdminController — back-office endpoints. The route group applies the
 * `admin` middleware (AdminOnly), so every action here assumes an admin caller.
 */
class AdminController extends Controller
{
    /** Paginated user list with optional search. */
    public function users(Request $request): AnonymousResourceCollection
    {
        $query = User::query()->with('profile')->latest('id');

        if ($search = $request->string('q')->toString()) {
            $query->where(function ($q) use ($search) {
                $q->where('name', 'like', "%{$search}%")
                    ->orWhere('email', 'like', "%{$search}%");
            });
        }

        return UserResource::collection($query->paginate(25));
    }

    /** Paginated match list. */
    public function matches(Request $request): AnonymousResourceCollection
    {
        return MatchResource::collection(
            Matchup::query()->with('players')->latest('id')->paginate(25)
        );
    }

    /** Paginated report queue. */
    public function reports(Request $request): JsonResponse
    {
        $reports = Report::query()
            ->with(['reporter:id,name', 'reported:id,name'])
            ->latest('id')
            ->paginate(25);

        return response()->json($reports);
    }

    /** Ban a user with a reason. */
    public function banUser(Request $request, User $user): JsonResponse
    {
        $request->validate(['reason' => ['required', 'string', 'max:255']]);

        $user->update([
            'is_banned' => true,
            'banned_reason' => $request->string('reason'),
            'banned_at' => now(),
        ]);

        // Revoke all tokens so the ban takes effect immediately.
        $user->tokens()->delete();

        return response()->json(['message' => 'User banned.']);
    }

    /** Lift a ban. */
    public function unbanUser(Request $request, User $user): JsonResponse
    {
        $user->update([
            'is_banned' => false,
            'banned_reason' => null,
            'banned_at' => null,
        ]);

        return response()->json(['message' => 'User unbanned.']);
    }
}
