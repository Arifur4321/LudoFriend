# Ludo Friends — Setup & Deployment Guide

How to run the **Laravel backend** (`backend/`) and the **Flutter app** (`app/`)
both **locally** and on a **remote production server**.

> App id: `com.arifurrahman.ludofriends` · API is versioned at `/api/v1` ·
> realtime uses Laravel **Reverb** (Pusher protocol).

---

## 1. Prerequisites

| Tool | Version | Used by |
|---|---|---|
| PHP | **8.2+** (with `pdo_mysql`, `mbstring`, `openssl`, `bcmath`, `ctype`, `curl`, `redis` optional) | backend |
| Composer | 2.x | backend |
| MySQL | 8.0+ (or MariaDB 10.6+) | backend |
| Redis | 6+ (optional locally, recommended in prod) | queue/cache/broadcast scaling |
| Flutter SDK | **3.24+** (Dart **3.5+**) | app |
| Android Studio / Xcode | latest | building the app |
| Git | any | both |

Check: `php -v`, `composer -V`, `mysql --version`, `flutter --version`, `flutter doctor`.

---

## 2. Backend — local

### 2.1 Install & configure

```bash
cd backend
composer install
cp .env.example .env
php artisan key:generate
```

Create the database and point `.env` at it:

```bash
mysql -u root -e "CREATE DATABASE ludo_friends CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
```

```dotenv
# backend/.env
APP_ENV=local
APP_DEBUG=true
APP_URL=http://localhost:8000

DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=ludo_friends
DB_USERNAME=root
DB_PASSWORD=

# Session/cache/queue default to the database driver locally.
QUEUE_CONNECTION=database
CACHE_STORE=database
SESSION_DRIVER=database

# Realtime (Reverb) — local dev values
BROADCAST_CONNECTION=reverb
REVERB_APP_ID=ludofriends
REVERB_APP_KEY=local-reverb-key
REVERB_APP_SECRET=local-reverb-secret
REVERB_HOST=localhost
REVERB_PORT=8080
REVERB_SCHEME=http
REVERB_SERVER_HOST=0.0.0.0
REVERB_SERVER_PORT=8080

# CORS — allow the client origins you use (never use "*" with credentials in prod)
CORS_ALLOWED_ORIGINS=http://localhost,http://localhost:3000
```

**Economy toggles** (all have safe defaults — add only what you want to change):

```dotenv
# Wallet / boards / payout
LUDO_STARTING_COINS=500
LUDO_HOUSE_RAKE_BPS=0            # 0 = pure winner-takes-all; 1000 = 10%
LUDO_MATCH_IDLE_ABORT_MINUTES=30

# Free spin (hourly rolling cooldown)
LUDO_FREE_SPIN_ENABLED=true
LUDO_FREE_SPIN_INTERVAL_MINUTES=60

# Coin store (kept safe until store creds exist)
LUDO_STORE_ENABLED=true
LUDO_STORE_VERIFY_RECEIPTS=false
APPLE_IAP_SHARED_SECRET=
LUDO_ANDROID_PACKAGE=com.arifurrahman.ludofriends

# Social login (inert until enabled + creds set)
GOOGLE_LOGIN_ENABLED=false
GOOGLE_CLIENT_ID_WEB=
GOOGLE_CLIENT_ID_ANDROID=
GOOGLE_CLIENT_ID_IOS=
FACEBOOK_LOGIN_ENABLED=false
FACEBOOK_APP_ID=
FACEBOOK_APP_SECRET=
```

### 2.2 Migrate

```bash
php artisan migrate           # fresh setup

# If you already ran an earlier version of these migrations on this dev DB,
# rebuild it (DEV ONLY — drops all data):
php artisan migrate:fresh
```

### 2.3 Run (four processes)

Open separate terminals (all from `backend/`):

```bash
php artisan serve                 # REST API        → http://127.0.0.1:8000
php artisan reverb:start          # WebSockets      → ws://127.0.0.1:8080
php artisan queue:work            # background jobs  (leaderboard, replays, refunds)
php artisan schedule:work         # cron-like scheduler (stale rooms/matches, leaderboards)
```

