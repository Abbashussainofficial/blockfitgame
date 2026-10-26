#!/usr/bin/env python3
"""Generates Block Fit's PLACEHOLDER launcher icons and store graphics.

    python3 tools/generate_icons.py

Pure Python (no Pillow needed). Draws the same 3x3 block logo the app shows.

Outputs
  android/app/src/main/res/mipmap-*/ic_launcher.png        legacy icon
  android/app/src/main/res/mipmap-*/ic_launcher_round.png  legacy round icon
  android/app/src/main/res/drawable/ic_launcher_foreground.xml   adaptive fg
  android/app/src/main/res/drawable/ic_launcher_monochrome.xml   themed icon
  android/app/src/main/res/mipmap-anydpi-v26/ic_launcher(_round).xml
  android/app/src/main/res/values/ic_launcher_background.xml
  store/graphics/icon-512.png                Play Store listing icon
  store/graphics/feature-graphic-1024x500.png

TO REPLACE WITH A DESIGNED ICON: in Android Studio use
File > New > Image Asset (Launcher Icons, Adaptive and Legacy) with a 1024 px
source image; it overwrites the files above. Replace the two PNGs in
store/graphics/ separately.
"""
import math
import os
import struct
import zlib

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
RES = os.path.join(ROOT, 'android', 'app', 'src', 'main', 'res')
STORE = os.path.join(ROOT, 'store', 'graphics')

# Classic Dark theme colours (lib/core/game_theme.dart).
BG_TOP = (0x1B, 0x21, 0x38)
BG_BOTTOM = (0x0E, 0x12, 0x22)
EMPTY = (0x23, 0x2A, 0x45)
BLOCKS = {0: (0xFF, 0xC9, 0x3C), 3: (0x7C, 0x4D, 0xFF), 5: (0xFF, 0x5C, 0x8A)}
# Same pattern as BlockFitLogo in lib/ui/widgets/common.dart (-1 = gap).
LOGO = [[0, -1, 5], [0, 3, 3], [0, 0, 3]]


# ---------------------------------------------------------------- raster ---

class Canvas:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.px = [[0.0, 0.0, 0.0, 0.0] for _ in range(w * h)]  # rgba 0..1

    def blend(self, x, y, rgb, a):
        if a <= 0:
            return
        p = self.px[y * self.w + x]
        r, g, b = (c / 255 for c in rgb)
        out_a = a + p[3] * (1 - a)
        if out_a <= 0:
            return
        for i, c in enumerate((r, g, b)):
            p[i] = (c * a + p[i] * p[3] * (1 - a)) / out_a
        p[3] = out_a

    def fill_sdf(self, bbox, sdf, rgb, alpha=1.0):
        """Fills a shape given its signed distance function (pixels)."""
        x0, y0, x1, y1 = bbox
        for y in range(max(0, int(y0) - 1), min(self.h, int(y1) + 2)):
            for x in range(max(0, int(x0) - 1), min(self.w, int(x1) + 2)):
                d = sdf(x + 0.5, y + 0.5)
                cov = min(1.0, max(0.0, 0.5 - d))  # 1px anti-aliasing
                if cov > 0:
                    self.blend(x, y, rgb, cov * alpha)

    def gradient(self, top, bottom):
        for y in range(self.h):
            t = y / max(1, self.h - 1)
            rgb = tuple(int(a + (b - a) * t) for a, b in zip(top, bottom))
            for x in range(self.w):
                self.blend(x, y, rgb, 1.0)

    def png(self, path):
        os.makedirs(os.path.dirname(path), exist_ok=True)
        raw = bytearray()
        for y in range(self.h):
            raw.append(0)
            for x in range(self.w):
                r, g, b, a = self.px[y * self.w + x]
                raw += bytes(int(max(0, min(1, v)) * 255 + 0.5) for v in (r, g, b, a))

        def chunk(tag, data):
            c = struct.pack('>I', len(data)) + tag + data
            return c + struct.pack('>I', zlib.crc32(tag + data) & 0xFFFFFFFF)

        with open(path, 'wb') as f:
            f.write(b'\x89PNG\r\n\x1a\n')
            f.write(chunk(b'IHDR', struct.pack('>IIBBBBB', self.w, self.h, 8, 6, 0, 0, 0)))
            f.write(chunk(b'IDAT', zlib.compress(bytes(raw), 9)))
            f.write(chunk(b'IEND', b''))
        print('wrote', os.path.relpath(path, ROOT))


def rrect_sdf(x0, y0, x1, y1, r):
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    hx, hy = (x1 - x0) / 2 - r, (y1 - y0) / 2 - r

    def sdf(px, py):
        qx, qy = abs(px - cx) - hx, abs(py - cy) - hy
        out = math.hypot(max(qx, 0), max(qy, 0))
        return out + min(max(qx, qy), 0) - r
    return sdf


