# Ludo Friends — API Reference

Base URL: `/api/v1`
All responses are JSON. Authenticated endpoints require
`Authorization: Bearer <sanctum-token>`.

Common error shapes:

| Status | Meaning | Body |
| --- | --- | --- |
| 401 | Unauthenticated | `{ "message": "Unauthenticated." }` |
| 403 | Forbidden (policy / banned / not admin) | `{ "message": "...", "reason"? }` |
| 404 | Not found (room/match) | `{ "message": "..." }` |
| 409 | Conflict (e.g. room full) | `{ "message": "Room is full." }` |
| 422 | Validation / illegal game action | `{ "message": "...", "errors"? }` |
| 429 | Rate limited | `{ "message": "Too Many Attempts." }` |

Throttles: auth `6/min`, game+matchmaking+room-join `30/min`, other authed `60/min`.

---

## Auth

### POST `/auth/register`
Auth: none · Throttle: 6/min
Request:
```json
{ "name": "Arifur", "email": "a@x.com", "password": "Passw0rd!", "password_confirmation": "Passw0rd!", "avatar": null }
```
Response `201`:
```json
{ "token": "…", "token_type": "Bearer", "user": { "id": 1, "name": "Arifur", "is_guest": false, "profile": { … } } }
```
Errors: 422 (email taken, weak password).

### POST `/auth/login`
Auth: none · Throttle: 6/min
Request: `{ "email": "a@x.com", "password": "Passw0rd!", "device_name": "iphone" }`
Response `200`: `{ "token": "…", "token_type": "Bearer", "user": { … } }`
Errors: 422 (bad credentials / banned).

### POST `/auth/guest`
Auth: none · Throttle: 6/min
Request: `{ "device_id": "install-uuid", "guest_name": "Anon", "avatar": null }`
Response `200`: `{ "token": "…", "user": { "is_guest": true, … } }`
Behavior: the same `device_id` reuses its existing guest account.
Errors: 422 (missing `device_id`).

### POST `/auth/facebook`
Auth: none · Throttle: 6/min
Request: `{ "access_token": "<fb-user-token>", "device_name": "android" }`
Response `200`: `{ "token": "…", "user": { … } }`
Behavior: verifies the token against the configured app, links/creates a user.
Errors: 422 (invalid token), 500 (FB credentials unset).

### POST `/auth/logout`
Auth: bearer
Response `200`: `{ "message": "Logged out." }` (revokes the current token).

### GET `/me`
Auth: bearer
Response `200`: `UserResource` for the authenticated user.

---

## Profile

### GET `/profile`
Auth: bearer · Response `200`: `ProfileResource`.

### PUT `/profile`
Auth: bearer
Request: `{ "display_name": "Ari", "avatar": "https://…" }`
Response `200`: `ProfileResource`.

### GET `/profile/stats`
Auth: bearer
Response `200`:
```json
{ "data": { "matches_played": 12, "wins": 7, "losses": 5, "win_rate": 0.5833, "best_streak": 4, "current_streak": 1, "coins": 700 } }
```