The **queue** and **scheduler** matter for the economy: idle staked matches are
auto-aborted **and refunded** by the scheduled `ExpireStaleMatches` job, and
leaderboards/replays run as queued jobs.

### 2.4 Test & lint

```bash
php artisan test                  # PHPUnit (uses in-memory SQLite; no MySQL needed)
./vendor/bin/pint --test          # code style check
```

---

## 3. Flutter app — local

```bash
cd app
flutter pub get                   # pulls deps incl. sqflite (on-device cache)
flutter analyze
flutter test
```

The client reads all environment-specific values from **`--dart-define`** flags
(see `app/lib/core/config/app_config.dart`). Point them at your local backend.

**Android emulator** reaches your host machine at `10.0.2.2`:

```bash
flutter run \
  --dart-define=APP_ENV=dev \
  --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1 \
  --dart-define=WS_HOST=10.0.2.2 \
  --dart-define=WS_PORT=8080 \
  --dart-define=WS_TLS=false \
  --dart-define=WS_KEY=local-reverb-key
```

**iOS simulator** uses `localhost` instead of `10.0.2.2`:

```bash
flutter run \
  --dart-define=API_BASE_URL=http://localhost:8000/api/v1 \
  --dart-define=WS_HOST=localhost --dart-define=WS_PORT=8080 --dart-define=WS_TLS=false \
  --dart-define=WS_KEY=local-reverb-key
```

**Physical device on the same Wi-Fi** — use your machine's LAN IP (e.g.
`192.168.1.20`) and run the API on `0.0.0.0`:

```bash
# backend
php artisan serve --host=0.0.0.0 --port=8000
# app
flutter run --dart-define=API_BASE_URL=http://192.168.1.20:8000/api/v1 \
  --dart-define=WS_HOST=192.168.1.20 --dart-define=WS_PORT=8080 --dart-define=WS_TLS=false \
  --dart-define=WS_KEY=local-reverb-key
```

> **Android cleartext (HTTP) in dev:** Android blocks plain HTTP by default. For
> local testing either use the debug build (which is more permissive) or add a
> network-security-config allowing cleartext to your dev host. Production uses
> HTTPS/WSS so this doesn't apply there.

**Dart-define reference** (client):

| Define | Local example | Prod example |
|---|---|---|
| `APP_ENV` | `dev` | `prod` |
| `API_BASE_URL` | `http://10.0.2.2:8000/api/v1` | `https://api.ludofriends.app/api/v1` |
| `WS_HOST` | `10.0.2.2` | `ws.ludofriends.app` |
| `WS_PORT` | `8080` | `443` |
| `WS_TLS` | `false` | `true` |
| `WS_KEY` | `local-reverb-key` | *(prod `REVERB_APP_KEY`)* |
| `GOOGLE_ENABLED` / `FACEBOOK_ENABLED` | `false` | `true` (with native setup + creds) |

`WS_KEY` **must equal** the backend `REVERB_APP_KEY`.

---

## 4. Backend — remote production server

Target: Ubuntu 22.04, Nginx + PHP-FPM 8.2, MySQL, Redis, Supervisor, Certbot.

### 4.1 Provision

```bash
sudo apt update
sudo apt install -y nginx mysql-server redis-server supervisor \
  php8.2-fpm php8.2-cli php8.2-mysql php8.2-mbstring php8.2-xml \
  php8.2-curl php8.2-bcmath php8.2-redis php8.2-zip unzip git
# Composer
curl -sS https://getcomposer.org/installer | php && sudo mv composer.phar /usr/local/bin/composer
```

### 4.2 Deploy the code

```bash
cd /var/www
sudo git clone <your-repo> ludofriends && cd ludofriends/backend
composer install --no-dev --optimize-autoloader
cp .env.example .env
php artisan key:generate
sudo chown -R www-data:www-data storage bootstrap/cache
```

### 4.3 Production `.env`

