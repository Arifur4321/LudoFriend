# Ludo Friends — WebSockets / Broadcasting

Realtime uses the **Pusher protocol** via **Laravel Reverb** (Soketi is
wire-compatible). Clients connect with the Pusher SDK configured from the
`VITE_REVERB_*` values and authenticate **private** channels through the
Sanctum-protected endpoint `POST /broadcasting/auth`.

## Channels

| Channel | Who may subscribe | Authorized in |
| --- | --- | --- |
| `private-room.{roomId}` | seated players; any authenticated user if the room is `public` | `routes/channels.php` |
| `private-match.{matchId}` | match participants only | `routes/channels.php` |

> Pusher prefixes private channels with `private-`. The server-side channel
> names are `room.{roomId}` and `match.{matchId}`.

All events expose a stable name via `broadcastAs()` (e.g. `game.dice_rolled`),
so clients bind to that name rather than the PHP class.

---

## Room channel events — `private-room.{roomId}`

### `room.player_joined`
Trigger: a player joins the lobby (`RoomService@join`).
Payload:
```json
{ "room_id": 7, "player": { "id": 21, "seat": 1, "color": "green", "is_bot": false, "is_ready": false, "user": { "id": 42, "name": "Ari", "avatar": null } } }
```

### `room.player_left`
Trigger: a player leaves (`RoomService@leave`).
Payload:
```json
{ "room_id": 7, "room_player_id": 21, "user_id": 42 }
```

### `room.ready_changed`
Trigger: a player toggles readiness (`RoomController@ready`).
Payload:
```json
{ "room_id": 7, "room_player_id": 21, "is_ready": true }
```

### `game.started`
Trigger: the host starts the match (`RoomService@start`).
Payload:
```json
{ "room_id": 7, "match_id": 19, "turn_order": ["red", "yellow"] }
```
Clients should now switch to the `private-match.{match_id}` channel.

---

## Match channel events — `private-match.{matchId}`

### `game.dice_rolled`
Trigger: a player rolls (`GameEngineService@roll`).
Payload:
```json
{ "match_id": 19, "color": "red", "dice": 6, "forfeited": false }
```
`forfeited: true` indicates the 3rd-consecutive-six rule fired (no move applied).

### `game.token_moved`
Trigger: a validated move is applied (`GameEngineService@move`).
Payload:
```json
{ "match_id": 19, "color": "red", "token": 0, "from": -1, "to": 0, "captured": [] }
```
Positions use the relative convention (`-1` base … `56` home). Captured entries
(when present) are `{ "color": "green", "token": 2 }`.

### `game.turn_changed`
Trigger: the turn advances to the next color (`GameEngineService@advanceTurn`).
Payload:
```json
{ "match_id": 19, "turn": "yellow" }
```

### `game.player_disconnected`
Trigger: a participant drops; a grace window starts.
Payload:
```json
{ "match_id": 19, "color": "red", "grace_seconds": 60 }
```

### `game.player_reconnected`
Trigger: a participant reconnects (`GameController@reconnect`).
Payload:
```json
{ "match_id": 19, "color": "red" }
```

### `game.ended`
Trigger: a color completes all four tokens (`GameEngineService@finalizeMatch`).
Payload:
```json
{ "match_id": 19, "winner_color": "red", "winner_user_id": 42 }
```

---

## Client flow summary

1. Authenticate (`/api/v1/auth/*`) → obtain bearer token.
2. Subscribe to `private-room.{roomId}` after creating/joining a room.
3. On `game.started`, subscribe to `private-match.{matchId}` and `GET /matches/{id}/state`.
4. Send actions over HTTP (`/roll`, `/move`); apply the authoritative `state` from
   the response and reconcile against the broadcast events (which other players
   also receive).
5. On `game.ended`, show results; on disconnect/reconnect, call `/reconnect` to
   resync the full snapshot.

> The HTTP response to your own action already contains the new `state`; the
> broadcast is primarily for the **other** participants. Treat the server
> `state` (and its `version`/`seq`) as canonical and never advance the board
> locally without it.
