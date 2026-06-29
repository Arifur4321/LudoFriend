# Deployment & production notes

## Environments & configuration

The client takes **all** environment config via `--dart-define` (never hardcoded):

| define | meaning | example |
|--------|---------|---------|
| `APP_ENV` | `dev` / `staging` / `prod` | `prod` |
| `API_BASE_URL` | REST base | `https://api.ludofriends.app/api/v1` |
| `WS_HOST` | WebSocket host | `ws.ludofriends.app` |
| `WS_PORT` | WebSocket port | `443` |
| `WS_TLS` | use wss | `true` |
| `WS_KEY` | **public** Reverb/Pusher key | `app-key` |
| `APP_ID` | runtime app id | `com.arifurrahman.ludofriends` |
| `ADS_ENABLED` / `IAP_ENABLED` / `FACEBOOK_ENABLED` | feature flags | `false` |

Example release build:

```bash
flutter build apk --release \
  --dart-define=APP_ENV=prod \
  --dart-define=API_BASE_URL=https://api.ludofriends.app/api/v1 \
  --dart-define=WS_HOST=ws.ludofriends.app --dart-define=WS_PORT=443 --dart-define=WS_TLS=true \
  --dart-define=WS_KEY=your_public_key
```

## App identity

Set the Android `applicationId` / iOS bundle id when generating platforms:
`flutter create --org com.arifurrahman --project-name ludo_friends .`. Change the
org to re-brand. App icons can be produced from `assets/svg/app_icon.svg` via
`flutter_launcher_icons` (see `assets/README_ASSETS.md`).

## Backend

```bash
cd backend
composer install
cp .env.example .env && php artisan key:generate
# configure DB_* (MySQL) and REVERB_* in .env
php artisan migrate
php artisan reverb:start      # WebSocket server (or run Soketi)
php artisan queue:work        # leaderboard recompute, replay persistence
php artisan serve             # or php-fpm + nginx in production
```

Production: run `reverb`, `queue:work` and the HTTP server under a supervisor
(systemd / Supervisor), terminate TLS at nginx, and point `WS_TLS=true`,
`WS_PORT=443` at the proxied WebSocket. Rate limits are configured per route
(auth, room joins, matchmaking, game actions).

## Enabling optional features

- **Facebook login** (off by default to keep launch crash-free): add
  `flutter_facebook_auth` to `app/pubspec.yaml`, configure the native Facebook
  App ID (Android `AndroidManifest.xml` meta-data + `strings.xml`, iOS
  `Info.plist`), restore the plugin call in
  `services/facebook/facebook_auth_service.dart`, and build with
  `--dart-define=FACEBOOK_ENABLED=true`. Friend discovery falls back to invite
  link / room code / deep link when `user_friends` permission is unavailable.
- **Ads / IAP**: implementations are stubs returning disabled. Wire AdMob /
  `in_app_purchase` in `services/ads` and `services/iap`, then flip
  `ADS_ENABLED` / `IAP_ENABLED`. Keep purchases cosmetic (no pay-to-win).

## Security checklist (online play)

- Sanctum bearer tokens stored in platform secure storage.
- Server validates turn ownership, dice state and the full move path; the client
  only sends *which token* to move.
- `match_events.seq` is monotonic & unique → replayed/out-of-order events are
  rejected.
- Rate limiting on auth/login, room joins, matchmaking and game actions.
- Players cannot join full rooms or control other players' tokens.

## Crash / analytics

`services/analytics/AnalyticsService` is the single hook — swap the provider for
Firebase Crashlytics / Sentry. `FlutterError.onError` already routes framework
errors there.
