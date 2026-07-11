# Ludo Friends

An original, animated **online + offline multiplayer Ludo** game.
Flutter client + Laravel (API & realtime) monorepo.

- **Android package:** `com.arifurrahman.ludofriends`
- **Production API:** https://db.ludogame.dronescan.pro/api/v1
- **WebSockets:** `wss://ws.ludogame.dronescan.pro`
- **Deploy branch:** `claude-fb` · **Rollback branch:** `claude-3d`
- **Contact:** hatbazar627@gmail.com

---

## 1. Repository layout

```
LudoFriend/
├── app/                 # Flutter client (Android / iOS)
│   ├── lib/             # feature-first: core/, features/*, services/*, shared/*
│   ├── android/         # Android project (FB SDK + Google Sign-In)
│   └── pubspec.yaml
├── backend/             # Laravel API + Reverb (WebSockets)
│   ├── app/  config/  routes/  database/  resources/views/legal  tests/
│   └── .env.example
├── docs/store-assets/   # Play Store icon + feature graphic
└── README.md            # (this file — single source of docs)
```

## 2. Features

Guest / Email / **Facebook** / **Google** sign-in · real-time multiplayer rooms &
matchmaking (Reverb) · friends, invites & presence · server-authoritative game
engine · in-game chat + emoji · coins / wallet / hourly free-spin economy ·
leaderboard · bot fallback.

## 3. Tech stack

- **Client:** Flutter (Riverpod, go_router, dio, web_socket_channel,
  flutter_svg, google_fonts, flutter_facebook_auth, google_sign_in,
  url_launcher).
- **Backend:** Laravel 11, Sanctum (bearer tokens), Reverb (Pusher protocol),
  MySQL, Redis (cache/queue/session in prod).

---

## 4. Flutter client

### Setup
```bash
cd app
flutter pub get
dart run flutter_launcher_icons     # (re)generate launcher icons from assets/images/app_icon.png
```

### Run on a USB device (production backend)
```bash
flutter run \
  --dart-define=APP_ENV=prod \
  --dart-define=API_BASE_URL=https://db.ludogame.dronescan.pro/api/v1 \
  --dart-define=WS_HOST=ws.ludogame.dronescan.pro \
  --dart-define=WS_PORT=443 \
  --dart-define=WS_TLS=true \
  --dart-define=WS_KEY=ludo-prod-key-2026 \
  --dart-define=FACEBOOK_ENABLED=true \
  --dart-define=GOOGLE_ENABLED=true \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=YOUR_WEB_OAUTH_CLIENT_ID
```

> **`GOOGLE_SERVER_CLIENT_ID` is required for Google login.** It must be the
> **Web** OAuth client id and must equal `GOOGLE_CLIENT_ID_WEB` on the server
> (that id is the token audience the backend verifies). Without it, Android does
> not return a usable ID token. iOS later: add `GOOGLE_IOS_CLIENT_ID`.

### `--dart-define` reference

| Define | Meaning |
|--------|---------|
| `APP_ENV` | `dev` / `staging` / `prod` |
| `API_BASE_URL` | REST base incl. `/api/v1` |
| `WS_HOST` `WS_PORT` `WS_TLS` `WS_KEY` | Reverb client connection |
| `FACEBOOK_ENABLED` / `GOOGLE_ENABLED` | show the social buttons |
| `GOOGLE_SERVER_CLIENT_ID` | **Web** OAuth client id (Google ID-token audience) |

---

## 5. Laravel backend

### Setup
```bash
cd backend
composer install --optimize-autoloader
cp .env.example .env      # then edit (template below)
php artisan key:generate
php artisan migrate --force
php artisan optimize:clear && php artisan config:cache && php artisan route:cache && php artisan event:cache
```

### MySQL (placeholders only)
```sql
CREATE DATABASE ludo_friends CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'ludo_user'@'127.0.0.1' IDENTIFIED BY 'CHANGE_ME_STRONG_PASSWORD';
GRANT ALL PRIVILEGES ON ludo_friends.* TO 'ludo_user'@'127.0.0.1';
FLUSH PRIVILEGES;
```

