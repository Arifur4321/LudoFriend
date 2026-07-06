<?php

namespace Tests\Feature;

use App\Exceptions\InsufficientCoinsException;
use App\Models\PlayerProfile;
use App\Models\User;
use App\Models\WalletTransaction;
use App\Services\Economy\WalletService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class WalletServiceTest extends TestCase
{
    use RefreshDatabase;

    private function wallet(): WalletService
    {
        return app(WalletService::class);
    }

    private function user(int $coins): User
    {
        $u = User::factory()->create();
        PlayerProfile::factory()->create(['user_id' => $u->id, 'coins' => $coins]);

        return $u;
    }

    public function test_credit_increases_balance_and_records_ledger_row(): void
    {
        $u = $this->user(100);

        $tx = $this->wallet()->credit($u, 250, WalletTransaction::TYPE_PRIZE);

        $this->assertSame(350, $this->wallet()->balance($u));
        $this->assertSame(250, $tx->amount);
        $this->assertSame(350, $tx->balance_after);
        $this->assertDatabaseHas('wallet_transactions', [
            'user_id' => $u->id, 'type' => 'prize', 'amount' => 250, 'balance_after' => 350,
        ]);
    }

    public function test_debit_decreases_balance(): void
    {
        $u = $this->user(500);

        $this->wallet()->debit($u, 200, WalletTransaction::TYPE_STAKE);

        $this->assertSame(300, $this->wallet()->balance($u));
        $this->assertDatabaseHas('wallet_transactions', [
            'user_id' => $u->id, 'type' => 'stake', 'amount' => -200, 'balance_after' => 300,
        ]);
    }

    public function test_debit_beyond_balance_throws_and_does_not_move_coins(): void
    {
        $u = $this->user(150);

        try {
            $this->wallet()->debit($u, 200, WalletTransaction::TYPE_STAKE);
            $this->fail('Expected InsufficientCoinsException.');
        } catch (InsufficientCoinsException $e) {
            $this->assertSame(200, $e->required);
            $this->assertSame(150, $e->available);
        }

        $this->assertSame(150, $this->wallet()->balance($u));
        $this->assertDatabaseMissing('wallet_transactions', ['user_id' => $u->id]);
    }

    public function test_ledger_balance_after_tracks_running_total(): void
    {
        $u = $this->user(0);

        $this->wallet()->credit($u, 1000, WalletTransaction::TYPE_SPIN);
        $this->wallet()->debit($u, 200, WalletTransaction::TYPE_STAKE);
        $this->wallet()->credit($u, 50, WalletTransaction::TYPE_ADJUSTMENT);

        $rows = WalletTransaction::where('user_id', $u->id)->orderBy('id')->pluck('balance_after')->all();
        $this->assertSame([1000, 800, 850], $rows);
        $this->assertSame(850, $this->wallet()->balance($u));
    }

    public function test_signup_bonus_is_idempotent(): void
    {
        $u = User::factory()->create();
        PlayerProfile::factory()->create(['user_id' => $u->id, 'coins' => 0]);

        $this->wallet()->grantSignupBonus($u, 500);
        $this->wallet()->grantSignupBonus($u, 500); // second call must be a no-op

        $this->assertSame(500, $this->wallet()->balance($u));
        $this->assertSame(1, WalletTransaction::where('user_id', $u->id)->where('type', 'signup_bonus')->count());
    }
}
