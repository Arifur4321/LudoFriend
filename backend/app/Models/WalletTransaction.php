<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Immutable coin-ledger entry. Rows are only ever inserted, never updated —
 * corrections are new `adjustment` rows. `amount` is signed (negative = debit).
 */
class WalletTransaction extends Model
{
    use HasFactory;

    public const TYPE_SIGNUP_BONUS = 'signup_bonus';
    public const TYPE_STAKE = 'stake';          // debit: buy into a match
    public const TYPE_PRIZE = 'prize';          // credit: won the pot
    public const TYPE_REFUND = 'refund';        // credit: match aborted
    public const TYPE_SPIN = 'spin';            // credit: daily free spin
    public const TYPE_PURCHASE = 'purchase';    // credit: bought coins
    public const TYPE_ADJUSTMENT = 'adjustment';// credit/debit: admin/manual

    protected $fillable = [
        'user_id',
        'type',
        'amount',
        'balance_after',
        'reference_type',
        'reference_id',
        'description',
        'meta',
    ];

    protected function casts(): array
    {
        return [
            'amount' => 'integer',
            'balance_after' => 'integer',
            'reference_id' => 'integer',
            'meta' => 'array',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function isCredit(): bool
    {
        return $this->amount >= 0;
    }
}