```dotenv
APP_ENV=production
APP_DEBUG=false
APP_URL=https://api.ludofriends.app

DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_DATABASE=ludo_friends
DB_USERNAME=ludo
DB_PASSWORD=<strong-password>

# Use Redis in prod for cache/queue/broadcast scaling
CACHE_STORE=redis
QUEUE_CONNECTION=redis
SESSION_DRIVER=redis
REDIS_CLIENT=phpredis
REDIS_HOST=127.0.0.1
REDIS_PORT=6379

# Security (see SENIOR_DEV_ANALYSIS.md P0s)
SANCTUM_TOKEN_EXPIRATION=43200                 # minutes (30 days); rotate as you like
CORS_ALLOWED_ORIGINS=https://ludofriends.app   # explicit allowlist, never "*"

# Realtime — public subdomain over TLS, internal server on 8080
BROADCAST_CONNECTION=reverb
REVERB_APP_ID=ludofriends
REVERB_APP_KEY=<random-public-key>
REVERB_APP_SECRET=<random-secret>
REVERB_HOST=ws.ludofriends.app
REVERB_PORT=443
REVERB_SCHEME=https
REVERB_SERVER_HOST=0.0.0.0
REVERB_SERVER_PORT=8080
REVERB_SCALING_ENABLED=true                    # Redis-backed, for >1 Reverb process

# Economy + social + store flags (fill social/store when you have creds)
LUDO_FREE_SPIN_INTERVAL_MINUTES=60
LUDO_STORE_VERIFY_RECEIPTS=true
APPLE_IAP_SHARED_SECRET=<from App Store Connect>
GOOGLE_LOGIN_ENABLED=true
GOOGLE_CLIENT_ID_ANDROID=<...>
GOOGLE_CLIENT_ID_IOS=<...>
FACEBOOK_LOGIN_ENABLED=true
FACEBOOK_APP_ID=<...>
FACEBOOK_APP_SECRET=<...>
```

### 4.4 Migrate & cache config

```bash
php artisan migrate --force
php artisan config:cache
php artisan route:cache
php artisan event:cache
php artisan storage:link
```

### 4.5 Nginx — API site (`/etc/nginx/sites-available/api.ludofriends.app`)

```nginx
server {
    listen 80;
    server_name api.ludofriends.app;
    root /var/www/ludofriends/backend/public;

    index index.php;
    charset utf-8;

    location / { try_files $uri $uri/ /index.php?$query_string; }
    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }

    location ~ \.php$ {
        fastcgi_pass unix:/var/run/php/php8.2-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
        include fastcgi_params;
    }
    location ~ /\.(?!well-known).* { deny all; }
}
```

### 4.6 Nginx — Reverb WebSocket site (`ws.ludofriends.app`)

```nginx
server {
    listen 80;
    server_name ws.ludofriends.app;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "Upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
    }
}
```

Enable both, add TLS, and reload:

```bash
sudo ln -s /etc/nginx/sites-available/api.ludofriends.app /etc/nginx/sites-enabled/
sudo ln -s /etc/nginx/sites-available/ws.ludofriends.app  /etc/nginx/sites-enabled/
sudo certbot --nginx -d api.ludofriends.app -d ws.ludofriends.app
sudo nginx -t && sudo systemctl reload nginx
```

### 4.7 Long-running processes — Supervisor

`/etc/supervisor/conf.d/ludofriends.conf`:

```ini
[program:ludo-reverb]
command=php /var/www/ludofriends/backend/artisan reverb:start --host=0.0.0.0 --port=8080
autostart=true
autorestart=true
user=www-data
stopwaitsecs=10
stdout_logfile=/var/log/ludo-reverb.log

[program:ludo-queue]
command=php /var/www/ludofriends/backend/artisan queue:work --sleep=1 --tries=3 --max-time=3600
autostart=true
autorestart=true
numprocs=2
process_name=%(program_name)s_%(process_num)02d
user=www-data
stopwaitsecs=30
stdout_logfile=/var/log/ludo-queue.log
```

```bash
sudo supervisorctl reread && sudo supervisorctl update && sudo supervisorctl start all
```

### 4.8 Scheduler — cron

```bash
sudo crontab -u www-data -e
```

```cron
* * * * * cd /var/www/ludofriends/backend && php artisan schedule:run >> /dev/null 2>&1
```

This drives the every-minute room sweep, the 5-minute idle-match abort+refund,
and the leaderboard recomputations.

### 4.9 Deploy updates