### GET `/profile/matches`
Auth: bearer · Response `200`: paginated `MatchResource` collection (the caller's matches).

---

## Friends

### GET `/friends`
Auth: bearer · Response `200`: `{ "data": [ UserResource, … ] }` (accepted friends).

### POST `/friends/invite`
Auth: bearer
Request: `{ "friend_user_id": 42, "source": "facebook" }`  (`source` ∈ facebook|code|link)
Response `201`: `{ "message": "Invite sent.", "data": { "id": 9, "status": "pending" } }`
Errors: 422 (self-invite, unknown user).

### POST `/friends/accept`
Auth: bearer
Request: `{ "code": "42" }`  (friend code; resolves to the inviter's user id)
Response `200`: `{ "message": "Friend added." }`
Errors: 422 (invalid code).

---

## Rooms

### POST `/rooms`
Auth: bearer · Throttle: 60/min
Request:
```json
{ "mode": "4p", "visibility": "private", "bot_fill": false, "turn_timer_seconds": 20, "settings": {} }
```
Response `201`: `RoomResource` (caller seated at seat 0, `status: "lobby"`).

### POST `/rooms/join`
Auth: bearer · Throttle: 30/min
Request: `{ "code": "ABC123" }`
Response `200`: `RoomResource`.
Errors: 409 (`Room is full.` / not accepting players), 422 (unknown code).

### GET `/rooms/{room}`
Auth: bearer (seated, or any user for public rooms — `RoomPolicy@view`)
Response `200`: `RoomResource` with players and current match id.

### POST `/rooms/{room}/leave`
Auth: bearer (seated — `RoomPolicy@participate`)
Response `200`: `{ "message": "Left room." }`
Behavior: host-leaving transfers host; empty room is cancelled.

### POST `/rooms/{room}/ready`
Auth: bearer (seated)
Request: `{ "ready": true }`
Response `200`: `{ "message": "Ready status updated.", "is_ready": true }`

### POST `/rooms/{room}/start`
Auth: bearer (**host only** — `RoomPolicy@start`)
Response `201`: `MatchResource` (with initial authoritative `state`).
Behavior: optionally bot-fills, requires ≥2 players and all humans ready.
Errors: 403 (not host), 422 (not enough players / not all ready / already started).

---

## Matchmaking

### POST `/matchmaking/enqueue`
Auth: bearer · Throttle: 30/min
Request: `{ "mode": "2p" }`
Response `201`: `{ "data": { "ticket_id": 5, "status": "queued|matched", "room_id": null } }`
Behavior: pairs the oldest queued players into a public room when enough are waiting.

### POST `/matchmaking/cancel`
Auth: bearer · Response `200`: `{ "message": "Matchmaking cancelled." }`

### GET `/matchmaking/status`
Auth: bearer
Response `200`: `{ "data": { "status": "queued|matched|none", "room_code": "ABC123", "room_id": 7 } }`

---

## Game (server-authoritative)

The match is identified by `{match}` (the `matches` table id).
All actions require the caller to own the acting color (`MatchPolicy@act`) and
the engine additionally enforces turn + phase + legality.

### GET `/matches/{match}/state`
Auth: bearer (participant — `MatchPolicy@view`)
Response `200`: `MatchResource` including:
```json
{
  "id": 7, "mode": "4p", "status": "active",
  "state": {
    "tokens": { "red": [-1,-1,-1,-1], "green": [0,3,-1,-1] },
    "turn": "red", "phase": "awaiting_roll", "dice": null,
    "consecutive_sixes": 0, "finished": { "red": false, … }, "winner": null, "seq": 12
  },
  "version": 12
}
```

### POST `/matches/{match}/roll`
Auth: bearer (owns color)
Request: `{ "color": "red" }`
Response `200`:
```json
{ "data": {
  "dice": 6, "forfeited": false,
  "legal_moves": [ { "token": 0, "from": -1, "to": 0, "captures": [] } ],
  "turn_passed": false, "state": { … }
} }
```
Notes:
- `forfeited: true` when this was the 3rd consecutive 6 (move skipped, turn ends).
- `legal_moves: []` + `turn_passed: true` when no move is possible (non-6).
- A 6 with no legal move keeps the turn (`turn_passed: false`).
Errors: 403 (not your color), 422 (`It is not your turn.` / wrong phase).

### POST `/matches/{match}/move`
Auth: bearer (owns color)
Request:
```json
{ "color": "red", "token": 0, "seq": 13 }
```
`token` is which of the four tokens (0..3) to move; `seq` is the optional
client-asserted next sequence number (anti-replay). The destination and any
capture are computed **server-side**.
Response `200`:
```json
{ "data": {
  "from": -1, "to": 0,
  "captured": [ { "color": "green", "token": 2 } ],
  "finished": false, "extra_turn": true, "winner": null,
  "turn_passed": false, "state": { … }
} }
```
Errors: 403 (not your color), 422 (`Illegal move for the current dice value.` /
`It is not your turn.` / `Out-of-order or replayed action …` / wrong phase).

### POST `/matches/{match}/reconnect`
Auth: bearer (participant)
Response `200`: `{ "data": { …MatchResource with full state… } }`
Behavior: stamps `reconnected_at`, broadcasts `game.player_reconnected`.

---

## Leaderboard

### GET `/leaderboard`
Auth: bearer
Query: `period=all_time|weekly` (default all_time), `limit=1..100` (default 50)
Response `200`: collection of `LeaderboardResource`:
```json
{ "data": [ { "rank": 1, "user": { "id": 3, "name": "Ari" }, "period": "all_time", "wins": 40, "games": 80, "rating": 1400 } ] }
```

---

## Admin (requires `admin` ability — `AdminOnly` middleware)

### GET `/admin/users`  — query `q` (search) · paginated `UserResource`.
### GET `/admin/matches` — paginated `MatchResource`.
### GET `/admin/reports` — paginated reports with reporter/reported.
### POST `/admin/users/{user}/ban` — body `{ "reason": "Cheating" }`; revokes tokens.
### POST `/admin/users/{user}/unban` — lifts the ban.

---

## Reports

### POST `/reports`
Auth: bearer
Request:
```json
{ "reported_user_id": 42, "match_id": 7, "reason": "cheating", "details": "…" }
```
`reason` ∈ `cheating|abuse|harassment|afk|other`.
Response `201`: `{ "message": "Report submitted.", "data": { "id": 11 } }`
Errors: 422 (reporting yourself, unknown user/match).
