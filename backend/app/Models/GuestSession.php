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
            // NOTE: `token` is intentionally NOT encrypted. It is a high-entropy
            // opaque secret (Str::random(64)) that is only ever written, never
            // read (guest re-auth is by device_id + Sanctum). An `encrypted`
            // cast produced a ~250-char blob that overflowed the column on
            // MySQL and broke guest login; storing the random value as-is keeps
            // it opaque, unique-indexable, and comfortably within the column.
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