### Production `.env` (never commit real secrets)
```
APP_NAME="Ludo Friends"
APP_ENV=production
APP_KEY=                       # php artisan key:generate
APP_DEBUG=false
APP_URL=https://db.ludogame.dronescan.pro

DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_DATABASE=ludo_friends
DB_USERNAME=ludo_user
DB_PASSWORD=                   # server only

CACHE_STORE=redis
QUEUE_CONNECTION=redis
SESSION_DRIVER=redis
REDIS_CLIENT=phpredis
REDIS_HOST=127.0.0.1

# Reverb — server listens on 8081; Nginx terminates TLS on 443
BROADCAST_CONNECTION=reverb
REVERB_APP_ID=ludofriends
REVERB_APP_KEY=ludo-prod-key-2026
REVERB_APP_SECRET=             # server only
REVERB_HOST=ws.ludogame.dronescan.pro
REVERB_PORT=443
REVERB_SCHEME=https
REVERB_SERVER_HOST=127.0.0.1
REVERB_SERVER_PORT=8081
REVERB_SCALING_ENABLED=true

# Facebook Login
FACEBOOK_LOGIN_ENABLED=true
FACEBOOK_APP_ID=2582636912564874
FACEBOOK_APP_SECRET=          # server only
FACEBOOK_GRAPH_VERSION=v19.0

# Google Sign-In (identity only — no Gmail/Drive/Contacts scopes)
GOOGLE_LOGIN_ENABLED=true
GOOGLE_CLIENT_ID_WEB=         # Web OAuth client id (== app GOOGLE_SERVER_CLIENT_ID)
GOOGLE_CLIENT_ID_ANDROID=     # Android OAuth client id
GOOGLE_CLIENT_ID_IOS=

CORS_ALLOWED_ORIGINS=https://db.ludogame.dronescan.pro
SANCTUM_TOKEN_EXPIRATION=20160
```

### Key API routes
`POST /api/v1/auth/{register,login,guest,facebook,google}` ·
`GET /api/v1/me` · `GET /api/v1/profile/stats` ·
`POST /api/v1/account/delete-request` (Sanctum) ·
rooms / matchmaking / matches / friends / wallet / store / spin / leaderboard.
Public legal (no auth): `GET /`, `/privacy`, `/terms`, `/data-deletion`, `/support`.

---

## 6. Authentication setup

### Facebook (already wired in `app/android/.../res/values/strings.xml`)
- App ID `2582636912564874`, client token + `fb_login_protocol_scheme` present;
  `AndroidManifest.xml` declares the FB SDK activities.
- Meta dashboard: package `com.arifurrahman.ludofriends`, class
  `com.arifurrahman.ludofriends.MainActivity`, **key hashes** (debug + Play App
  Signing), Privacy/Terms/Data-Deletion URLs, **`public_profile` only** (do NOT
  request `user_friends` until Meta App Review approves it).

Generate a Facebook key hash:
```bash
keytool -exportcert -alias upload -keystore upload-keystore.jks | openssl sha1 -binary | openssl base64
```

### Google Sign-In
1. Google Cloud → project → **OAuth consent screen** (app name Ludo Friends,
   support + developer email `hatbazar627@gmail.com`, privacy/terms URLs, app
   domain `db.ludogame.dronescan.pro`, add test users if in Testing mode).
2. **Android OAuth client**: package `com.arifurrahman.ludofriends` + SHA-1
   (Windows debug, Mac debug if used, **Play App Signing**).
3. **Web OAuth client** → `GOOGLE_CLIENT_ID_WEB` (server) and
   `GOOGLE_SERVER_CLIENT_ID` (app build) — same value.
4. No Gmail API; no Drive/Contacts/Calendar scopes.

---

## 7. Realtime (Reverb) + Nginx + Supervisor

**Reverb server port is 8081** (Nginx terminates wss on 443 and proxies to it).

Nginx WebSocket vhost (`ws.ludogame.dronescan.pro`):
```nginx
location / {
    proxy_pass http://127.0.0.1:8081;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "Upgrade";
    proxy_set_header Host $host;
    proxy_read_timeout 600s;
}
```

Supervisor:
```ini
[program:ludo-reverb]
command=php /var/www/ludofriends/backend/artisan reverb:start --host=127.0.0.1 --port=8081
autostart=true
autorestart=true
user=arif

[program:ludo-queue]
command=php /var/www/ludofriends/backend/artisan queue:work --sleep=1 --tries=3 --max-time=3600
numprocs=2
autostart=true
autorestart=true
user=arif
```

Scheduler (cron):
```
* * * * * cd /var/www/ludofriends/backend && php artisan schedule:run >> /dev/null 2>&1
```

---

## 8. Deploy (server, branch `claude-fb`)

```bash
ssh arif@87.106.236.129
cd /var/www/ludofriends
git fetch origin && git switch claude-fb && git pull --ff-only origin claude-fb
cd backend
composer install --no-dev --optimize-autoloader
php artisan migrate --force
php artisan optimize:clear && php artisan config:cache && php artisan route:cache && php artisan event:cache
sudo supervisorctl restart ludo-queue:* ludo-reverb
sudo systemctl reload nginx
```
After editing `.env` (e.g. Google keys) run the `optimize:clear … config:cache …`
line and restart Reverb/queue again.

**Rollback:** `git switch claude-3d && composer install --no-dev -o && php artisan migrate --force && php artisan optimize:clear && php artisan config:cache && sudo supervisorctl restart ludo-queue:* ludo-reverb`

---

## 9. Play Store release (internal testing)

