# Ludo Friends — API Backend

Server-authoritative Laravel API for **Ludo Friends**, a production multiplayer
Ludo game (`com.arifurrahman.ludofriends`).

- **Framework:** Laravel 11, PHP 8.2+
- **Database:** MySQL (`ludo_friends`)
- **Auth:** Laravel Sanctum (bearer tokens for mobile; stateful cookies for the optional SPA)
- **Realtime:** Pusher protocol via Laravel Reverb (Soketi is wire-compatible)
- **Queues:** database driver

The server is the single source of truth for game state. Clients never decide
move outcomes; they send intents (which token to move) and the engine recomputes
everything against the verified ruleset.

---

## Verified Ludo ruleset (single-sourced in `config/ludo.php`)

- Ring = 52 cells (0..51). Start offsets: RED=0, GREEN=13, YELLOW=26, BLUE=39.
- Token relative position: `-1` base, `0..50` shared ring, `51..56` home column, `56` finished.
- `absolutePos(color, rel) = (start[color] + rel) % 52` for `rel` in `0..50`; otherwise `null`.
- A token leaves base **only** on a roll of 6 (`rel -1 -> 0`).
- A move of `dice` from `rel r` is legal only if `r + dice <= 56` (must land **exactly** on 56 to finish).
- **Capture:** landing on a ring cell occupied by an opponent sends it to base, **unless** the cell is safe. Safe = `{0, 8, 13, 21, 26, 34, 39, 47}`. No captures inside home columns.
- **Extra turn** if `dice == 6`, a capture happened, or a token reached home.
- **Three consecutive 6s** in one turn forfeits the third roll and ends the turn.
- **Winner** = all 4 of a color's tokens at `rel 56`.

These constants live only in `config/ludo.php` and are read by
`App\Services\Game\LudoRules`. Do not duplicate them elsewhere.

---

## Setup

```bash
# 1. Install dependencies
composer install

# 2. Environment
cp .env.example .env
php artisan key:generate
#   Edit .env: set DB_* for your MySQL `ludo_friends` database,
#   REVERB_* keys, and FACEBOOK_APP_ID / FACEBOOK_APP_SECRET if using FB login.

# 3. Create the schema (and demo data)
php artisan migrate
php artisan db:seed        # optional: admin user + demo leaderboard

# 4. Serve the API
php artisan serve          # http://127.0.0.1:8000

# 5. Realtime websocket server (Pusher protocol)
php artisan reverb:start   # ws://localhost:8080

# 6. Queue worker (database queue) — required for jobs & async broadcasts
php artisan queue:work

# 7. Scheduler (expire stale rooms, recompute leaderboards)
php artisan schedule:work
```

### Environment notes

| Variable | Purpose |
| --- | --- |
| `DB_DATABASE=ludo_friends` | MySQL schema name |
| `BROADCAST_CONNECTION=reverb` | Pusher-protocol broadcaster (Reverb/Soketi) |
| `REVERB_APP_ID/KEY/SECRET` | Reverb app credentials (also exposed to clients via `VITE_REVERB_*`) |
| `QUEUE_CONNECTION=database` | Jobs & queued broadcasts |
| `FACEBOOK_APP_ID/SECRET` | Facebook login + friends-using-app |
| `LUDO_TURN_TIMER_SECONDS` | Per-turn timer default |
| `LUDO_MAX_CONSECUTIVE_SIXES` | Forfeit threshold (default 3) |
| `RATE_LIMIT_AUTH/GAME/API` | Per-minute throttles for the route groups |

Never hardcode secrets — everything is read via `config()` / `.env`.

---

## Architecture

```
HTTP (routes/api.php, /api/v1)
  └── Controllers/Api/*           thin: authorize -> delegate -> resource
        ├── Form Requests          validate every input
        ├── Policies               RoomPolicy / MatchPolicy (ownership & seats)
        └── Services
              ├── Game/LudoRules            pure rules (unit-tested)
              ├── Game/GameEngineService    authoritative referee + anti-replay
              ├── RoomService               lobby, codes, capacity, start
              ├── MatchmakingService        queue + pairing + bot-fill
              └── FacebookService           token verify + friends (graceful)
Realtime (routes/channels.php)
  └── Events/* (ShouldBroadcast)  private channels room.{id} / match.{id}
Async (app/Jobs/*)                RecalculateLeaderboard, PersistMatchReplay, ExpireStaleRooms
```

### Anti-cheat / server authority

- `match_states` holds the canonical JSON snapshot with an optimistic `version`.
- Every action goes through `GameEngineService`, which validates **turn
  ownership + dice phase + legal move** and recomputes the result. The client's
  requested destination is ignored.
- `match_events` carries a monotonic per-match `seq` with a
  `unique(match_id, seq)` constraint. Replayed or out-of-order actions are
  rejected both by an explicit expected-seq check and at the database level.

---

## Testing

```bash
php artisan test
# or a focused suite
php artisan test --testsuite=Unit
```

Tests use an in-memory SQLite database (`phpunit.xml`) with `RefreshDatabase`.
`tests/Unit/LudoRulesTest.php` mirrors the nine verified rule scenarios;
`tests/Feature/GameMoveValidationTest.php` proves illegal/wrong-turn/replayed
actions are rejected end-to-end.

See [`API_REFERENCE.md`](API_REFERENCE.md) for every endpoint and
[`WEBSOCKETS.md`](WEBSOCKETS.md) for every broadcast event.
