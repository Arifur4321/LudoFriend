<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\UpdateProfileRequest;
use App\Http\Resources\MatchResource;
use App\Http\Resources\ProfileResource;
use App\Models\MatchPlayer;
use App\Models\PlayerProfile;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

class ProfileController extends Controller
{
    /** Show the authenticated user's profile. */
    public function show(Request $request): ProfileResource
    {
        $profile = PlayerProfile::firstOrCreate(
            ['user_id' => $request->user()->id],
            ['display_name' => $request->user()->name, 'coins' => config('ludo.starting_coins')]
        );

        return new ProfileResource($profile);
    }

    /** Update display name / avatar. */
    public function update(UpdateProfileRequest $request): ProfileResource
    {
        $profile = PlayerProfile::firstOrCreate(['user_id' => $request->user()->id]);
        $profile->fill($request->validated())->save();

        return new ProfileResource($profile);
    }

    /** Aggregate stats for the authenticated user. */
    public function stats(Request $request): array
    {
        $profile = PlayerProfile::firstOrCreate(['user_id' => $request->user()->id]);

        return [
            'data' => [
                'matches_played' => (int) $profile->matches_played,
                'wins' => (int) $profile->wins,
                'losses' => (int) $profile->losses,
                'win_rate' => $profile->matches_played > 0
                    ? round($profile->wins / $profile->matches_played, 4)
                    : 0,
                'best_streak' => (int) $profile->best_streak,
                'current_streak' => (int) $profile->current_streak,
                'coins' => (int) $profile->coins,
            ],
        ];
    }

    /** Paginated match history for the authenticated user. */
    public function matchHistory(Request $request): AnonymousResourceCollection
    {
        $matchIds = MatchPlayer::where('user_id', $request->user()->id)
            ->latest('id')
            ->limit(200)
            ->pluck('match_id');

        $matches = \App\Models\Matchup::whereIn('id', $matchIds)
            ->with('players.user')
            ->latest('id')
            ->paginate(20);

        return MatchResource::collection($matches);
    }
}
