<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class GameRoomPlayer extends Model
{
    use HasFactory;

    protected $fillable = [
        'room_id',
        'user_id',
        'seat',
        'color',
        'is_bot',
        'is_ready',
        'joined_at',
    ];

    protected function casts(): array
    {
        return [
            'seat' => 'integer',
            'is_bot' => 'boolean',
            'is_ready' => 'boolean',
            'joined_at' => 'datetime',
        ];
    }

    public function room(): BelongsTo
    {
        return $this->belongsTo(GameRoom::class, 'room_id');
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