def circle_sdf(cx, cy, r):
    return lambda px, py: math.hypot(px - cx, py - cy) - r


def shade(rgb, k):
    """k < 0 darkens toward black, k > 0 lightens toward white."""
    target = 0 if k < 0 else 255
    return tuple(int(c + (target - c) * abs(k)) for c in rgb)


def draw_block(cv, x, y, s, rgb):
    """A rounded 3D block like BlockPainter.block in the app."""
    rad = s * 0.2
    edge = s * 0.1
    cv.fill_sdf((x, y, x + s, y + s), rrect_sdf(x, y, x + s, y + s, rad), shade(rgb, -0.3))
    cv.fill_sdf((x, y, x + s, y + s - edge), rrect_sdf(x, y, x + s, y + s - edge, rad), rgb)
    fx = s - edge
    sx0, sy0 = x + s * 0.16, y + fx * 0.1
    sx1, sy1 = x + s * 0.84, y + fx * 0.32
    cv.fill_sdf((sx0, sy0, sx1, sy1), rrect_sdf(sx0, sy0, sx1, sy1, (sy1 - sy0) / 2),
                (255, 255, 255), 0.28)


def draw_logo(cv, x, y, size):
    cell = size / 3
    gap = cell * 0.08
    for r, row in enumerate(LOGO):
        for c, v in enumerate(row):
            bx, by, bs = x + c * cell + gap / 2, y + r * cell + gap / 2, cell - gap
            if v < 0:
                cv.fill_sdf((bx, by, bx + bs, by + bs), rrect_sdf(bx, by, bx + bs, by + bs, bs * 0.2), EMPTY)
            else:
                draw_block(cv, bx, by, bs, BLOCKS[v])


def gradient_shape(cv, sdf, bbox):
    """Background gradient clipped to a shape."""
    x0, y0, x1, y1 = bbox
    for y in range(cv.h):
        t = y / max(1, cv.h - 1)
        rgb = tuple(int(a + (b - a) * t) for a, b in zip(BG_TOP, BG_BOTTOM))
        for x in range(cv.w):
            cov = min(1.0, max(0.0, 0.5 - sdf(x + 0.5, y + 0.5)))
            cv.blend(x, y, rgb, cov)


# --------------------------------------------------------------- outputs ---

DENSITIES = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}


def legacy_icons():
    for name, s in DENSITIES.items():
        for round_icon in (False, True):
            cv = Canvas(s, s)
            m = s * 0.04
            sdf = (circle_sdf(s / 2, s / 2, s / 2 - m) if round_icon
                   else rrect_sdf(m, m, s - m, s - m, s * 0.18))
            gradient_shape(cv, sdf, (0, 0, s, s))
            logo = s * (0.56 if round_icon else 0.62)
            draw_logo(cv, (s - logo) / 2, (s - logo) / 2, logo)
            fname = 'ic_launcher_round.png' if round_icon else 'ic_launcher.png'
            cv.png(os.path.join(RES, f'mipmap-{name}', fname))


def vector_rrect(x0, y0, x1, y1, r):
    return (f'M{x0 + r:.2f},{y0:.2f}H{x1 - r:.2f}A{r:.2f},{r:.2f} 0 0 1 {x1:.2f},{y0 + r:.2f}'
            f'V{y1 - r:.2f}A{r:.2f},{r:.2f} 0 0 1 {x1 - r:.2f},{y1:.2f}'
            f'H{x0 + r:.2f}A{r:.2f},{r:.2f} 0 0 1 {x0:.2f},{y1 - r:.2f}'
            f'V{y0 + r:.2f}A{r:.2f},{r:.2f} 0 0 1 {x0 + r:.2f},{y0:.2f}Z')


def hexcolor(rgb, alpha=None):
    a = '' if alpha is None else f'{int(alpha * 255):02X}'
    return '#' + a + ''.join(f'{c:02X}' for c in rgb)


