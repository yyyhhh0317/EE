#!/usr/bin/env python3
"""Turn a raw character frame into a game-ready sprite:
   - crop to the character + margin
   - flood-fill remove the background (transparent)
   - draw a glowing energy ring around the character
   - resize to a square game sprite
Usage: python process_sprite.py <in.png> <out.png> [target_px]
"""
import sys, os
import collections
from PIL import Image, ImageDraw, ImageFilter

BG_THRESH = 34     # color distance considered "background"
RING_COLOR = (120, 200, 255)  # pale cyan energy ring


def content_bbox(rgb, bg, thresh=BG_THRESH, step=2):
    w, h = rgb.size
    px = rgb.load()
    minx, miny, maxx, maxy = w, h, -1, -1
    for y in range(0, h, step):
        for x in range(0, w, step):
            p = px[x, y]
            if abs(p[0] - bg[0]) + abs(p[1] - bg[1]) + abs(p[2] - bg[2]) > thresh:
                if x < minx: minx = x
                if y < miny: miny = y
                if x > maxx: maxx = x
                if y > maxy: maxy = y
    if maxx < 0:
        return None
    return minx, miny, maxx, maxy


def transparent_from_border(rgba, bg, thresh=BG_THRESH):
    """Flood-fill from the border: any connected pixel close to bg -> alpha 0."""
    w, h = rgba.size
    rgb = rgba.convert('RGB').load()
    px = rgba.load()
    visited = [[False] * w for _ in range(h)]
    q = collections.deque()
    for x in range(w):
        q.append((x, 0)); q.append((x, h - 1))
    for y in range(h):
        q.append((0, y)); q.append((w - 1, y))
    while q:
        x, y = q.popleft()
        if x < 0 or y < 0 or x >= w or y >= h or visited[y][x]:
            continue
        visited[y][x] = True
        p = rgb[x, y]
        if abs(p[0] - bg[0]) + abs(p[1] - bg[1]) + abs(p[2] - bg[2]) <= thresh:
            px[x, y] = (p[0], p[1], p[2], 0)
            q.append((x + 1, y)); q.append((x - 1, y))
            q.append((x, y + 1)); q.append((x, y - 1))
    return rgba


def add_ring(canvas):
    """Draw a clear glowing elliptical ring around the character (centered on canvas)."""
    side = canvas.size[0]
    cx = cy = side / 2
    rx = ry = side * 0.46
    overlay = Image.new('RGBA', canvas.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(overlay)
    # halo glow (outer, fainter)
    for s, alpha in [(1.14, 42), (1.07, 78), (1.02, 120)]:
        d.ellipse([cx - rx * s, cy - ry * s, cx + rx * s, cy + ry * s],
                  outline=(*RING_COLOR, alpha), width=4)
    # main ring
    d.ellipse([cx - rx, cy - ry, cx + rx, cy + ry],
              outline=(*RING_COLOR, 235), width=3)
    return Image.alpha_composite(canvas, overlay)


def main():
    args = sys.argv[1:]
    if len(args) < 2:
        print('usage: process_sprite.py <in.png> <out.png> [target_px] [--no-ring]'); sys.exit(1)
    src, dst = args[0], args[1]
    target = 128
    ring = True
    for a in args[2:]:
        if a == '--no-ring':
            ring = False
        elif a.isdigit():
            target = int(a)
    im = Image.open(src).convert('RGB')
    w, h = im.size
    bg = im.getpixel((2, 2))
    bbox = content_bbox(im, bg)
    if bbox is None:
        print('no content found'); sys.exit(1)
    x0, y0, x1, y1 = bbox
    pad = 24
    x0 = max(0, x0 - pad); y0 = max(0, y0 - pad)
    x1 = min(w - 1, x1 + pad); y1 = min(h - 1, y1 + pad)
    crop = im.crop((x0, y0, x1 + 1, y1 + 1))
    rgba = crop.convert('RGBA')
    rgba = transparent_from_border(rgba, bg)
    # square canvas around center
    cw, ch = rgba.size
    side = max(cw, ch)
    canvas = Image.new('RGBA', (side, side), (0, 0, 0, 0))
    canvas.paste(rgba, ((side - cw) // 2, (side - ch) // 2), rgba)
    if ring:
        canvas = add_ring(canvas)
    canvas = canvas.resize((target, target), Image.LANCZOS)
    canvas.save(dst)
    imp = dst + '.import'
    if os.path.exists(imp):
        os.remove(imp)
    print(f'saved {dst} ({target}x{target}, ring={ring}) from bbox {bbox}')


if __name__ == '__main__':
    main()