```bash
cd /var/www/ludofriends/backend
git pull
composer install --no-dev --optimize-autoloader
php artisan migrate --force
php artisan config:cache && php artisan route:cache && php artisan event:cache
sudo supervisorctl restart ludo-reverb ludo-queue:*
```

---

## 5. Flutter app — release build against the remote server

```bash
cd app
flutter pub get

# Android App Bundle (Play Store)
flutter build appbundle --release \
  --dart-define=APP_ENV=prod \
  --dart-define=API_BASE_URL=https://api.ludofriends.app/api/v1 \
  --dart-define=WS_HOST=ws.ludofriends.app \
  --dart-define=WS_PORT=443 \
  --dart-define=WS_TLS=true \
  --dart-define=WS_KEY=<prod REVERB_APP_KEY> \
  --dart-define=GOOGLE_ENABLED=true \
  --dart-define=FACEBOOK_ENABLED=true

# iOS (then archive/upload in Xcode)
flutter build ipa --release \
  --dart-define=APP_ENV=prod \
  --dart-define=API_BASE_URL=https://api.ludofriends.app/api/v1 \
  --dart-define=WS_HOST=ws.ludofriends.app --dart-define=WS_PORT=443 --dart-define=WS_TLS=true \
  --dart-define=WS_KEY=<prod REVERB_APP_KEY> \
  --dart-define=GOOGLE_ENABLED=true --dart-define=FACEBOOK_ENABLED=true
```

Put the many defines in a JSON file and pass `--dart-define-from-file=prod.json`
to keep build commands short.

**Signing (high level):**
- **Android:** create a keystore, set it in `android/key.properties` +
  `android/app/build.gradle`, then `flutter build appbundle --release`.
- **iOS:** open `ios/Runner.xcworkspace` in Xcode, set the Team/bundle id
  (`com.arifurrahman.ludofriends`), then Archive → Distribute.

---

## 6. Adding social login / store credentials later

- **Google:** set `GOOGLE_LOGIN_ENABLED=true` + `GOOGLE_CLIENT_ID_*` on the
  backend; build the app with `--dart-define=GOOGLE_ENABLED=true` (plus the
  native Google Sign-In setup per platform). Endpoint `/auth/google` is ready.
- **Facebook:** set `FACEBOOK_LOGIN_ENABLED=true` + `FACEBOOK_APP_ID/SECRET`;
  build with `--dart-define=FACEBOOK_ENABLED=true` and complete the native FB SDK
  setup.
- **Coin store:** set `LUDO_STORE_VERIFY_RECEIPTS=true` and provide
  `APPLE_IAP_SHARED_SECRET` (iOS) / a Play service account (Android — wire in
  `StoreService::verifyReceipt`). Until then purchases are recorded but only
  credited in local/testing, so no coins are granted on unverified receipts.

---

## 7. Troubleshooting

| Symptom | Fix |
|---|---|
| App can't reach API on Android emulator | Use `10.0.2.2`, not `localhost`; API on `--host=0.0.0.0`. |
| `CORS`/credentials error | Set `CORS_ALLOWED_ORIGINS` to explicit origins; never `*` with credentials. |
| WebSocket won't connect | Reverb process running? `WS_KEY == REVERB_APP_KEY`? Prod: Nginx `Upgrade`/`Connection` headers + WSS on 443. |
| Realtime works but jobs/refunds don't | Start `queue:work` (local) / Supervisor (prod) **and** the scheduler (cron). |
| Migration errors after pulling updates (dev) | `php artisan migrate:fresh` (dev only — drops data). |
| Coins/spins not updating | Confirm `php artisan migrate` ran and the queue + scheduler are up. |
| Android release rejects HTTP | Production must use HTTPS/WSS; only debug/dev should ever use cleartext. |

---

## 8. Related docs

- `docs/ECONOMY_FEATURES.md` — wallet, hourly spin, staked boards, 3D dice, store.
- `docs/RUN_AND_TEST.md` — focused test commands + economy tuning knobs.
- `docs/DEPLOYMENT.md` / `docs/ARCHITECTURE.md` — original deployment/architecture notes.
- `SENIOR_DEV_ANALYSIS.md` — pre-launch hardening checklist (CORS, token expiry, etc.).
