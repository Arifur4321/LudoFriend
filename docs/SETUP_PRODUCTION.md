# Ludo Friends — Production Setup

Companion to `SETUP.md`. Covers the monorepo, backend/app setup, the production
`.env` template (no secrets), Nginx/Reverb/Supervisor/cron, and Facebook +
Google Sign-In. **Keep all real secrets out of git.**

Branch: **`claude-fb`** (multiplayer/friends/matchmaking). Rollback: **`claude-3d`**.

---

## 1. Monorepo layout

```
LudoFriend/
├── app/       # Flutter client (Android/iOS)
├── backend/   # Laravel API + Reverb (WebSockets)
└── docs/      # setup, release checklist, store assets
```

---

## 2. Flutter (client)

Local setup:

```bash
cd app
flutter pub get
dart run flutter_launcher_icons   # (re)generate launcher icons
```

Run against production (USB device):

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
  --dart-define=GOOGLE_SERVER_CLIENT_ID=PASTE_WEB_CLIENT_ID
```

Release AAB / APK: see `docs/RELEASE_CHECKLIST_INTERNAL_TESTING.md` (includes
the required **upload keystore** setup — Play rejects debug-signed uploads).

Client `--dart-define` reference:

| Define | Meaning |
|--------|---------|
| `APP_ENV` | `dev` / `staging` / `prod` |
| `API_BASE_URL` | REST base incl. `/api/v1` |
| `WS_HOST` / `WS_PORT` / `WS_TLS` / `WS_KEY` | Reverb/Pusher client connection |
| `FACEBOOK_ENABLED` | toggle Facebook button |
| `GOOGLE_ENABLED` | toggle Google button |
| `GOOGLE_SERVER_CLIENT_ID` | **Web** OAuth client id (idToken audience) — required for Google login |
| `GOOGLE_IOS_CLIENT_ID` | iOS OAuth client id (iOS only, later) |

---

## 3. Laravel (backend)

```bash
cd backend
composer install --no-dev --optimize-autoloader
cp .env.example .env          # then edit (see template below)
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

### Production `.env` template (no secrets committed)

```
APP_NAME="Ludo Friends"
APP_ENV=production
APP_KEY=            # php artisan key:generate
APP_DEBUG=false
APP_URL=https://db.ludogame.dronescan.pro

DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=ludo_friends
DB_USERNAME=ludo_user
DB_PASSWORD=            # set on server only

# Scale: prefer redis in production
CACHE_STORE=redis
QUEUE_CONNECTION=redis
SESSION_DRIVER=redis
REDIS_CLIENT=phpredis
REDIS_HOST=127.0.0.1
REDIS_PORT=6379

# Broadcasting (Reverb) — server listens on 8081; Nginx terminates TLS on 443
BROADCAST_CONNECTION=reverb
REVERB_APP_ID=ludofriends
REVERB_APP_KEY=ludo-prod-key-2026
REVERB_APP_SECRET=            # set on server only
REVERB_HOST=ws.ludogame.dronescan.pro
REVERB_PORT=443
REVERB_SCHEME=https
REVERB_SERVER_HOST=127.0.0.1
REVERB_SERVER_PORT=8081
REVERB_SCALING_ENABLED=true

# Facebook Login
FACEBOOK_LOGIN_ENABLED=true
FACEBOOK_APP_ID=2582636912564874
FACEBOOK_APP_SECRET=            # set on server only
FACEBOOK_GRAPH_VERSION=v19.0

# Google Sign-In (identity only — no Gmail/Drive/Contacts scopes)
GOOGLE_LOGIN_ENABLED=true
GOOGLE_CLIENT_ID_WEB=            # Web OAuth client id (token audience)
GOOGLE_CLIENT_ID_ANDROID=       # Android OAuth client id
GOOGLE_CLIENT_ID_IOS=

CORS_ALLOWED_ORIGINS=https://db.ludogame.dronescan.pro
SANCTUM_TOKEN_EXPIRATION=20160
```

---

## 4. Nginx — API vhost (HTTPS)

```nginx
server {
    listen 443 ssl http2;
    server_name db.ludogame.dronescan.pro;

    ssl_certificate     /etc/letsencrypt/live/db.ludogame.dronescan.pro/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/db.ludogame.dronescan.pro/privkey.pem;

    root /var/www/ludofriends/backend/public;
    index index.php;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        include fastcgi_params;
        fastcgi_pass unix:/run/php/php8.2-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
    }
}
```

## 5. Nginx — WebSocket vhost (Reverb, wss → 8081)

