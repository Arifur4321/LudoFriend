# Game rules & engine model

These rules are implemented in `app/lib/game_engine/` and mirrored by the
backend's `LudoRules`. They were verified with an independent reference model
before being ported (see the engine unit tests).

## Board model (coordinate-free core)

- **Shared ring:** 52 cells, absolute index `0..51`.
- **Start offsets:** red `0`, green `13`, yellow `26`, blue `39`.
- **Token relative position** (`Token.position`):
  - `-1` — in base/yard
  - `0..50` — on the shared ring (relative to the token's start)
  - `51..55` — inside the private home column
  - `56` — finished (home)
- **Absolute cell** for capture/safe checks: `(startOffset[color] + rel) % 52`
  for `rel ∈ 0..50`; home-column cells are private and never collide.
- **Safe cells:** `{0, 8, 13, 21, 26, 34, 39, 47}` — the four colored start cells
  and four star cells.

## Rules

1. **Leave base only on a 6** — a token moves from base (`-1`) to its start (`0`)
   only when a 6 is rolled.
2. **Exact landing** — a move of `d` from `rel` is legal only if `rel + d ≤ 56`;
   you must land exactly on `56` to finish.
3. **Capture** — landing on a ring cell occupied by an opponent sends that
   opponent back to base, **unless** the cell is safe. No captures in home
   columns.
4. **Extra turn** — granted on a 6, on a capture, or on reaching home.
5. **Three sixes** — a third consecutive 6 forfeits that roll and ends the turn.
6. **Winner** — first color with all four tokens at `56` wins.

All of the above are configurable via `RuleConfig` (`rollAgainOnSix`,
`captureGrantsExtraTurn`, `threeSixesForfeitsTurn`, `turnTimerSeconds`, …) so the
same engine supports rule variants and 2- or 4-player games.

## Rendering coordinates

`BoardLayout` maps positions to a 15×15 grid (verified to render the standard
Ludo cross). The 52 ring cells, the four 6-cell home columns and the four base
yards each have explicit grid coordinates; movement animation interpolates along
the engine's `MoveResult.path`.

## Tested scenarios

`leave-base-only-on-6`, `extra turn on 6`, `three consecutive sixes forfeit`,
`capture`, `safe-cell protection`, `no capture in home column`, `exact home
landing`, `winner detection`, `2p & 4p full-game termination`, plus
serialization round-trip and bot legality/priority.
