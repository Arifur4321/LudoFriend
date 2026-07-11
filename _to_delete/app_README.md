# Ludo Friends — Flutter app

Original, animated Ludo-style game client. Riverpod + go_router, a pure-Dart
tested game engine, and a premium original visual identity.

## Requirements

- Flutter (latest stable) and Dart — `flutter --version`
- Android SDK (Android first) / Xcode (iOS-ready)

## First-time setup

The repo ships `lib/`, `assets/`, `pubspec.yaml`, tests and config. Generate the
native platform folders, then fetch packages:

```bash
cd app

# Generates android/ ios/ (keeps your lib/, assets/, pubspec.yaml untouched).
flutter create --org com.arifurrahman --project-name ludo_friends \
  --platforms=android,ios .

flutter pub get
```

> `flutter create .` only *adds* missing platform files — it does not overwrite
> the existing `lib/`, `pubspec.yaml`, `assets/` or `analysis_options.yaml`.

## Run

```bash
flutter run                      # default = dev environment
# or point at your backend / websocket:
flutter run \
  --dart-define=APP_ENV=staging \
  --dart-define=API_BASE_URL=https://staging.api.ludofriends.app/api/v1 \
  --dart-define=WS_HOST=staging.ws.ludofriends.app \
  --dart-define=WS_KEY=your_public_reverb_key
```

Offline play (pass-and-play, bots, guest, private-room-vs-bots) needs **no
backend**. Online matchmaking / real multiplayer needs the Laravel backend +
WebSocket server running (see `../backend/README.md`).

## Test, format, analyze

```bash
flutter test          # game-engine, dice, board, serialization, bot, widget, repo tests
dart format .
flutter analyze
```

The game engine (`lib/game_engine/`) is pure Dart with **no Flutter imports**, so
its tests run fast and deterministically.

## Configurable identity

- **App id**: `com.arifurrahman.ludofriends` — set per-platform by the
  `flutter create --org` above (Android `applicationId`, iOS bundle id). The
  runtime-visible id is also exposed via `AppConfig.appId`
  (`--dart-define=APP_ID=...`).
- **No hardcoded URLs/secrets**: all environment config flows through
  `--dart-define` (`lib/core/config/app_config.dart`).

## Project structure

```
lib/
├── main.dart, app.dart            # entry + MaterialApp.router
├── core/                          # config, constants, errors, network, storage, router, di, utils
├── game_engine/                   # PURE DART, fully tested
│   ├── models/  rules/  bot/      # tokens, state, dice, rule config, bot strategy
│   ├── board_layout.dart          # 52-ring + home columns + grid coords
│   └── ludo_engine.dart           # legal moves, captures, turns, winner
├── features/
│   ├── splash/ onboarding/ home/  # entry + main menu + play options
│   ├── auth/                      # guest/login/register (+ FB opt-in)
│   ├── game/                      # board painter, dice, tokens, animations, controller
│   ├── matchmaking/ room/         # online + private room (offline bot-fill playable)
│   ├── profile/ leaderboard/ settings/ help/ common/
├── services/                      # audio, ads, iap, analytics, realtime ws, facebook
├── shared/                        # theme + reusable widgets
└── l10n/                          # en (+ it/bn/hi) localization scaffolding
```

## Status by phase

- **Phase 1 (done, runnable):** offline local 2–4 player, vs-bot, guest, full
  animated board/dice/tokens/capture/winner, all 19 screens.
- **Phase 2 (scaffolded):** REST client, Pusher/Reverb WebSocket client with
  reconnect, room/matchmaking screens wired to endpoints.
- **Phase 3 (scaffolded):** Facebook login opt-in, friends/invite fallback,
  match history, leaderboard.
- **Phase 4:** sounds (placeholder SFX included), monetization hooks
  (off by default), production hardening.

See `../docs/` for architecture, rules, deployment and API/WebSocket references.
