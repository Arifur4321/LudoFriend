# Architecture

Ludo Friends is a monorepo with a Flutter client and a Laravel API, sharing one
authoritative rule set.

```
┌────────────────────────┐        REST (Sanctum)        ┌────────────────────────┐
│      Flutter app       │ ───────────────────────────▶ │     Laravel API        │
│                        │ ◀─────────────────────────── │  (server-authoritative)│
│  game_engine (pure)    │     Pusher/Reverb WebSocket   │  LudoRules (mirror)    │
└────────────────────────┘ ◀───────── events ────────── └─────────┬──────────────┘
                                                                   │
                                                              MySQL (state, events,
                                                              users, rooms, stats)
```

## Client (Flutter)

Feature-first structure with a hard separation between the **game engine** and
the **UI**.

- **`game_engine/` — pure Dart, zero Flutter imports.** Immutable `GameState`;
  every transition returns a new state. Dice values are injected (no internal
  randomness) so games are deterministic and unit-testable. This is the single
  source of truth for the rules and is mirrored server-side.
- **State management: Riverpod.** `GameController` (a `StateNotifier`) wraps the
  engine, sequences animations, runs bots, and plays sound. Services
  (`audio`, `realtime`, `auth`, …) are exposed as providers; `prefsProvider` is
  overridden in `main()` after async init.
- **Rendering.** The board is a `CustomPainter` (yards, cross track, home lanes,
  centre, safe stars). Tokens/dice are widgets overlaid in a `Stack`; movement
  is animated cell-by-cell along the engine-provided `path`.
- **Navigation.** `go_router` with fade/slide transitions (`core/router/`).
- **Config.** `AppConfig` reads everything from `--dart-define` — no hardcoded
  URLs or secrets. Per-environment defaults for dev/staging/prod.
- **Errors.** Typed `Failure`s; `DioClient` normalises network/HTTP errors;
  loading/empty/no-internet/reconnect states have dedicated widgets.

## Backend (Laravel)

Layered and server-authoritative (see `../backend/`):

- **Auth**: Sanctum tokens; email/password, guest, Facebook.
- **Services**: `LudoRules` (pure rules, mirrors the Dart engine, single-sourced
  from `config/ludo.php`), `GameEngineService` (validates turn ownership + dice
  state + legal move, appends monotonic `match_events`, persists versioned
  `match_states`, broadcasts), `RoomService`, `MatchmakingService`,
  `FacebookService`.
- **Realtime**: `ShouldBroadcast` events on private `room.{id}` / `match.{id}`
  channels (Reverb/Soketi/laravel-websockets).
- **Data**: 15+ domain tables incl. `match_events` (unique `seq` → anti-replay)
  and `match_states` (authoritative snapshot).
- **Policies + rate limiting** on auth, room joins, matchmaking, game actions.

## Why the engine is duplicated (Dart + PHP)

The client runs the engine for instant, smooth offline/optimistic play; the
server re-runs the same rules to validate every online move. Both read identical
constants (safe cells, start offsets, ring size), so they never diverge.
