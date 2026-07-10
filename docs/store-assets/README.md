# Ludo Friends — Store Assets

Production art for the Google Play listing. All art is original LudoFriend style
(Ludo board/dice + four tokens on the brand purple gradient). **No third-party
logos** (no Facebook/Google marks) are used in the icon or feature graphic.

## Inventory

| File | Size | Where it's used |
|------|------|-----------------|
| `play_icon_512.png` | 512×512 PNG (32-bit) | Play Console → Store listing → **App icon** |
| `feature_graphic_1024x500.png` | 1024×500 PNG | Play Console → Store listing → **Feature graphic** |

Source art: `docs/meta/ludo_friends_meta_icon_1024.png` (1024×1024), which is the
same art as the in-app launcher source `app/assets/images/app_icon.png`.

> The feature graphic is a clean, ready-to-use placeholder. Swap the wordmark
> font for Fredoka (the in-app font) later if you want it pixel-identical to the
> app's typography.

## Android launcher icons (in-app)

The Android/iOS launcher icons are generated from
`app/assets/images/app_icon.png` by **flutter_launcher_icons** (already
configured in `app/pubspec.yaml`). To regenerate after changing the source:

```bash
cd app
flutter pub get
dart run flutter_launcher_icons
```

## Regenerating the store assets

Requires Python 3 + Pillow (`pip install pillow`). From the repo root:

```bash
python3 - <<'PY'
from PIL import Image, ImageDraw, ImageFont
src = Image.open('docs/meta/ludo_friends_meta_icon_1024.png').convert('RGBA')
out = 'docs/store-assets'

# 512x512 Play icon
src.resize((512, 512), Image.LANCZOS).save(f'{out}/play_icon_512.png')

# 1024x500 feature graphic
W, H = 1024, 500
c_tl, c_br = (106, 76, 224), (142, 107, 255)
cx = tuple(int((a+b)/2) for a, b in zip(c_tl, c_br))
g = Image.new('RGB', (2, 2)); g.putpixel((0,0), c_tl); g.putpixel((1,1), c_br)
g.putpixel((1,0), cx); g.putpixel((0,1), cx)
fg = g.resize((W, H), Image.BICUBIC).convert('RGBA')
D = 372; emb = src.resize((D, D), Image.LANCZOS)
m = Image.new('L', (D, D), 0); ImageDraw.Draw(m).ellipse([0,0,D,D], fill=255)
emb.putalpha(m); ex, ey = 70, (H-D)//2; fg.alpha_composite(emb, (ex, ey))
d = ImageDraw.Draw(fg)
FB = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
FR = '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
tx = ex + D + 46; avail = W - tx - 40; size = 96
while size > 40 and d.textlength('Ludo Friends', font=ImageFont.truetype(FB, size)) > avail:
    size -= 2
title = ImageFont.truetype(FB, size); sub = ImageFont.truetype(FR, 34)
ty = (H - (size + 24 + 34)) // 2
d.text((tx, ty), 'Ludo Friends', font=title, fill=(255,255,255,255))
d.text((tx+1, ty+size+20), 'Play Ludo online with friends', font=sub, fill=(255,255,255,235))
fg.convert('RGB').save(f'{out}/feature_graphic_1024x500.png')
print('done')
PY
```

## Play listing quick reference

- **App name:** Ludo Friends
- **Category:** Game / Board
- **App icon:** `play_icon_512.png`
- **Feature graphic:** `feature_graphic_1024x500.png`
- **Screenshots:** capture from a device/emulator (phone 16:9 or 9:16, min 320px) —
  Home, Board (with names/photos), Coin Store, Profile, Wallet.
