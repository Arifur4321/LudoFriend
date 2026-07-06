<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\StorePurchaseRequest;
use App\Http\Resources\CoinPackResource;
use App\Services\Economy\StoreService;
use App\Services\Economy\WalletService;
use Illuminate\Http\JsonResponse;
use RuntimeException;

class StoreController extends Controller
{
    public function __construct(
        private readonly StoreService $store,
        private readonly WalletService $wallet,
    ) {
    }

    /** List purchasable coin packs. */
    public function packs(): JsonResponse
    {
        return response()->json([
            'enabled' => $this->store->enabled(),
            'packs' => CoinPackResource::collection($this->store->packs()),
        ]);
    }

    /** Record + verify a purchase and credit coins when valid. */
    public function purchase(StorePurchaseRequest $request): JsonResponse
    {
        try {
            $purchase = $this->store->verifyAndAward(
                $request->user(),
                $request->string('product_id'),
                $request->string('platform'),
                $request->input('receipt'),
            );
        } catch (RuntimeException $e) {
            return response()->json(['message' => $e->getMessage()], 422);
        }

        return response()->json([
            'status' => $purchase->status,
            'coins_awarded' => (int) $purchase->coins_awarded,
            'coins' => $this->wallet->balance($request->user()),
            'pending' => $purchase->status !== 'verified',
        ], $purchase->status === 'verified' ? 201 : 202);
    }
}
