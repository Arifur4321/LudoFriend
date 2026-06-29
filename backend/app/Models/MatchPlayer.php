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
        'seat',
        'is_bot',
        'placement',
        'disconnected_at',
        'reconnected_at',
    ];

    protected function casts(): array
    {
        return [
            'seat' => 'integer',
            'is_bot' => 'boolean',
            'placement' => 'integer',
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
