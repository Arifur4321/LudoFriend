# Ludo Friends — Visual Asset Set

Original, license-safe art for the **Ludo Friends** mobile game. Every file in this
folder was hand-authored as clean, vector-first **SVG** (plus two tiny Lottie JSON
animations). Nothing here copies, traces, or derives from "Ludo King" or any other
existing game's logo, board, tokens, icons, or brand style. The identity, mark,
wordmark, and palette are our own.

> **Originality & licensing:** 100% original work created for this project.
> No third-party trademarks, logos, fonts-as-files, or copied artwork are embedded.
> Every SVG has a `viewBox`, no external references (only the standard
> `xmlns="http://www.w3.org/2000/svg"` namespace), and all `url(#…)` fills point to
> gradients/patterns defined inside the same file. Safe to ship.

> **Facebook note:** We deliberately do **not** draw the Facebook logo. `btn_facebook_bg.svg`
> is a neutral pill button background only; the app overlays the **official Facebook SDK**
> button/label at runtime to satisfy brand guidelines. `icon_friends.svg` is a generic
> "friends" glyph (two people + spark), not a Facebook mark.

---

## Brand palette

Use these consistently across every asset and in app theming.

| Role | Name | Hex |
|---|---|---|
| Primary | Brand purple | `#5B3FD6` |
| Primary (deep) | Purple deep | `#3F2BA8` |
| Primary (light) | Purple light | `#8E6BFF` |
| Secondary | Coral | `#FF6B6B` |
| Accent | Sunny | `#FFC542` |
| Board base | Cream | `#FFF7EC` |
| Board line | Line | `#E7DCC8` |
| Text | Ink | `#2A2440` |
| Token RED | | `#FF5A5F` |
| Token GREEN | | `#2BD9A1` |
| Token YELLOW | | `#FFB23E` |
| Token BLUE | | `#3A86FF` |
| Background gradient | | `#6A4CE0` → `#8E6BFF` |

**Style language:** rounded, friendly, modern shapes; soft shadows via subtle
gradients; consistent ~2px stroke weight; flat-but-polished with gentle white
highlights. Wordmark uses a rounded heavy sans (Baloo 2 / Nunito family, with
`Segoe UI`/`sans-serif` fallback declared inline — no font files bundled).

---

## Folder layout

```
app/assets/
├── svg/            # all vector art (32 files)
├── animations/     # Lottie JSON (2 files)
└── README_ASSETS.md
```

---

## Asset inventory

### Branding & identity (`svg/`)

| File | Purpose | viewBox / size |
|---|---|---|
| `logo_ludo_friends.svg` | Full lockup: mark (four pawns arcing a die) + "Ludo Friends" wordmark | 480 × 160 |
| `app_icon.svg` | App icon source — bold centered mark on purple-gradient rounded square | 1024 × 1024 |
| `splash_logo.svg` | Centered mark + wordmark for splash, transparent bg | 512 × 512 |

### Dice (`svg/`) — white rounded-square die, palette-colored pips, consistent layout

| File | Face | viewBox |
|---|---|---|
| `die_1.svg` … `die_6.svg` | Pips 1–6 | 120 × 120 each |

### Player tokens (`svg/`) — rounded teardrop pawn, highlight + ground shadow

| File | Color | viewBox |
|---|---|---|
| `token_red.svg` | RED `#FF5A5F` | 96 × 96 |
| `token_green.svg` | GREEN `#2BD9A1` | 96 × 96 |
| `token_yellow.svg` | YELLOW `#FFB23E` | 96 × 96 |
| `token_blue.svg` | BLUE `#3A86FF` | 96 × 96 |
| `token_red_glow.svg` | RED + active glow/ring (selectable) | 96 × 96 |
| `token_green_glow.svg` | GREEN + active glow/ring | 96 × 96 |
| `token_yellow_glow.svg` | YELLOW + active glow/ring | 96 × 96 |
| `token_blue_glow.svg` | BLUE + active glow/ring | 96 × 96 |

### Avatars (`svg/`) — friendly circular, tinted backgrounds

| File | Purpose | viewBox |
|---|---|---|
| `avatar_guest.svg` | Guest (silhouette + "?" badge) | 128 × 128 |
| `avatar_neutral.svg` | Neutral / default | 128 × 128 |
| `avatar_male.svg` | Male presentation | 128 × 128 |
| `avatar_female.svg` | Female presentation | 128 × 128 |

### Icon set (`svg/`) — consistent 64 × 64, ~2px stroke language

| File | Purpose |
|---|---|
| `icon_coin.svg` | Soft currency / coins |
| `icon_trophy.svg` | Wins / leaderboard |
| `icon_crown.svg` | Winner / VIP |
| `icon_room.svg` | Game room / table (4 player dots) |
| `icon_friends.svg` | Friends (generic, FB-safe) |
| `icon_bot.svg` | Bot / AI opponent |
| `icon_dice.svg` | Roll / dice action |
| `icon_sound_on.svg` | Audio on |
| `icon_sound_off.svg` | Audio muted |

### UI & decoration (`svg/`)