```nginx
server {
    listen 443 ssl http2;
    server_name ws.ludogame.dronescan.pro;

    ssl_certificate     /etc/letsencrypt/live/ws.ludogame.dronescan.pro/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/ws.ludogame.dronescan.pro/privkey.pem;

    location / {
        proxy_pass http://127.0.0.1:8081;      # Reverb server port
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "Upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 600s;
    }
}
```

`sudo nginx -t && sudo systemctl reload nginx`

---

## 6. Supervisor — Reverb + queue workers

`/etc/supervisor/conf.d/ludo-reverb.conf`:

```ini
[program:ludo-reverb]
command=php /var/www/ludofriends/backend/artisan reverb:start --host=127.0.0.1 --port=8081
directory=/var/www/ludofriends/backend
autostart=true
autorestart=true
user=arif
stdout_logfile=/var/www/ludofriends/backend/storage/logs/reverb.log
stopwaitsecs=10
```

`/etc/supervisor/conf.d/ludo-queue.conf`:

```ini
[program:ludo-queue]
process_name=%(program_name)s_%(process_num)02d
command=php /var/www/ludofriends/backend/artisan queue:work --sleep=1 --tries=3 --max-time=3600
directory=/var/www/ludofriends/backend
autostart=true
autorestart=true
user=arif
numprocs=2
stdout_logfile=/var/www/ludofriends/backend/storage/logs/queue.log
stopwaitsecs=15
```

```bash
sudo supervisorctl reread && sudo supervisorctl update
sudo supervisorctl restart ludo-queue:* ludo-reverb
```

## 7. Scheduler (cron)

```
* * * * * cd /var/www/ludofriends/backend && php artisan schedule:run >> /dev/null 2>&1
```

---

## 8. Facebook Login setup

- App ID `2582636912564874` (in `app/android/app/src/main/res/values/strings.xml`
  and server `.env`). Client token + `fb_login_protocol_scheme` are already in
  `strings.xml`; `AndroidManifest.xml` already declares the FB SDK + activities.
- Meta dashboard: package `com.arifurrahman.ludofriends`, class
  `com.arifurrahman.ludofriends.MainActivity`, key hashes (debug + Play App
  Signing), Privacy/Terms/Data-Deletion URLs, **public_profile only**.

## 9. Google Sign-In setup

- The client uses `google_sign_in` (v7). It needs the **Web** OAuth client id at
  build time as `GOOGLE_SERVER_CLIENT_ID`, and an **Android** OAuth client
  (package + SHA-1) in Google Cloud.
- The backend verifies the idToken audience against `GOOGLE_CLIENT_ID_WEB` /
  `GOOGLE_CLIENT_ID_ANDROID` (`config/economy.php` → `social.google.client_ids`).
- **No Gmail API, no Drive/Contacts/Calendar scopes** — identity only.

Google Cloud Console steps:
1. Create/select the Ludo Friends project.
2. OAuth consent screen: App name **Ludo Friends**, support + developer email
   `hatbazar627@gmail.com`, privacy `…/privacy`, terms `…/terms`, app domain
   `db.ludogame.dronescan.pro`; add test users if in Testing mode.
3. Create **Android** OAuth client (package `com.arifurrahman.ludofriends`, add
   SHA-1s: Windows debug, Mac debug, Play App Signing).
4. Create **Web** OAuth client → `GOOGLE_CLIENT_ID_WEB` and the app's
   `GOOGLE_SERVER_CLIENT_ID`.
5. Rebuild config cache after editing `.env`.

---

## 10. Branch / rollback

- Deploy branch: **`claude-fb`**.
- Rollback: `git switch claude-3d && composer install --no-dev -o && php artisan migrate --force && php artisan optimize:clear && php artisan config:cache && sudo supervisorctl restart ludo-queue:* ludo-reverb`.

## 11. Troubleshooting

| Symptom | Meaning / fix |
|---------|---------------|
| `401` on a protected route | Normal for unauthenticated requests |
| `404` on `/friends`, `/rooms`, `/matchmaking` | Route/branch not deployed — deploy `claude-fb` |
| WebSocket won't connect | Check `WS_HOST`/`WS_KEY`, Reverb port **8081**, Nginx WS vhost |
| FB "invalid key hash" | Add debug + Play App Signing key hashes in Meta |
| FB "invalid scope" | `user_friends` requested — use `public_profile` only |
| Google `sign_in_failed` / `ApiException: 10` | Wrong package/SHA-1/OAuth client, or missing `GOOGLE_SERVER_CLIENT_ID` |
| `composer.lock` missing / advisory | `composer install` from a clean checkout; review advisories before `--no-dev` |
| Queue/scheduler not running | `supervisorctl status`; check cron line |
