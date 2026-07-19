<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class MatchPlayer extends Model
{
    use HasFactory;

    protected $fillable = [
        'match_id',
        'user_id',
        'color',
        'team',
        'seat',
        'is_bot',
        'display_name',
        'placement',
        'stake_paid',
        'payout',
        'disconnected_at',
        'reconnected_at',
    ];

    protected function casts(): array
    {
        return [
            'seat' => 'integer',
            'team' => 'integer',
            'is_bot' => 'boolean',
            'placement' => 'integer',
            'stake_paid' => 'integer',
            'payout' => 'integer',
            'disconnected_at' => 'datetime',
            'reconnected_at' => 'datetime',
        ];
    }

    public function matchup(): BelongsTo
    {
        return $this->belongsTo(Matchup::class, 'match_id');
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