| File | Purpose | viewBox |
|---|---|---|
| `btn_facebook_bg.svg` | Neutral "Continue with Facebook" pill background (no logo; SDK label at runtime) | 320 × 56 (non-uniform scale) |
| `bg_pattern.svg` | Subtle seamless-tile geometric pattern (pawns/dots/diamonds) on purple gradient | 240 × 240 (tile = 120) |
| `board_decor_corner.svg` | Optional decorative corner flourish for the board frame (rotate/flip for 4 corners) | 120 × 120 |

### Spot illustrations (`svg/`) — friendly, ~320 × 240

| File | Purpose |
|---|---|
| `illus_no_internet.svg` | Offline / no connection state (broken wifi + sad pawn) |
| `illus_empty_state.svg` | Empty list / no rooms yet (empty board + floating die) |
| `illus_error.svg` | Generic error (tipped-over dizzy pawn + warning triangle) |

### Animations (`animations/`) — Lottie JSON for the `lottie` Flutter package

| File | Purpose | Canvas / frames |
|---|---|---|
| `confetti.json` | Win celebration — 5 colored confetti pieces falling & spinning | 300 × 300, 30 fps, 90 frames |
| `loading_spinner.json` | Loading — dual rotating trimmed arcs + pulsing center dot | 120 × 120, 30 fps, 60 frames (loops) |

Both are minimal, self-contained, schema-valid Lottie (`v`, `fr`, `ip`, `op`, `w`, `h`,
`layers`) and verified to parse as JSON. If you ever prefer a code-driven fallback,
the app can swap either for a `CustomPainter` — but these load fine with
`Lottie.asset('assets/animations/confetti.json')`.

---

## Using the SVGs in Flutter

Render vectors directly with [`flutter_svg`](https://pub.dev/packages/flutter_svg):

```dart
import 'package:flutter_svg/flutter_svg.dart';

SvgPicture.asset('assets/svg/token_red.svg', width: 48);
SvgPicture.asset('assets/svg/icon_dice.svg', width: 28);
```

Register the folders in `pubspec.yaml`:

```yaml
flutter:
  assets:
    - assets/svg/
    - assets/animations/
```

---

## Generating optimized raster (WebP / PNG) when you need it

Vectors are preferred at runtime. For places that need raster (e.g. store
listings, OG images, or perf-critical sprites), rasterize the SVGs.

### Prerequisites
- `rsvg-convert` (librsvg) **or** Inkscape — SVG → PNG
- `cwebp` (libwebp) — PNG → WebP

### Single asset, SVG → WebP (pipe, no temp file)

```bash
# 192px-wide red token, quality 90 WebP
rsvg-convert -w 192 svg/token_red.svg | cwebp -q 90 -o token_red.webp -
```

### Inkscape alternative (if rsvg-convert is unavailable)

```bash
inkscape svg/token_red.svg -w 192 --export-type=png -o token_red.png
cwebp -q 90 token_red.png -o token_red.webp
```

### Batch every SVG to @1x/@2x/@3x WebP

```bash
mkdir -p webp/1x webp/2x webp/3x
for f in svg/*.svg; do
  name="$(basename "${f%.svg}")"
  rsvg-convert -w 96  "$f" | cwebp -q 90 -o "webp/1x/${name}.webp" -
  rsvg-convert -w 192 "$f" | cwebp -q 90 -o "webp/2x/${name}.webp" -
  rsvg-convert -w 288 "$f" | cwebp -q 90 -o "webp/3x/${name}.webp" -
done
```

(Scale the `-w` values per asset; e.g. dice 120, tokens 96, icons 64, avatars 128,
illustrations 320, app icon 1024.)

### Lossless WebP (for crisp UI icons)

```bash
rsvg-convert -w 128 svg/icon_crown.svg | cwebp -lossless -o icon_crown.webp -
```

---

## Exporting PNG app icons via `flutter_launcher_icons`

`app_icon.svg` is the 1024×1024 source. Rasterize it once to a PNG master, then let
`flutter_launcher_icons` generate every platform size.

1. Rasterize the master PNG:

   ```bash
   rsvg-convert -w 1024 -h 1024 svg/app_icon.svg -o app_icon_1024.png
   # (or) inkscape svg/app_icon.svg -w 1024 -h 1024 --export-type=png -o app_icon_1024.png
   ```

2. Add the dev dependency:

   ```yaml
   dev_dependencies:
     flutter_launcher_icons: ^0.13.1
   ```

3. Configure (in `pubspec.yaml` or `flutter_launcher_icons.yaml`):

   ```yaml
   flutter_launcher_icons:
     image_path: "assets/app_icon_1024.png"
     android: true
     ios: true
     min_sdk_android: 21
     adaptive_icon_background: "#5B3FD6"
     adaptive_icon_foreground: "assets/app_icon_1024.png"
     web:
       generate: true
       background_color: "#5B3FD6"
       theme_color: "#5B3FD6"
   ```

4. Generate:

   ```bash
   dart run flutter_launcher_icons
   ```

For the splash screen, pair with `flutter_native_splash` using `splash_logo.svg`
rasterized similarly and `color: "#6A4CE0"`.

---

## Notes
- This document lives at `app/assets/README_ASSETS.md`. You may copy it to
  `docs/ASSETS.md` for top-level discoverability:
  `cp app/assets/README_ASSETS.md docs/ASSETS.md`.
- Keep new assets on-palette and in the same rounded, friendly style to stay cohesive.
