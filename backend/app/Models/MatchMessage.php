<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * A single in-match chat entry (free text or a canned phrase). Emoji reactions
 * are ephemeral and are NOT persisted here.
 */
class MatchMessage extends Model
{
    /** Only created_at is tracked. */
    public const UPDATED_AT = null;

    protected $fillable = [
        'match_id',
        'user_id',
        'color',
        'type',
        'body',
    ];

    public function matchup(): BelongsTo
    {
        return $this->belongsTo(Matchup::class, 'match_id');
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
