<?php

namespace App\Services\Economy;

use App\Models\Purchase;
use App\Models\User;
use App\Models\WalletTransaction;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use RuntimeException;

/**
 * StoreService — coin-pack catalog + purchase verification.
 *
 * Receipt verification is gated by config('economy.store.verify_receipts'):
 *   - true  → verify against the platform store (Apple implemented; Play left
 *             as a documented stub until a service account is wired).
 *   - false → coins are only granted in local/testing (dev flow). In any other
 *             environment the purchase is recorded 'pending' and NOT credited,
 *             so real money paths stay safe until credentials are added.
 */
class StoreService
{
    public function __construct(private readonly WalletService $wallet)
    {
    }

    public function enabled(): bool
    {
        return (bool) config('economy.store.enabled', true);
    }

    /** @return array<int,array> */
    public function packs(): array
    {
        return array_values(config('economy.store.packs', []));
    }

    public function findPack(string $productId): ?array
    {
        foreach ($this->packs() as $pack) {
            if (($pack['product_id'] ?? null) === $productId) {
                return $pack;
            }
        }

        return null;
    }

    /**
     * Record a purchase, verify it, and (if valid) credit coins atomically.
     *
     * @throws RuntimeException on unknown product / disabled store.
     */
    public function verifyAndAward(User $user, string $productId, string $platform, ?string $receipt): Purchase
    {
        if (! $this->enabled()) {
            throw new RuntimeException('The coin store is currently unavailable.');
        }

        $pack = $this->findPack($productId);
        if (! $pack) {
            throw new RuntimeException('Unknown coin pack.');
        }

        $coins = (int) $pack['coins'] + (int) ($pack['bonus'] ?? 0);

        $purchase = Purchase::create([
            'user_id' => $user->id,
            'product_id' => $productId,
            'platform' => $platform,
            'receipt' => $receipt,
            'status' => 'pending',
            'meta' => ['coins' => $coins],
        ]);

        $verified = config('economy.store.verify_receipts')
            ? $this->verifyReceipt($platform, $productId, $receipt)
            : app()->environment(['local', 'testing']);

        if (! $verified) {
            return $purchase; // recorded, awaiting verification; no coins granted
        }

        DB::transaction(function () use ($user, $purchase, $coins) {
            $this->wallet->credit($user, $coins, WalletTransaction::TYPE_PURCHASE, [
                'reference_type' => 'purchase',
                'reference_id' => $purchase->id,
                'description' => 'Coin pack purchase',
                'meta' => ['product_id' => $purchase->product_id],
            ]);

            $purchase->forceFill([
                'status' => 'verified',
                'coins_awarded' => $coins,
                'verified_at' => now(),
            ])->save();
        });

        return $purchase->fresh();
    }

    /**
     * Platform receipt verification. Apple is implemented against verifyReceipt;
     * Google Play requires a service-account OAuth token (add when credentials
     * are provisioned) and currently returns false so nothing is credited.
     */
    private function verifyReceipt(string $platform, string $productId, ?string $receipt): bool
    {
        if (empty($receipt)) {
            return false;
        }

        if ($platform === 'ios') {
            $secret = config('economy.store.apple_shared_secret');
            if (empty($secret)) {
                return false;
            }
            // Try production, then sandbox (Apple's recommended flow).
            foreach (['https://buy.itunes.apple.com/verifyReceipt', 'https://sandbox.itunes.apple.com/verifyReceipt'] as $url) {
                $res = Http::asJson()->post($url, [
                    'receipt-data' => $receipt,
                    'password' => $secret,
                    'exclude-old-transactions' => true,
                ]);
                $status = (int) $res->json('status', -1);
                if ($status === 0) {
                    return true;
                }
                if ($status !== 21007) { // 21007 => retry in sandbox
                    break;
                }
            }

            return false;
        }

        // android / web: real verification requires provisioned credentials.
        return false;
    }
}
