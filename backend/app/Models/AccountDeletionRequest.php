<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * A user-initiated account deletion request.
 *
 * Recording a request is intentionally non-destructive: wallet, purchase, and
 * match records are retained for game integrity, fraud prevention, and
 * accounting. Actual deletion/anonymization is performed out of band once the
 * request is reviewed.
 */
class AccountDeletionRequest extends Model
{
    protected $fillable = [
        'user_id',
        'status',
        'reason',
        'processed_at',
    ];

    protected function casts(): array
    {
        return [
            'processed_at' => 'datetime',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
