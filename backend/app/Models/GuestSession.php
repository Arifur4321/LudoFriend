<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class GuestSession extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'device_id',
        'guest_name',
        'token',
        'last_seen_at',
    ];

    protected $hidden = ['token'];

    protected function casts(): array
    {
        return [
            'last_seen_at' => 'datetime',
            // Opaque guest re-auth secret is encrypted at rest.
            'token' => 'encrypted',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
