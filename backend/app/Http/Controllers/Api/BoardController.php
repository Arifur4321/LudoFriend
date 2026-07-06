<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\BoardTierResource;
use App\Services\Economy\BoardService;
use App\Services\Economy\WalletService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class BoardController extends Controller
{
    public function __construct(
        private readonly BoardService $boards,
        private readonly WalletService $wallet,
    ) {
    }

    /** List staked board tiers + whether the caller can currently afford each. */
    public function index(Request $request): JsonResponse
    {
        $balance = $this->wallet->balance($request->user());

        $tiers = collect($this->boards->all())
            ->reject(fn (array $tier) => (bool) ($tier['hidden'] ?? false))
            ->map(function (array $tier) use ($balance, $request) {
                return array_merge(
                    (new BoardTierResource($tier))->toArray($request),
                    ['affordable' => $balance >= (int) $tier['stake']],
                );
            })->values()->all();

        return response()->json([
            'coins' => $balance,
            'tiers' => $tiers,
        ]);
    }
}
