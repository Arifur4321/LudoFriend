<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Report extends Model
{
    use HasFactory;

    protected $fillable = [
        'reporter_user_id',
        'reported_user_id',
        'match_id',
        'reason',
        'details',
        'status',
    ];

    public function reporter(): BelongsTo
    {
        return $this->belongsTo(User::class, 'reporter_user_id');
    }

    public function reported(): BelongsTo
    {
        return $this->belongsTo(User::class, 'reported_user_id');
    }

    public function matchup(): BelongsTo
    {
        return $this->belongsTo(Matchup::class, 'match_id');
    }
}
