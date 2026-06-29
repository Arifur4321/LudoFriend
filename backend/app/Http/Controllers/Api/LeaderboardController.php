<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\LeaderboardResource;
use App\Models\PlayerStat;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

class LeaderboardController extends Controller
{
    /**
     * Top players for a period (all_time|weekly), ordered by rating.
     */
    public function index(Request $request): AnonymousResourceCollection
    {
        $request->validate([
            'period' => ['nullable', 'in:all_time,weekly'],
            'limit' => ['nullable', 'integer', 'min:1', 'max:100'],
        ]);

        $period = $request->input('period', 'all_time');
        $limit = (int) $request->input('limit', 50);

        $rows = PlayerStat::forPeriod($period)
            ->with('user')
            ->orderByDesc('rating')
            ->orderByDesc('wins')
            ->limit($limit)
            ->get();

        return LeaderboardResource::collection($rows);
    }
}