### 9.1 Release signing — REQUIRED (Play rejects debug-signed AABs)
`app/android/app/build.gradle.kts` currently signs release with the debug key.
Create an upload keystore once:
```bash
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```
Create `app/android/key.properties` (**do NOT commit** — add to .gitignore):
```
storePassword=********
keyPassword=********
keyAlias=upload
storeFile=/absolute/path/to/upload-keystore.jks
```
Wire it in `app/android/app/build.gradle.kts`:
```kotlin
import java.util.Properties
import java.io.FileInputStream
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) keystoreProperties.load(FileInputStream(keystorePropertiesFile))
android {
  signingConfigs {
    create("release") {
      if (keystorePropertiesFile.exists()) {
        keyAlias = keystoreProperties["keyAlias"] as String
        keyPassword = keystoreProperties["keyPassword"] as String
        storeFile = file(keystoreProperties["storeFile"] as String)
        storePassword = keystoreProperties["storePassword"] as String
      }
    }
  }
  buildTypes {
    release {
      signingConfig = if (keystorePropertiesFile.exists())
        signingConfigs.getByName("release") else signingConfigs.getByName("debug")
    }
  }
}
```
> Bump `version:` in `app/pubspec.yaml` (`1.0.0+1` → `+2` …) for every upload —
> Play requires a unique `versionCode`.

### 9.2 Build the AAB
```bash
cd app && flutter clean && flutter pub get
flutter build appbundle --release \
  --dart-define=APP_ENV=prod \
  --dart-define=API_BASE_URL=https://db.ludogame.dronescan.pro/api/v1 \
  --dart-define=WS_HOST=ws.ludogame.dronescan.pro \
  --dart-define=WS_PORT=443 --dart-define=WS_TLS=true \
  --dart-define=WS_KEY=ludo-prod-key-2026 \
  --dart-define=FACEBOOK_ENABLED=true \
  --dart-define=GOOGLE_ENABLED=true \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=YOUR_WEB_OAUTH_CLIENT_ID
```
Output: `app/build/app/outputs/bundle/release/app-release.aab`

### 9.3 Store assets (in `docs/store-assets/`)
- `play_icon_512.png` — 512×512 app icon.
- `feature_graphic_1024x500.png` — 1024×500 feature graphic.
- Regenerate with Pillow from `docs/store-assets/` source; launcher icons via
  `dart run flutter_launcher_icons`.

### 9.4 Play Console checklist
Internal testing release → upload AAB → add tester Gmail addresses → copy opt-in
link → **Data safety** (below) → privacy URL `…/privacy` → category **Game /
Board** → content rating → store listing (icon, feature graphic, screenshots) →
contact `hatbazar627@gmail.com` → App integrity SHA-1 → add that SHA-1 to the
Google Cloud Android OAuth client **and** convert it to a Facebook key hash for
Meta. Keep debug key hashes for USB testing.

**Data safety mapping:** collects Name, optional Email (Google), User IDs
(Google/Facebook), profile Photo, App activity (gameplay/friends/matches),
diagnostics. Encrypted in transit (HTTPS); users can request deletion (in-app +
web). Not collected: location, contacts, mic/camera, Gmail/Drive.

### 9.5 On-device test checklist
Facebook login · Google login · Guest · **profile shows photo + real
matches/wins/losses/win-rate/streak/coins** · home has no overflow · board shows
name/photo · create/join private room · start match · dice/move sync · chat/emoji
sync · friends persist · invite friend · matchmaking · bot fallback · leaderboard
· no 404 on `/friends` `/rooms` `/matchmaking` · Reverb + queue + scheduler up ·
Settings → Legal links open.

---

## 10. Legal & account deletion

- Privacy: https://db.ludogame.dronescan.pro/privacy
- Terms: https://db.ludogame.dronescan.pro/terms
- Data deletion (Meta "User Data Deletion URL"): https://db.ludogame.dronescan.pro/data-deletion
- Support: https://db.ludogame.dronescan.pro/support

In-app: **Settings → Legal**. Account deletion request endpoint:
`POST /api/v1/account/delete-request` (Sanctum) records a non-destructive
request; wallet/purchase/match records are retained for integrity.

---

## 11. Troubleshooting

| Symptom | Fix |
|---------|-----|
| `401` on a protected route | Normal when unauthenticated |
| `404` on `/friends` `/rooms` `/matchmaking` | Deploy branch `claude-fb` |
| WebSocket won't connect | `WS_HOST`/`WS_KEY`, Reverb port **8081**, Nginx WS vhost |
| Google "requestedScopes cannot be null or empty" | Fixed (no empty-scope authorize call); rebuild the app |
| Google `ApiException: 10` | Wrong package/SHA-1/OAuth client, or missing `GOOGLE_SERVER_CLIENT_ID` |
| Google "issued for a different app" | Web client id ≠ server `GOOGLE_CLIENT_ID_WEB` |
| FB "invalid key hash" | Add debug + Play App Signing key hashes in Meta |
| FB "invalid scope" | `user_friends` requested — use `public_profile` only |
| Profile photo missing | App now prefers the fresh provider photo URL; rebuild + re-login |
| Play rejects AAB "signed in debug mode" | Set up the upload keystore (§9.1) |
```
