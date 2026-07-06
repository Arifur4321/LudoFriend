<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\WalletTransactionResource;
use App\Services\Economy\WalletService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class WalletController extends Controller
{
    public function __construct(private readonly WalletService $wallet)
    {
    }

    /** Current balance + a few recent ledger rows. */
    public function show(Request $request): JsonResponse
    {
        $user = $request->user();

        return response()->json([
            'coins' => $this->wallet->balance($user),
            'recent' => WalletTransactionResource::collection($this->wallet->history($user, 10)),
        ]);
    }

    /** Paginated ledger history. */
    public function transactions(Request $request): JsonResponse
    {
        $user = $request->user();
        $limit = min((int) $request->integer('limit', 50), 100);

        return response()->json([
            'coins' => $this->wallet->balance($user),
            'transactions' => WalletTransactionResource::collection($this->wallet->history($user, $limit)),
        ]);
    }
}
