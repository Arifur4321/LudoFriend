# Ludo Friends

A beautiful, animated, **online/offline multiplayer Ludo-style game** — original art and brand identity (not affiliated with or derived from any existing Ludo product).

| Layer | Tech |
|-------|------|
| Mobile app | Flutter (Riverpod, go_router) — Android first, iOS-ready |
| Backend API | Laravel 11 + Sanctum |
| Database | MySQL |
| Realtime | Pusher-protocol WebSockets (Laravel Reverb / Soketi compatible) |
| Auth | Email/password, Guest, Facebook |

> App / package id: **`com.arifurrahman.ludofriends`** — configurable via flavors & `--dart-define` (see `app/lib/core/config/`).

## Monorepo layout

```
LudoFriend/
├── app/          # Flutter client (game engine + UI + services)
├── backend/      # Laravel API (auth, rooms, matchmaking, websockets, validation)
└── docs/         # API, WebSocket, architecture, rules, deployment, assets
```

## What works today (Phase 1, runnable now)

- **Pure-Dart, fully tested Ludo engine** — `app/lib/game_engine/` (rules verified independently before porting).
- **Offline play**: pass-and-play local multiplayer (2–4 players on one device).
- **Bot play**: modular AI opponents with legal, prioritized moves.
- **Guest play**: generated guest name, local progress.
- Animated board (CustomPainter), dice, token movement, capture, winner confetti.
- All 19 screens; premium colorful original theme; original SVG assets.

## Scaffolded for Phases 2–4

- Online room create/join, random matchmaking, server-authoritative moves (Laravel + WebSockets).
- Facebook login + friend invite / room-code / deep-link fallback.
- Match history, leaderboard, profile stats.
- Sounds, monetization hooks (ads/IAP, **disabled by default**), localization (en + it/bn/hi structure).

## Quick start

**App**
```bash
cd app
flutter create .            # generate android/ios/web platform folders (keeps lib/)
flutter pub get
flutter test                # run the game-engine + widget tests
flutter run                 # play offline / vs bot / guest
```

**Backend** — see `backend/README.md`:
```bash
cd backend
composer install
cp .env.example .env && php artisan key:generate
php artisan migrate
php artisan reverb:start &   # websockets
php artisan queue:work &
php artisan serve
```

See `docs/` for full API, WebSocket, architecture, rules and deployment notes.

## Originality & licensing

All visual assets, board design, colors, icons, characters, animations and brand
identity are **original** and created for this project. No third-party game's UI,
art, sounds or trademarks are copied. Facebook integration uses the official SDK
button at runtime (no Facebook logo is embedded as an asset).
