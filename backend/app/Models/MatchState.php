<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * Authoritative snapshot of a match. The `state` JSON holds the full
 * server-side truth; `version` is an optimistic-concurrency counter that the
 * GameEngineService bumps on every applied move.
 */
class MatchState extends Model
{
    use HasFactory;

    // updated_at is managed manually; created_at handled on insert.
    public $timestamps = false;

    protected $fillable = [
        'match_id',
        'version',
        'state',
        'updated_at',
        'created_at',
    ];

    protected function casts(): array
    {
        return [
            'version' => 'integer',
            'state' => 'array',
            'updated_at' => 'datetime',
            'created_at' => 'datetime',
        ];
    }

    public function matchup(): BelongsTo
    {
        return $this->belongsTo(Matchup::class, 'match_id');
    }
}
