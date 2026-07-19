<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class MatchmakingTicket extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'mode',
        'team_mode',
        'board_tier',
        'stake',
        'status',
        'room_id',
        'rating',
        'enqueued_at',
    ];

    protected function casts(): array
    {
        return [
            'stake' => 'integer',
            'team_mode' => 'boolean',
            'rating' => 'integer',
            'enqueued_at' => 'datetime',
        ];
    }

    public function scopeQueued(Builder $query): Builder
    {
        return $query->where('status', 'queued');
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function room(): BelongsTo
    {
        return $this->belongsTo(GameRoom::class, 'room_id');
    }
}
