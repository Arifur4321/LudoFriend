# Ludo Friends — Senior Developer Analysis

**Scope:** Read-only review of `app/` (Flutter client) and `backend/` (Laravel 11 API), all subfolders.
**Date:** 2026-06-30 · **No code was changed and nothing was pushed.**

---

## 1. Verdict

This is a genuinely well-engineered Phase-1 codebase — well above the quality typical of a hobby game project. The standout is a **correctly implemented server-authoritative multiplayer core**: row-level locking, DB transactions, anti-replay via a unique per-match sequence, and server-side recomputation of every move (the client is never trusted). Architecture, layering, naming, and tests on the critical paths are all sound.

The work needed before a Phase-2 online launch is mostly **hardening and ops** (CORS, token expiry, secret encryption, CI), not rework. Roughly **~6,800 LOC** of Dart and **~4,300 LOC** of PHP, both cleanly organized.

| Area | Rating |
|------|--------|
| Architecture & layering | Excellent |
| Server-authoritative correctness | Excellent |
| Concurrency control | Strong |
| Test coverage (critical paths) | Good |
| Security posture | Good, with must-fix prod gaps |
| Ops / CI / release readiness | Needs work |

---

## 2. Architecture

### 2.1 Flutter app (`app/lib/`)

Feature-first, layered cleanly:

- **`core/`** — cross-cutting infra: `config/` (env + app config), `di/providers.dart` (Riverpod), `network/` (Dio client, endpoints, typed `ApiResult`), `router/` (go_router), `storage/` (secure + prefs), `errors/` (typed exceptions/failures), `utils/`.
- **`features/<feature>/{application,data,presentation}/`** — auth, home, game, room, matchmaking, leaderboard, profile, settings, friends, help, onboarding, splash, common. Consistent triad of controller (application) / repository (data) / screens & widgets (presentation).
- **`game_engine/`** — **pure, deterministic Dart** rules engine (no Flutter, no I/O, no randomness injected externally). Models, bot strategy, rule config. This is the same logic mirrored on the server.
- **`services/`** — `realtime/` (hand-rolled Pusher-protocol WebSocket client), `audio/`, `analytics/`, `ads/`, `iap/`, `facebook/`, `google/`, `social/`. Monetization hooks are **disabled by default** behind config flags.
- **`shared/`** — theme (colors, gradients, text styles), reusable widgets.
- **`l10n/`** — 4 locales (en, it, bn, hi) with generated localizations.

Stack: Riverpod (DI/state) · go_router (nav) · Dio (HTTP, bearer-token interceptor + typed failure mapping) · flutter_secure_storage (token at rest) · web_socket_channel (realtime).

### 2.2 Laravel backend (`backend/app/`)

Textbook Laravel layering with thin controllers and real logic in services:

- **Controllers (`Http/Controllers/Api/`)** — thin HTTP adapters; e.g. `GameController` authorizes via policy then delegates to the engine.
- **Services (`Services/`)** — `GameEngineService` (authoritative referee), `LudoRules` (pure ruleset), `RoomService`, `MatchmakingService`, `FacebookService`.
- **FormRequests (`Http/Requests/`)** — validation isolated per endpoint.
- **Resources (`Http/Resources/`)** — response shaping.
- **Policies (`Policies/`)** — `MatchPolicy`, `RoomPolicy` for per-action authorization.
- **Events (`Events/`)** — 10 broadcast events (dice, move, turn, join/leave, ready, disconnect/reconnect, start/end).
- **Jobs (`Jobs/`)** — `ExpireStaleRooms`, `PersistMatchReplay`, `RecalculateLeaderboard`.
- **Config (`config/ludo.php`)** — **single source of truth** for every gameplay constant, consumed by `LudoRules`.

Stack: Laravel 11 · Sanctum (bearer tokens) · Reverb (WebSockets) · Predis/Redis · MySQL.

---

## 3. What's done right (keep doing this)

1. **Server-authoritative anti-cheat.** `GameEngineService::move()` recomputes legal moves server-side and rejects anything not in the legal set; the client only names *which token*, never the destination or captures (`GameEngineService.php:253–262`).
2. **Anti-replay, two layers.** An explicit expected-`seq` check *plus* a DB `unique(match_id, seq)` constraint on `match_events` — duplicate/out-of-order actions can't be persisted (`GameEngineService.php:243–246`, migration `...001000`).
3. **Concurrency via row locks.** `lockForUpdate()` inside `DB::transaction()` for match state mutation, room join, and matchmaking — protects against join races and double-moves (`GameEngineService.php:121,234`; `RoomService.php:62–76`; `MatchmakingService.php`).
4. **Single source of truth for rules.** `config/ludo.php` feeds `LudoRules`; the Dart engine mirrors it. No magic numbers duplicated across the server.
5. **Right things are tested.** Feature tests assert the five guarantees that matter — wrong-turn rejection, illegal-move rejection, replay rejection, win/finish detection, reconnect — plus matchmaking and room join/leave. Unit test for `LudoRules`.
6. **Sound API design.** Versioned (`/api/v1`), tiered rate limits (auth 6/min, game 30/min, api 60/min), private broadcast channels authorized to seated participants only (`channels.php`).
7. **Clean error handling.** Typed `Failure` hierarchy on the client; `RuntimeException → 422` with readable messages on the server.
8. **Proper scheduling.** `routes/console.php` wires `ExpireStaleRooms` (every minute, `withoutOverlapping`) and `RecalculateLeaderboard` (hourly/6-hourly).

