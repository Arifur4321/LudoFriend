# Run & Test — Coin Economy

The coin-economy code was written and statically reviewed, but **could not be
compiled or test-run in the authoring environment** (no PHP/Composer/Flutter
there). Run the steps below on your machine to migrate, test, and launch.

## Backend (Laravel 11)

```bash
cd backend
composer install
cp .env.example .env          # if you don't have one yet
php artisan key:generate

# Point DB_* at your database, then:
php artisan migrate           # applies the new 2026_07_06_* economy migrations

# Run the test suite (uses in-memory SQLite from phpunit.xml):
php artisan test
```

New economy tests (all under `backend/tests/Feature/`):

- `WalletServiceTest` — credit/debit, insufficient-funds guard, ledger integrity, idempotent signup bonus
- `FreeSpinTest` — hourly cooldown (spin, blocked, then available after `travel(61)->minutes()`), reward within set, weighting bounded
- `StakedMatchTest` — stake escrowed at start, winner takes the pot, atomic roll-back when unaffordable, 422 guards
- `TeamMatchPayoutTest` — 2v2 pot split (each of 4 pays 200, winning pair gets 400 each)
- `EconomyRefundAndBoardsTest` — abort refunds every stake, `/boards` hides the free tier, Google login validation

Optional static lint (if you have PHP tooling): `./vendor/bin/pint --test`.

## Flutter app

```bash
cd app
flutter pub get               # pulls in sqflite + path (on-device cache)
flutter analyze
flutter test                  # includes app/test/economy/*
```

The on-device SQLite cache uses `sqflite`, which is a mobile plugin — it only
runs on a device/emulator, not in `flutter test`. Tests use the in-memory cache
fallback automatically (the default `localCacheProvider` binding), so they don't
need the plugin.

Run against a local backend (Android emulator reaches the host at 10.0.2.2):

```bash
flutter run \
  --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
```

## Enabling social login (when you have credentials)

Backend `.env`:

```
GOOGLE_LOGIN_ENABLED=true
GOOGLE_CLIENT_ID_WEB=...        # add android/ios client ids too
GOOGLE_CLIENT_ID_ANDROID=...
GOOGLE_CLIENT_ID_IOS=...

FACEBOOK_LOGIN_ENABLED=true
FACEBOOK_APP_ID=...
FACEBOOK_APP_SECRET=...
```

Flutter build defines: `--dart-define=GOOGLE_ENABLED=true --dart-define=FACEBOOK_ENABLED=true`
(plus the platform Google client ids and the native Facebook setup). The login
buttons and `/auth/google` + `/auth/facebook` are already wired — they just stay
disabled until these are set.

## Enabling the coin store (when you have store accounts)

Backend `.env`:

```
LUDO_STORE_ENABLED=true
LUDO_STORE_VERIFY_RECEIPTS=true      # verify real receipts before crediting
APPLE_IAP_SHARED_SECRET=...          # iOS verification (implemented)
LUDO_ANDROID_PACKAGE=com.ludofriends.app
```

Product ids live in `config/economy.php → store.packs` and must match the
App Store / Play Console entries. Google Play verification needs a service
account (add in `StoreService::verifyReceipt`). With `LUDO_STORE_VERIFY_RECEIPTS=false`,
purchases are credited only in `local`/`testing` and recorded as `pending`
elsewhere — so no coins are granted for unverified receipts in production.

## Tuning the economy

All in `backend/config/economy.php` (or the matching env vars):

- `tiers` — board stakes and identities
- `free_spin.segments` — wheel rewards + weights
- `free_spin.interval_minutes` — spin cooldown (default 60; `LUDO_FREE_SPIN_INTERVAL_MINUTES`)
- `store.packs` — coin packs
- `house_rake_bps` — commission in basis points (0 = pure winner-takes-all)
- `match_idle_abort_minutes` — when an idle match auto-aborts + refunds

## Activating staked online play

The backend is ready. To go live you need to finish the **Phase-2 online
room/match flow** on the client (replace the local `RoomDraft` in
`app/lib/features/room/` with server rooms via `POST /rooms` carrying
`board_tier`/`team_mode`, and drive rolls/moves through the existing
`/matches/*` endpoints + Reverb broadcasts). Once a room is created with a
staked `board_tier`, the server escrows stakes at `start` and pays the pot at
finish automatically.
