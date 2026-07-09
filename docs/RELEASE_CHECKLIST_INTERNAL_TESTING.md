# Go‑Live Runbook — Backend (VPS) + Play Store internal testing

This is the exact, ordered list of **manual** actions to ship the current
`claude-fb` build (live board, in‑game chat/emoji, Facebook friends + presence,
private rooms, **random matchmaking**, online multiplayer) so internal testers
can install it and play together.

Two things must both be true for online play to work:
1. The **backend** is deployed and migrated on your VPS.
2. Three long‑running processes are up: **Reverb** (WebSockets), a **queue
   worker**, and the **scheduler** (cron). Matchmaking bot‑fill and every
   realtime update depend on the last two — do not skip them.

Assumed hosts (change if yours differ):
- REST API: `https://db.ludogame.dronescan.pro`  → app base `…/api/v1`
- WebSocket: `wss://ws.ludogame.dronescan.pro` (nginx TLS → Reverb on `127.0.0.1:8080`)
- Facebook App ID already wired natively: `2582636912564874`

---

## PART A — Backend on the VPS

```bash
# 1. Get the code onto the server (first time: clone; after: pull)
cd /var/www/ludofriend        # your app path
git fetch origin
git checkout claude-fb
git pull origin claude-fb

# 2. PHP deps (production)
cd backend
composer install --no-dev --optimize-autoloader

# 3. Environment (first deploy only: create + key)
cp .env.example .env          # skip if .env already exists
php artisan key:generate      # skip if APP_KEY already set
```

Edit `backend/.env` — the values that matter for this release:

```dotenv
APP_ENV=production
APP_DEBUG=false
APP_URL=https://db.ludogame.dronescan.pro

# --- Database (your MySQL) ---
DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_DATABASE=ludofriend
DB_USERNAME=xxxx
DB_PASSWORD=xxxx

# --- Redis (presence, cache, queue) ---
REDIS_CLIENT=phpredis          # or predis if the ext isn't installed
REDIS_HOST=127.0.0.1
REDIS_PORT=6379
CACHE_STORE=redis              # friends "online" flag lives in cache
SESSION_DRIVER=redis
QUEUE_CONNECTION=redis         # broadcasts + jobs go through the worker

# --- Broadcasting / Reverb (WebSockets) ---
BROADCAST_CONNECTION=reverb
REVERB_APP_ID=ludofriends
REVERB_APP_KEY=CHOOSE_A_PUBLIC_KEY      # ships in the app as WS_KEY (safe to expose)
REVERB_APP_SECRET=CHOOSE_A_LONG_SECRET  # server-only, keep private
REVERB_HOST=ws.ludogame.dronescan.pro   # public hostname the app connects to
REVERB_PORT=443
REVERB_SCHEME=https
REVERB_SERVER_HOST=127.0.0.1            # the socket Reverb actually listens on
REVERB_SERVER_PORT=8080
REVERB_SCALING_ENABLED=false            # set true only when you run >1 Reverb node
```

```bash
# 4. Migrate (creates matchmaking_tickets, match_messages, friend_links, etc.)
php artisan migrate --force

# 5. Cache config/routes for speed (re-run after every .env change)
php artisan config:cache
php artisan route:cache
php artisan event:cache
```

> After **any** later `.env` edit, re-run `php artisan config:cache` and restart
> the Reverb + queue services, or the change won't be picked up.

---

## PART B — Reverb WebSocket server + nginx TLS

Reverb listens on `127.0.0.1:8080`; nginx terminates TLS and forwards
`wss://ws.ludogame.dronescan.pro` to it. Add this server block (and issue a cert
for that hostname with certbot):

```nginx
server {
    listen 443 ssl http2;
    server_name ws.ludogame.dronescan.pro;

    ssl_certificate     /etc/letsencrypt/live/ws.ludogame.dronescan.pro/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/ws.ludogame.dronescan.pro/privkey.pem;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "Upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 3600s;   # keep long-lived sockets open
    }
}
```

```bash
sudo certbot --nginx -d ws.ludogame.dronescan.pro
sudo nginx -t && sudo systemctl reload nginx
```

---

## PART C — Keep 3 processes alive (systemd)

Create these units, then `enable --now` each. **All three are required.**

`/etc/systemd/system/reverb.service`

```ini
[Unit]
Description=Laravel Reverb
After=network.target
[Service]
User=www-data
WorkingDirectory=/var/www/ludofriend/backend
ExecStart=/usr/bin/php artisan reverb:start --host=127.0.0.1 --port=8080
Restart=always
[Install]
WantedBy=multi-user.target
```

`/etc/systemd/system/ludo-queue.service`  (delivers broadcasts + jobs)

```ini
[Unit]
Description=Ludo queue worker
After=network.target
[Service]
User=www-data
WorkingDirectory=/var/www/ludofriend/backend
ExecStart=/usr/bin/php artisan queue:work --queue=default --sleep=1 --tries=3 --timeout=90
Restart=always
[Install]
WantedBy=multi-user.target
```

