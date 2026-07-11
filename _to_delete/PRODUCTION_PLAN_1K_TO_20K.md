# Ludo Friends — Production Plan (Live Table, Chat, Friends, Scale to 1k→20k)

**Author:** Senior dev pass · **Scope:** client redesign + realtime social + backend scaling
**Status legend:** ✅ done this pass · 🚧 designed, ready to build · 🔭 planned

This document is the single source of truth for the work requested: a
production-grade in-game experience that matches the reference screenshot,
Facebook-friends play, in-game chat + emoji, richer settings, and a backend that
holds **1,000 concurrent players now** with a clear path to **20,000**.

---

## 0. How this was verified

The build sandbox used for this pass can reach GitHub/npm but **not** packagist
or pub.dev, so the Laravel and Flutter dependency trees could not be installed
and the two test suites could not be executed here. Verification was therefore:

- **Flutter:** static review + an independent code-review agent pass against the
  real repo APIs (there is no compiler in the sandbox). A pixel-faithful HTML
  mock of the new board (drawn from the app's real `BoardLayout` coordinates)
  was rendered with headless Chromium to validate the layout visually.
- **Laravel:** `php -l` lint on every changed PHP file (PHP 8.4 is available).

**Before shipping, run locally** (both are already wired in the repo):

```bash
# client
cd app && flutter pub get && flutter analyze && flutter test
# server
cd backend && composer install && php artisan test
```

---

## 1. Phase 1 — The "live table" in-game redesign ✅ (this pass)

Rebuilt the match screen to match the reference: four **corner player pods**,
each with its **own dice shown next to the player** (the active player's die is
enlarged and animates; on your turn it reads **TAP** and is tappable to roll),
the **LUDO + tier** wordmark header, and the **Chat / Emoji / Friends /
Settings** bar. The board art is unchanged (same `BoardPainter` geometry), so it
applies identically to **every board tier** (Casual → Diamond).

**Avatars** now render per seat: a Facebook/Google **profile photo** for
signed-in players (`Image.network`, in-memory cached, graceful fallback while
loading / on error), a bundled **SVG avatar for guests** (deterministic per
guest, reusing the existing `avatar_*.svg` set), a **bot glyph** for bots, and a
colored monogram as last resort. `GamePlayer` gained `avatarUrl` + `isGuest`,
plumbed from the signed-in `AuthUser` into the local seat.

**Chat + emoji (client):** a chat bottom-sheet with quick phrases + free text,
and a quick-emoji picker that floats the emoji over the board. Today these echo
locally through `gameChatProvider`; Phase 2 feeds the same provider from the
match WebSocket so no UI rework is needed.

**Settings:** expanded to Sound, Music, **Vibration**, **Turn alerts**,
**In-game chat**, **Emoji reactions**, plus Language / How-to-play / About — all
persisted via `PrefsStorage`.

New/changed files: `game_player.dart`, `shared/widgets/player_avatar.dart`,
game widgets `ludo_header.dart` · `player_pod.dart` · `game_action_bar.dart` ·
`game_chat.dart`, `game_screen.dart` (rewrite), `game_config.dart`,
`play_options_screen.dart`, `app_constants.dart`, `prefs_storage.dart`,
`settings_controller.dart`, `settings_screen.dart`.

**Follow-ups for full polish (small):** wire `Vibration`/`Turn alerts` to actual
haptics (`HapticFeedback`) and a turn chime; add a golden test of `GameScreen`
with four fake seats; feed real avatars for *remote* seats once online rooms
carry them (Phase 3).

---

## 2. Phase 2 — In-game chat + emoji, realtime 🚧

Client UI already exists; this is the server + wire-up.

**Events (Laravel, `ShouldBroadcast`, on the existing `private-match.{id}`):**

- `chat.message` → `{ match_id, user_id, name, color, text, ts }`
- `chat.emoji`   → `{ match_id, user_id, color, emoji, ts }` (ephemeral, not persisted)

**Endpoints** (auth + `banned`, tight limit): `POST /matches/{match}/chat`
`{ text }` and `POST /matches/{match}/emoji` `{ emoji }`. Server validates the
sender is a seated participant, applies a **length cap + profanity filter**, and
restricts **guests to canned phrases/emojis** (no free text) to limit abuse.
Rate-limit `throttle:20,1`. Persist chat to a small `match_messages` table for
moderation; emojis are fire-and-forget.

**Client:** `FriendsRepository`-style `ChatRepository.send()`, and in
`websocket_service` bind `chat.message`→`gameChatProvider.addRemote(...)` and
`chat.emoji`→`flashEmoji(...)`. Honor the new Settings toggles (mute chat/emoji).

**Moderation:** reuse the existing `Report` model; add a per-user mute and a
server-side rate/abuse guard. Est. **1–1.5 days**.

---

## 3. Phase 3 — Facebook-friends play, end-to-end 🚧

**Reality of the platform:** since Graph API v2.0, Facebook only returns friends
who **also use this app** and granted `user_friends`. A full friend list is not
obtainable. So "play with friends" = **app-using FB friends** + **share/deep-link
invites** for everyone else. Both are built here.

**Current bug to fix first:** the client posts invites as
`{ provider, friend_id, room_code }` but `FriendController@invite` expects an
internal `friend_user_id` and ignores room codes — the flow is broken. Replace
with the endpoints below.

**Backend**

- `GET /friends/facebook` — using the stored FB token, call
  `FacebookService::appFriends()`, map `provider_user_id → users` via
  `social_accounts`, return internal friends who play (with `online` flag).
- `POST /friends/invite-to-room` `{ room_id, friend_user_id }` — authorize the
  inviter is seated, then broadcast `friend.invite`
  `{ room_id, code, from: {name, avatar} }` on a **new private user channel**.
- `routes/channels.php`: `Broadcast::channel('user.{id}', fn(User $u,$id)=>
  (int)$u->id === (int)$id)` for invites + presence.
- **Invite links / deep links:** `https://ludofriends.app/r/{CODE}` (universal /
  app link) and `com.arifurrahman.ludofriends://room/{CODE}`; share via
  `share_plus` (already a dependency). Inbound link → `POST /rooms/join {code}`
  (endpoint already exists).
- **Friend codes (FB-independent):** expose each user's short code and an
  add-by-code screen (the accept path already exists in `FriendController`).
- **Presence:** maintain an `online:{userId}` Redis key refreshed on WS connect /
  heartbeat; surface it in the friends list and pods.

**Client:** build the Friends screen (list app-friends + added friends, online
dots, "Invite" buttons), an inbound-invite banner (from `user.{id}` channel),
deep-link handling, and share-sheet buttons in the room lobby. Est. **3–4 days**.

---

## 4. Phase 4 — Backend scale + hardening for 1,000 concurrent 🚧

**The one thing that will break first:** the defaults are
`CACHE_STORE=database`, `QUEUE_CONNECTION=database`, `SESSION_DRIVER=database`.
Under a few hundred concurrent realtime players these turn every cache/lock/queue
op into contended DB writes. **Move them to Redis.** This is the highest-leverage
change and is mostly configuration.

### 4.1 Redis everywhere

```dotenv
CACHE_STORE=redis
QUEUE_CONNECTION=redis
SESSION_DRIVER=redis          # API is token-based; sessions are light anyway
BROADCAST_CONNECTION=reverb
REDIS_CLIENT=phpredis          # install ext-redis; ~2–3x faster than predis
RATE_LIMITER_STORE=redis       # move throttling off the DB
```

Install the `phpredis` PHP extension on the VPS (swap from `predis`). Laravel's
`RateLimiter`, cache locks (`lockForUpdate` complements, not replaces), and queue
all then run on Redis.

### 4.2 Reverb horizontal scaling

Reverb is single-process per node. Enable Redis pub/sub scaling so multiple
Reverb workers/nodes share events:

```dotenv
REVERB_SCALING_ENABLED=true    # config/reverb.php 'scaling' => Redis pub/sub
```

Run Reverb under a process manager with several workers; put it behind the same
TLS load balancer as the API (path `/app`, sticky not required with Redis
scaling). One node comfortably holds a few thousand concurrent WS connections;
1,000 is single-node territory.

### 4.3 Queue workers + queued broadcasting

Broadcast events already implement `ShouldBroadcast`, so they dispatch through
the queue — that only helps if **workers are running**. Run a Horizon/Supervisor
pool (start ~4 workers, `--queue=broadcasts,default`). Keep broadcasts on their
own queue so a backlog of replay/leaderboard jobs never delays gameplay events.

### 4.4 Laravel Octane

Serve the API with **Octane (FrankenPHP or Swoole)** to remove per-request
bootstrap and hold warm workers: typically **3–5× throughput** vs php-fpm.
Audit for state leakage between requests (no request-scoped data in singletons;
the codebase's stateless services are already a good fit). `php artisan
octane:start --workers=auto --max-requests=500`.

### 4.5 MySQL

Indexes on the hot paths are already present (`match_events` unique
`(match_id, seq)`, etc.). For scale: `innodb_buffer_pool_size` ≈ 60–70% RAM,
`innodb_flush_log_at_trx_commit=2` (small durability trade for throughput),
connection cap sized to `(app workers + octane workers + queue workers) ×
pool`. Add composite indexes where the queries show up hot:
`matchmaking_tickets(status, mode, enqueued_at)`, `game_rooms(status,
updated_at)`.

### 4.6 Server-side turn timeout (correctness at scale)

Today AFK handling is client-side (`_autoAct`). Online matches need a
**server-authoritative** turn clock so a disconnected player can't freeze a match
(and hold a WS slot): on each `turn.changed`, dispatch a delayed job
`AutoResolveTurn(matchId, seq, deadline)`; if the seq is unchanged at the
deadline, auto-roll/skip via the engine and broadcast. This also frees stuck
matches, which is a real capacity lever.

### 4.7 Security P0s (do before public launch)

- **CORS:** `config/cors.php` → `allowed_origins` from an env allowlist (never
  `*` with `supports_credentials=true`).
- **Sanctum expiry:** set `SANCTUM_TOKEN_EXPIRATION` (e.g. 20160 = 14 days;
  shorter for guests) + schedule `sanctum:prune-expired`.
- **Encrypt secrets at rest:** `encrypted` cast on
  `social_accounts.access_token` and `guest_sessions.token`.
- **Prod env:** `APP_DEBUG=false`, `APP_ENV=production`.

Est. **2–3 days** incl. load-test tuning.

---

## 5. Phase 5 — Deployment topology & capacity 🔭

### 5.1 Capacity math

At 1,000 concurrent players (~250 four-player matches): with ~1 action / player /
10 s at peak that's **~100 req/s** to the API and **~300–400 WS msgs/s**
outbound, plus ~100 DB writes/s (event insert + state update). All of that is
**comfortably one well-tuned VPS** with Redis + Octane + a co-located or adjacent
MySQL.

At 20,000 concurrent (~5,000 matches): **~2,000 req/s**, **~8,000 WS msgs/s**,
~2,000 DB writes/s. That needs horizontal scale (below) and moving the match
**hot state into Redis** (authoritative snapshot in Redis, async-persisted to
MySQL) so the per-move path avoids a locked DB round-trip.

### 5.2 Topology

**1,000 concurrent — start here (single or split):**

```
            ┌── nginx / TLS LB ──┐
 clients ──▶│  /api → Octane app │  (1 node, 4–8 vCPU / 8–16 GB)
            │  /app → Reverb     │  (same node or a 2 vCPU / 4 GB node)
            └────────┬───────────┘
                     ├── Redis        (cache/queue/session/presence/pubsub)
                     ├── MySQL 8      (2–4 vCPU / 8–16 GB, tuned innodb)
                     └── queue workers (Horizon, 4 workers)
```

**Path to 20,000 — scale out each tier:**

```
 clients ─▶ LB ─▶ [Octane app ×3–4]     (stateless; add nodes as needed)
              └─▶ [Reverb ×2–3]          (Redis pub/sub scaling; LB /app)
   Redis: 1 large instance → cluster     (presence + hot match state)
   MySQL: primary + 1–2 read replicas    (reads: leaderboard, history, lobby)
   Workers: separate box, Horizon autoscale
```

### 5.3 Load-test method (prove it before launch)

- **API + DB:** `k6` scripting a full match loop (auth → create/join → roll →
  move) ramped to 250, 500, 1,000 concurrent match-loops; watch p95 latency, DB
  CPU, Redis ops.
- **WebSocket:** a Node/`ws` harness opening 1,000 subscriptions to
  `private-match.*` and asserting event fan-out latency < 250 ms p95.
- Tune buffer pool / worker counts against the numbers; re-run.

### 5.4 Monitoring

Laravel Telescope (staging) / Sentry (prod) for errors; Reverb connection gauge;
Redis + MySQL exporters → Grafana; alert on queue depth, WS connection count, and
p95 action latency.

---

## 6. Suggested sequencing

1. **Ship Phase 1** (this pass) after `flutter analyze`/`test` locally.
2. **Phase 4.1–4.3 + 4.7** (Redis + workers + security P0s) — small, highest ROI,
   unblocks a safe public beta.
3. **Phase 2** (chat/emoji realtime) — the client is already built.
4. **Phase 3** (friends play) — the visible social feature.
5. **Phase 4.4–4.6 + Phase 5** (Octane, turn-timeout, load test, topology) as you
   approach the 20k target.
