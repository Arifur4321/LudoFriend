<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class MatchEvent extends Model
{
    use HasFactory;

    protected $fillable = [
        'match_id',
        'seq',
        'actor_color',
        'type',
        'payload',
        'server_time',
    ];

    protected function casts(): array
    {
        return [
            'seq' => 'integer',
            'payload' => 'array',
            'server_time' => 'datetime',
        ];
    }

    public function matchup(): BelongsTo
    {
        return $this->belongsTo(Matchup::class, 'match_id');
    }
}
