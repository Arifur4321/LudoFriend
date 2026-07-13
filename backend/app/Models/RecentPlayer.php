<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * A directed "recently played with" link (one row per direction), maintained
 * by GameEngineService when a match completes. Powers the recent-players list
 * and rematch invites without touching the primary friend_links store.
 */
class RecentPlayer extends Model
{
    protected $fillable = [
        'user_id',
        'other_user_id',
        'games',
        'last_match_id',
        'last_played_at',
    ];

    protected function casts(): array
    {
        return [
            'last_played_at' => 'datetime',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function otherUser(): BelongsTo
    {
        return $this->belongsTo(User::class, 'other_user_id');
    }
}
