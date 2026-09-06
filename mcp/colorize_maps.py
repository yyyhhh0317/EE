#!/usr/bin/env python3
"""Recolor one base map into 8 emotion-themed variants (identical structure,
only the colour grade / style changes). Chaotic = corrupted-but-readable room
(iridescent hue + chromatic aberration + glitch bars). Adds a pixel-art
post-process. Outputs art/maps/<emotion>_map.png."""
import os
import colorsys
from PIL import Image, ImageOps, ImageChops

SRC = r'D:\yyy\EE\art\maps\base_map.png'
OUT = r'D:\yyy\EE\art\maps'
PIXEL_GRID = 128          # target pixel-block grid; smaller = chunkier
QUANTIZE = 16             # palette size for the regular grades

# 3-tone grades: (shadow/black, mid, highlight/white)  — matched to GDD theme colours.
PALETTES = {
    'joy':      ((150, 40, 80),  (255, 190, 90),  (255, 244, 180)),  # 明黄/亮粉
    'rage':     ((70, 8, 8),     (210, 70, 25),   (255, 150, 60)),   # 暗红/橙
    'sorrow':   ((26, 40, 62),   (110, 138, 162), (190, 206, 220)),  # 灰蓝
    'fear':     ((12, 8, 22),    (98, 60, 122),   (170, 120, 190)),  # 深黑/暗紫（稍提亮可读）
    'disgust':  ((20, 46, 18),   (92, 116, 66),   (168, 152, 164)),  # 绿紫
    'surprise': ((6, 6, 6),      (110, 110, 110), (255, 255, 255)),  # 高对比白
    'anxiety':  ((58, 58, 68),   (138, 132, 152), (216, 210, 230)),  # 灰/浅紫
}


def pixelate(img, grid=PIXEL_GRID):
    small = img.resize((grid, grid), Image.NEAREST)
    return small.resize(img.size, Image.NEAREST)


def chaos_variant(img, grid=PIXEL_GRID):
    """Corrupted but still readable room: hue varies slowly by position (big
    colour regions), brightness tracks the structure, then chromatic-aberration
    (red/cyan fringing) + a few horizontal glitch bars."""
    small = img.convert('L').resize((grid, grid), Image.NEAREST)
    s = small.load()
    out = Image.new('RGB', (grid, grid))
    o = out.load()
    for y in range(grid):
        for x in range(grid):
            v = s[x, y]
            h = ((x * 2 + y * 3) % 360) / 360.0   # slow hue variation -> large colour regions
            sat = 0.60                            # subdued so the room still reads
            val = 0.15 + 0.85 * (v / 255.0)       # structure: dark shadows, lit areas bright
            r, g, b = colorsys.hsv_to_rgb(h, sat, val)
            o[x, y] = (int(r * 255), int(g * 255), int(b * 255))
    rgb = out.resize(img.size, Image.NEAREST)
    # chromatic-aberration glitch (red/cyan fringing on every edge)
    r, g, b = rgb.split()
    rgb = Image.merge('RGB', (ImageChops.offset(r, 5, 0), g, ImageChops.offset(b, -5, 0)))
    # a few deterministic horizontal glitch bars
    w, h = rgb.size
    for y, ih, sx in [(90, 12, 26), (300, 16, -22), (520, 10, 30), (660, 14, -18)]:
        bar = rgb.crop((0, y, w, min(y + ih, h)))
        rgb.paste(ImageChops.offset(bar, sx, 0), (0, y))
    return rgb


def main():
    img = Image.open(SRC).convert('RGB')
    img.save(SRC)  # re-encode source as a real PNG (Pollinations returns JPEG bytes)
    gray = pixelate(img.convert('L'))
    w, h = img.size
    print(f'base: {w}x{h}  grid={PIXEL_GRID}')

    os.makedirs(OUT, exist_ok=True)

    for name, (black, mid, white) in PALETTES.items():
        graded = ImageOps.colorize(gray, black=black, white=white, mid=mid)
        graded = graded.quantize(colors=QUANTIZE).convert('RGB')
        out = os.path.join(OUT, f'{name}_map.png')
        graded.save(out)
        print(f'{name}_map.png  {graded.size}  palette={QUANTIZE}')

    ch = chaos_variant(img)
    out = os.path.join(OUT, 'chaos_map.png')
    ch.save(out)
    print(f'chaos_map.png  {ch.size}')

    print('DONE')


if __name__ == '__main__':
    main()
