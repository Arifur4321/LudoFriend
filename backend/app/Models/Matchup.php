<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;

/**
 * Eloquent model for a single game session.
 *
 * Named "Matchup" rather than "Match" because `match` is a reserved keyword
 * in PHP 8 (the match expression). The underlying table is still `matches`.
 */
class Matchup extends Model
{
    use HasFactory;

    protected $table = 'matches';

    protected $fillable = [
        'room_id',
        'mode',
        'status',
        'winner_user_id',
        'rule_config',
        'seed',
        'started_at',
        'ended_at',
    ];

    protected function casts(): array
    {
        return [
            'rule_config' => 'array',
            'seed' => 'integer',
            'started_at' => 'datetime',
            'ended_at' => 'datetime',
        ];
    }

    public function scopeActive(Builder $query): Builder
    {
        return $query->where('status', 'active');
    }

    public function isActive(): bool
    {
        return $this->status === 'active';
    }

    public function room(): BelongsTo
    {
        return $this->belongsTo(GameRoom::class, 'room_id');
    }

    public function winner(): BelongsTo
    {
        return $this->belongsTo(User::class, 'winner_user_id');
    }

    public function players(): HasMany
    {
        return $this->hasMany(MatchPlayer::class, 'match_id');
    }

    public function events(): HasMany
    {
        return $this->hasMany(MatchEvent::class, 'match_id');
    }

    public function state(): HasOne
    {
        return $this->hasOne(MatchState::class, 'match_id');
    }
}
