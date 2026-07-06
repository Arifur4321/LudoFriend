# Ludo Friends — Coin Economy (Wallet, Daily Spin, Staked Boards, Store)

This document describes the coin-economy features added on top of the existing
server-authoritative Ludo core, across the Laravel backend and the Flutter app.

## What was added

- **Coin wallet with an audited ledger.** Every coin movement is one immutable
  `wallet_transactions` row (signed amount + resulting balance). The cached
  `player_profiles.coins` column is kept in sync; the ledger is the source of
  truth. New accounts are seeded with a `signup_bonus` (500 coins) through the
  ledger.
- **Hourly free spin.** A weighted prize wheel (rare jackpots) claimable once
  every 60 minutes (rolling cooldown, `interval_minutes` in config), decided
  **server-side** (the client only animates to the chosen segment). Rewards
  range 500 → 20,000. The home screen shows a glowing "Free Spin" badge with a
  live countdown and pops a one-time "ready" prompt after login.
- **Six staked board tiers with distinct faux-3D designs.** Classic 200,
  Bronze 500, Silver 1,000, Gold 5,000, Emerald 10,000, Diamond 20,000 — each
  with its own gradient/bevel/motif/dice colours. The in-game die is a real
  **isometric 3D cube** (top + two shaded side faces with pips) that tumbles
  when rolled, themed per tier. A hidden free **Casual** tier backs quick-match /
  bot-fill / offline practice.
- **On-device SQLite cache.** Last-known coin balance, free-spin unlock time and
  selected board are cached locally (sqflite) so the wallet chip and countdown
  render instantly on cold start; falls back to an in-memory cache if the DB
  can't open.
- **Winner-takes-all pots + 2v2 teams.** Each seat pays the board stake into an
  escrow pot at match start; the winner takes the full pot. On 4-player boards
  you can play **2v2 teams** — the winning team splits the pot evenly. Pure
  winner-takes-all (house rake configurable, default 0%).
- **Coin store (IAP-ready).** Purchasable coin packs credited via the wallet.
  Receipt verification is gated behind a flag so real-money paths stay safe
  until store credentials are added.
- **Google login.** Backend `/auth/google` verifies a Google ID token; the
  Flutter client already had the Google + Facebook buttons wired.

## Backend architecture (`backend/`)

| Concern | Where |
|---|---|
| Coin ledger (only place coins move) | `app/Services/Economy/WalletService.php` |
| Free spin (weighted, hourly cooldown, atomic) | `app/Services/Economy/FreeSpinService.php` |
| Board tiers resolver / validation | `app/Services/Economy/BoardService.php` |
| Coin store + receipt verification | `app/Services/Economy/StoreService.php` |
| Stake escrow at match start | `app/Services/RoomService.php` → `start()` |
| Pot payout + 2v2 split + refund | `app/Services/Game/GameEngineService.php` |
| Google ID-token verification | `app/Services/GoogleService.php` |
| Idle-match abort + refund (scheduled) | `app/Jobs/ExpireStaleMatches.php` |
| Single source of truth (tiers/spin/packs/flags) | `config/economy.php` |

Ledger, spins, stakes and teams are added via additive migrations
(`database/migrations/2026_07_06_*`). Coins never move outside `WalletService`,
which locks the wallet row `FOR UPDATE` inside a transaction, so concurrent
stakes/prizes/spins/purchases can't race into a wrong balance. Staking is
atomic: if any seat can't afford the buy-in at start, the whole match creation
rolls back — no partial escrow.

## API (all under `/api/v1`, bearer-authenticated)

| Method | Path | Purpose |
|---|---|---|
| GET | `/wallet` | balance + recent ledger |
| GET | `/wallet/transactions?limit=` | ledger history |
| GET | `/boards` | staked tiers + affordability |
| GET | `/spin/status` | can-spin + next-unlock + wheel layout |
| POST | `/spin` | claim free spin (hourly cooldown) |
| GET | `/store/packs` | coin packs |
| POST | `/store/purchase` | verify + credit a purchase |
| POST | `/auth/google` | Google login (public) |

Rooms gained `board_tier`, `team_mode` inputs; matches expose
`stake`, `pot`, `team_mode`, and per-seat `team`/`payout`.

## Economy rules

- **Starting coins:** 500 (`LUDO_STARTING_COINS`).
- **Board stakes:** 200 / 500 / 1,000 / 5,000 / 10,000 / 20,000.
- **Payout:** winner takes 100% of the pot; 2v2 winning team splits it evenly
  (odd remainder to the finisher). Rake `LUDO_HOUSE_RAKE_BPS` default `0`.
- **Free spin:** claimable every `LUDO_FREE_SPIN_INTERVAL_MINUTES` (default 60).
  Odds (weight / total 1000): 500→30%, 750→22%, 1,000→20%, 1,500→13%,
  2,500→8%, 5,000→4.5%, 10,000→2%, 20,000→0.5% (EV ≈ 1,435 **per spin**). At the
  60-min default that's up to ~24 spins/day (~34k coins/day) — lower the segment
  rewards or raise the interval in `config/economy.php` to tighten the economy.
- **Refunds:** an aborted/idle match refunds every escrowed stake.

## Flutter (`app/lib/`)

- `features/wallet/` — balance chip (in the home bar), wallet + ledger screen.
- `features/spin/` — animated prize wheel that spins to the server-chosen segment.
- `features/boards/` — board picker with a live themed preview of each tier.
- `features/store/` — coin-pack grid wired to the purchase endpoint.
- `shared/theme/board_theme.dart` — the six board themes; the game board
  (`board_painter.dart`) renders the active theme.

## Known limitations / next steps

- **Staked *online* multiplayer requires the Phase-2 online room/match flow**,
  which was already "in progress" in this repo (the client's room/lobby is a
  local draft that runs an offline bot match). The **backend fully implements
  and tests** staking, escrow, winner/team payout and refunds, so real
  coin-staked online play activates once that client flow is completed. Today
  the board picker launches each tier as **themed practice** (no coins charged
  offline); the wallet, daily spin and coin store are fully functional over REST.
- **Google/Facebook login and the coin store are inert until credentials are
  added** (see `RUN_AND_TEST.md`), matching the repo's existing "monetization
  off by default" pattern.