`/etc/systemd/system/ludo-scheduler.service` + timer — **this is what runs the
matchmaking bot‑fill sweep and stale‑room cleanup every minute.** Simplest is a
cron line instead:

```bash
sudo crontab -u www-data -e
# add:
* * * * * cd /var/www/ludofriend/backend && php artisan schedule:run >> /dev/null 2>&1
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now reverb.service ludo-queue.service
# restart both after every deploy:
sudo systemctl restart reverb.service ludo-queue.service php8.3-fpm
```

Quick server‑side check:

```bash
php artisan about | grep -i broadcast     # driver = reverb
redis-cli ping                            # PONG
sudo ss -ltnp | grep 8080                 # reverb listening
```

---

## PART D — Flutter build for Play Store internal testing

Build an **app bundle** (`.aab`, required by Play) with your real endpoints.
`WS_KEY` must equal the backend `REVERB_APP_KEY` from Part A.

```bash
cd app
flutter clean
flutter pub get

flutter build appbundle --release \
  --dart-define=APP_ENV=prod \
  --dart-define=API_BASE_URL=https://db.ludogame.dronescan.pro/api/v1 \
  --dart-define=WS_HOST=ws.ludogame.dronescan.pro \
  --dart-define=WS_PORT=443 \
  --dart-define=WS_TLS=true \
  --dart-define=WS_KEY=CHOOSE_A_PUBLIC_KEY \
  --dart-define=FACEBOOK_ENABLED=true
```

Output: `app/build/app/outputs/bundle/release/app-release.aab`.

**Release signing** (once): create a keystore and an `android/key.properties`, and
make sure `android/app/build.gradle` reads it for the `release` signingConfig, or
Play will reject an unsigned/debug‑signed bundle.

```bash
keytool -genkey -v -keystore ~/ludofriend-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias ludofriend
```

Then in Play Console:
1. Create the app (or open it) → **Testing → Internal testing → Create new release**.
2. Upload the `.aab`. Fill release notes.
3. **Testers** tab → create an email list → add your testers' Google account
   emails → **Save**, then **Review release → Start rollout to Internal testing**.
4. Copy the **Join on the web** opt‑in link and send it to each tester. They must
   accept, then install from Play. (Internal testing is live in minutes — no
   review wait.)

> First upload also requires the one‑time forms: App content (privacy policy URL,
> data safety, content rating, target audience, ads declaration). Internal
> testing can roll out before these are all done, but Play nags until complete.

---

## PART E — Facebook app so testers can log in

The native FB App ID / client token are already in the project. For **release**
builds two things commonly bite:

1. **Roles or Live mode.** While the FB app is in *Development* mode, only people
   with a role can log in. Either add each tester under **App → Roles → Roles**
   (Testers), **or** switch the app to **Live** (public_profile only needs Basic
   Access — no App Review). Live mode needs a Privacy Policy URL and the basic
   settings filled in.
2. **Release key hash.** Facebook rejects logins whose signing hash it doesn't
   know. Because Play re‑signs your app, use Google's signing certificate:
   - Play Console → your app → **Test and release → App integrity → App signing**
     → copy the **SHA‑1** of the *App signing key certificate*.
   - Convert to a Facebook key hash and paste it into **FB app → Settings →
     Basic → Android → Key hashes**:
     ```bash
     echo -n <SHA1_HEX_NO_COLONS> | xxd -r -p | openssl base64
     ```
     (Also add your local debug hash so `flutter run` keeps working.)

Confirm under **FB → Settings → Basic → Android**: package name
`com.arifurrahman.ludofriends`, default activity
`com.arifurrahman.ludofriends.MainActivity`, and Facebook Login is enabled.

---

## PART F — Smoke test with 2 devices/accounts

1. Both testers install from the internal‑testing link and open the app.
2. Both **log in with Facebook** — each should see their **photo + name** (guests
   see an SVG avatar).
3. Friends: on device A, **Online Match → 4 Players** on both; they should get
   matched together (or bot‑filled after ~30 s), land in the lobby, host taps
   **Start**, and both drop into the same board.
4. Private room: A creates a room, shares the code, B joins by code → both ready →
   start. After the game they should now see each other saved under **Friends**
   next time (no code needed).
5. Online invite: with a saved/online friend, tap **Play** on their friend tile;
   the other device shows a **"Play with {name}?"** prompt → Join → same board.
6. In‑game: dice sits next to the active player, chat + emoji work, settings
   (sound/music/vibration) apply.

If realtime doesn't update (lobby stuck, moves not syncing): the queue worker or
Reverb is almost always the cause — check `systemctl status ludo-queue reverb`
and that `WS_KEY` (app) exactly equals `REVERB_APP_KEY` (server).

---

### One‑line reminder of the "why"
- **No queue worker** → broadcasts never leave the server → lobby/board don't update.
- **No scheduler cron** → solo matchmaking never bot‑fills (players wait forever; the in‑app "Play bots instead" button is the only escape).
- **WS_KEY ≠ REVERB_APP_KEY** → the socket connects but every private channel auth fails.