def adaptive_icons():
    # 108dp canvas; the launcher mask keeps the central 66dp, so the logo is
    # drawn inside a 54dp square centred on (54, 54).
    size, x0 = 54.0, 27.0
    cell = size / 3
    gap = cell * 0.08
    fg, mono = [], []
    for r, row in enumerate(LOGO):
        for c, v in enumerate(row):
            bx, by, bs = x0 + c * cell + gap / 2, x0 + r * cell + gap / 2, cell - gap
            rad, edge = bs * 0.2, bs * 0.1
            if v < 0:
                fg.append((vector_rrect(bx, by, bx + bs, by + bs, rad), hexcolor(EMPTY)))
                continue
            rgb = BLOCKS[v]
            fg.append((vector_rrect(bx, by, bx + bs, by + bs, rad), hexcolor(shade(rgb, -0.3))))
            fg.append((vector_rrect(bx, by, bx + bs, by + bs - edge, rad), hexcolor(rgb)))
            sh = (bs - edge) * 0.22
            sy = by + (bs - edge) * 0.1
            fg.append((vector_rrect(bx + bs * 0.16, sy, bx + bs * 0.84, sy + sh, sh / 2),
                       hexcolor((255, 255, 255), 0.28)))
            mono.append(vector_rrect(bx, by, bx + bs, by + bs, rad))

    def vector(paths):
        body = '\n'.join(
            f'    <path\n        android:fillColor="{color}"\n        android:pathData="{d}" />'
            for d, color in paths)
        return ('<?xml version="1.0" encoding="utf-8"?>\n'
                '<!-- Generated by tools/generate_icons.py (placeholder icon). -->\n'
                '<vector xmlns:android="http://schemas.android.com/apk/res/android"\n'
                '    android:width="108dp"\n    android:height="108dp"\n'
                '    android:viewportWidth="108"\n    android:viewportHeight="108">\n'
                f'{body}\n</vector>\n')

    def write(path, text):
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, 'w') as f:
            f.write(text)
        print('wrote', os.path.relpath(path, ROOT))

    write(os.path.join(RES, 'drawable', 'ic_launcher_foreground.xml'), vector(fg))
    write(os.path.join(RES, 'drawable', 'ic_launcher_monochrome.xml'),
          vector([(d, '#FFFFFFFF') for d in mono]))
    write(os.path.join(RES, 'values', 'ic_launcher_background.xml'),
          '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
          f'    <color name="ic_launcher_background">{hexcolor(BG_TOP)}</color>\n'
          f'    <color name="splash_background">{hexcolor(BG_BOTTOM)}</color>\n'
          '</resources>\n')
    adaptive = ('<?xml version="1.0" encoding="utf-8"?>\n'
                '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
                '    <background android:drawable="@color/ic_launcher_background" />\n'
                '    <foreground android:drawable="@drawable/ic_launcher_foreground" />\n'
                '    <monochrome android:drawable="@drawable/ic_launcher_monochrome" />\n'
                '</adaptive-icon>\n')
    for name in ('ic_launcher.xml', 'ic_launcher_round.xml'):
        write(os.path.join(RES, 'mipmap-anydpi-v26', name), adaptive)


# 5x7 pixel font for the feature graphic title, drawn with game blocks.
FONT = {
    'B': ['XXXX.', 'X...X', 'X...X', 'XXXX.', 'X...X', 'X...X', 'XXXX.'],
    'L': ['X....', 'X....', 'X....', 'X....', 'X....', 'X....', 'XXXXX'],
    'O': ['.XXX.', 'X...X', 'X...X', 'X...X', 'X...X', 'X...X', '.XXX.'],
    'C': ['.XXXX', 'X....', 'X....', 'X....', 'X....', 'X....', '.XXXX'],
    'K': ['X...X', 'X..X.', 'X.X..', 'XX...', 'X.X..', 'X..X.', 'X...X'],
    'F': ['XXXXX', 'X....', 'X....', 'XXXX.', 'X....', 'X....', 'X....'],
    'I': ['XXX', '.X.', '.X.', '.X.', '.X.', '.X.', 'XXX'],
    'T': ['XXXXX', '..X..', '..X..', '..X..', '..X..', '..X..', '..X..'],
    ' ': ['..', '..', '..', '..', '..', '..', '..'],
}


def store_graphics():
    s = 512
    cv = Canvas(s, s)
    cv.gradient(BG_TOP, BG_BOTTOM)  # Play applies its own mask: fill fully.
    logo = s * 0.6
    draw_logo(cv, (s - logo) / 2, (s - logo) / 2, logo)
    cv.png(os.path.join(STORE, 'icon-512.png'))

    w, h = 1024, 500
    cv = Canvas(w, h)
    cv.gradient(BG_TOP, BG_BOTTOM)
    draw_logo(cv, 70, (h - 300) / 2, 300)
    text = 'BLOCK FIT'
    palette = [BLOCKS[0], BLOCKS[5], BLOCKS[3]]
    # Fit the title into the space right of the logo, with a margin.
    cols = sum(len(FONT[ch][0]) + 1 for ch in text) - 1
    left, right = 420.0, w - 50.0
    px = (right - left) / cols
    x = left
    y = (h - 7 * px) / 2
    for i, ch in enumerate(text):
        glyph = FONT[ch]
        for r, row in enumerate(glyph):
            for c, v in enumerate(row):
                if v == 'X':
                    draw_block(cv, x + c * px, y + r * px, px * 0.92, palette[i % 3])
        x += (len(glyph[0]) + 1) * px
    cv.png(os.path.join(STORE, 'feature-graphic-1024x500.png'))


if __name__ == '__main__':
    legacy_icons()
    adaptive_icons()
    store_graphics()