---

## 4. Findings & recommendations (prioritized)

### P0 — Fix before any production/online deployment

- **CORS wildcard + credentials.** `config/cors.php` defaults `allowed_origins` to `*` while `supports_credentials => true`. That combination is invalid per the CORS spec and unsafe for the credentialed paths (`broadcasting/auth`, `sanctum/csrf-cookie`). **Action:** set `CORS_ALLOWED_ORIGINS` to an explicit allowlist in production; never ship `*` with credentials.
- **Sanctum tokens never expire by default.** `config/sanctum.php` reads `expiration` from `SANCTUM_TOKEN_EXPIRATION`, which is unset → tokens are effectively permanent. **Action:** set an expiration (and a refresh/rotation story), shorter for guest tokens.
- **Third-party secrets stored in plaintext.** `social_accounts.access_token` (Facebook) and `guest_sessions.token` are persisted unencrypted. **Action:** use Eloquent `encrypted` casts (or drop the FB token if you don't reuse it server-side).
- **Production debug flag.** `.env.example` ships `APP_DEBUG=true`. Fine for an example, but confirm prod sets `APP_DEBUG=false` and `APP_ENV=production` so stack traces aren't leaked.

### P1 — Correctness / parity (address during Phase 2)

- **Client↔server engine divergence in turn advance.** Backend `advanceTurn()` skips colors that have already finished; the Dart `_advanceTurn()` simply does `(index+1) % players.length` and does **not** skip finished players (`ludo_engine.dart:220`). Harmless while a single winner ends the match, but it will desync if you ever support play-to-2nd/3rd place offline. Keep the two engines behaviorally identical.
- **Blocking/"doubles" not modeled.** Two opponent tokens can co-occupy a ring cell and both get captured; there's no block/stack rule. This is documented as intentional in `LudoRules`, but confirm it matches `docs/GAME_RULES.md` and product intent.
- **`legalMoves().captures` is not color-qualified.** It returns a flat list of opponent token indexes, ambiguous if ever used for more than a capture count. `applyMove()` resolves captures correctly with color, so this is presentational only — worth a comment or a richer shape to avoid future misuse (`LudoRules.php:323–346`).
- **Replay fidelity.** Dice use `random_int` (good — secure, not seeded). Exact reproduction relies on the persisted `dice_rolled` events rather than a seed; since each roll is recorded, data-driven replay works — just don't switch to recomputing rolls from a seed later expecting determinism.

### P2 — Ops, tooling, hygiene

- **No CI.** There's no `.github/workflows/`. **Action:** add CI to run `flutter analyze` + `flutter test`, and `php artisan test` + `pint --test` on every PR. High leverage given the parity and line-ending risks below.
- **Line-ending churn in the working tree.** `git status` shows **329 files "modified" with 19,816 insertions / 19,816 deletions** — equal counts, every line removed and re-added. This is pure CRLF↔LF normalization, not real edits. **Action:** add a `.gitattributes` (`* text=auto eol=lf`, with `*.bat eol=crlf`) and renormalize, *before* committing, so you don't bury a real change in a 19k-line noise diff. (Nothing was pushed — good.)
- **Release logging.** `AppLogger.e()` always logs (including request URIs surfaced from Dio's `onError`) regardless of environment (`logger.dart`). **Action:** route error logging through the analytics/crash hook in release and avoid logging full URIs / any PII.
- **Lint strictness.** Client uses `flutter_lints` + a handful of extra rules; backend has Pint but no enforcement. Consider a stricter analysis set and wiring `pint`/`dart format --set-exit-if-changed` into CI.
- **Guest account model.** Guest re-auth is keyed solely on a client-supplied `device_id` (`AuthController::guest`). Anyone presenting a known `device_id` assumes that guest. Acceptable for throwaway guests, but document it and consider binding the stored `guest_sessions.token` into the handshake if guest progress becomes valuable.

---

## 5. Suggested sequencing for "later steps"

1. **Repo hygiene first:** add `.gitattributes`, renormalize line endings, add CI — so subsequent real diffs are reviewable.
2. **P0 security pass:** CORS allowlist, Sanctum expiration, encrypted secret casts, prod env defaults.
3. **Engine parity:** align Dart `_advanceTurn` with the server, add a cross-engine test (same inputs → same state) if you can share fixtures.
4. **Phase-2 functionality:** finish online room/match flows end-to-end against Reverb, exercise reconnect within `reconnect_grace_seconds`, load-test matchmaking + bot-fill.

---

*Read-only analysis. No files in `app/` or `backend/` were modified; no commits or pushes were made. This report is the only file added (`SENIOR_DEV_ANALYSIS.md` at repo root) — delete it freely.*
