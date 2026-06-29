<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    use HasApiTokens, HasFactory, Notifiable;

    protected $fillable = [
        'name',
        'email',
        'password',
        'avatar',
        'is_guest',
        'is_admin',
        'is_banned',
        'banned_reason',
        'banned_at',
    ];

    protected $hidden = [
        'password',
        'remember_token',
    ];

    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'banned_at' => 'datetime',
            'password' => 'hashed',
            'is_guest' => 'boolean',
            'is_admin' => 'boolean',
            'is_banned' => 'boolean',
        ];
    }

    /* -----------------------------------------------------------------
     | Scopes
     | ----------------------------------------------------------------- */

    /** Only guest accounts. */
    public function scopeGuests(Builder $query): Builder
    {
        return $query->where('is_guest', true);
    }

    /** Only registered (non-guest) accounts. */
    public function scopeRegistered(Builder $query): Builder
    {
        return $query->where('is_guest', false);
    }

    /** Only accounts that are not banned. */
    public function scopeNotBanned(Builder $query): Builder
    {
        return $query->where('is_banned', false);
    }

    /** Only banned accounts. */
    public function scopeBanned(Builder $query): Builder
    {
        return $query->where('is_banned', true);
    }

    /* -----------------------------------------------------------------
     | Helpers
     | ----------------------------------------------------------------- */

    public function isGuest(): bool
    {
        return (bool) $this->is_guest;
    }

    public function isBanned(): bool
    {
        return (bool) $this->is_banned;
    }

    public function isAdmin(): bool
    {
        return (bool) $this->is_admin;
    }

    /* -----------------------------------------------------------------
     | Relationships
     | ----------------------------------------------------------------- */

    public function profile(): HasOne
    {
        return $this->hasOne(PlayerProfile::class);
    }

    public function guestSession(): HasOne
    {
        return $this->hasOne(GuestSession::class);
    }

    public function socialAccounts(): HasMany
    {
        return $this->hasMany(SocialAccount::class);
    }

    public function stats(): HasMany
    {
        return $this->hasMany(PlayerStat::class);
    }

    /** Friendships this user initiated. */
    public function friends(): HasMany
    {
        return $this->hasMany(FriendLink::class, 'user_id');
    }

    public function hostedRooms(): HasMany
    {
        return $this->hasMany(GameRoom::class, 'host_user_id');
    }

    public function roomSeats(): HasMany
    {
        return $this->hasMany(GameRoomPlayer::class);
    }

    public function matchSeats(): HasMany
    {
        return $this->hasMany(MatchPlayer::class);
    }

    public function purchases(): HasMany
    {
        return $this->hasMany(Purchase::class);
    }

    public function reportsMade(): HasMany
    {
        return $this->hasMany(Report::class, 'reporter_user_id');
    }
}
