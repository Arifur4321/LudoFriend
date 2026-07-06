<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * A claimed free spin. Availability is a rolling cooldown
 * (config economy.free_spin.interval_minutes) enforced by FreeSpinService via a
 * wallet-row lock + the most recent `spun_at`; `day_key` is informational only.
 */
class DailySpin extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'day_key',
        'reward',
        'segment_index',
        'spun_at',
    ];

    protected function casts(): array
    {
        return [
            'reward' => 'integer',
            'segment_index' => 'integer',
            'spun_at' => 'datetime',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
