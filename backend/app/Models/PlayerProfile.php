<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class PlayerProfile extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'display_name',
        'avatar',
        'coins',
        'matches_played',
        'wins',
        'losses',
        'best_streak',
        'current_streak',
    ];

    protected function casts(): array
    {
        return [
            'coins' => 'integer',
            'matches_played' => 'integer',
            'wins' => 'integer',
            'losses' => 'integer',
            'best_streak' => 'integer',
            'current_streak' => 'integer',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    /**
     * Record a win: bumps counters and the streaks, awards coins.
     */
    public function recordWin(int $coinsReward = 0): void
    {
        $this->matches_played++;
        $this->wins++;
        $this->current_streak = max(1, $this->current_streak + 1);
        $this->best_streak = max($this->best_streak, $this->current_streak);
        $this->coins += $coinsReward;
        $this->save();
    }

    /**
     * Record a loss: bumps counters and resets the current streak.
     */
    public function recordLoss(): void
    {
        $this->matches_played++;
        $this->losses++;
        $this->current_streak = 0;
        $this->save();
    }
}
