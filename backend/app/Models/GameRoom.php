<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class GameRoom extends Model
{
    use HasFactory;

    protected $fillable = [
        'code',
        'host_user_id',
        'mode',
        'board_tier',
        'stake',
        'team_mode',
        'visibility',
        'bot_fill',
        'turn_timer_seconds',
        'status',
        'settings',
    ];

    protected function casts(): array
    {
        return [
            'stake' => 'integer',
            'team_mode' => 'boolean',
            'bot_fill' => 'boolean',
            'turn_timer_seconds' => 'integer',
            'settings' => 'array',
        ];
    }

    /** Maximum seats for this room's mode. */
    public function capacity(): int
    {
        return $this->mode === '2p' ? 2 : 4;
    }

    public function isFull(): bool
    {
        return $this->players()->count() >= $this->capacity();
    }

    public function isLobby(): bool
    {
        return $this->status === 'lobby';
    }

    public function scopeOpenPublic(Builder $query): Builder
    {
        return $query->where('visibility', 'public')->where('status', 'lobby');
    }

    public function host(): BelongsTo
    {
        return $this->belongsTo(User::class, 'host_user_id');
    }

    public function players(): HasMany
    {
        return $this->hasMany(GameRoomPlayer::class, 'room_id');
    }

    public function matchup(): \Illuminate\Database\Eloquent\Relations\HasOne
    {
        return $this->hasOne(Matchup::class, 'room_id')->latestOfMany();
    }
}
