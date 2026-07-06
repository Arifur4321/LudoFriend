<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Purchase extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'product_id',
        'platform',
        'receipt',
        'status',
        'coins_awarded',
        'verified_at',
        'meta',
    ];

    protected $hidden = ['receipt'];

    protected function casts(): array
    {
        return [
            'coins_awarded' => 'integer',
            'verified_at' => 'datetime',
            'meta' => 'array',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
