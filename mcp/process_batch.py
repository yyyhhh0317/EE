#!/usr/bin/env python3
"""Process raw monster frames (matching <prefix>*.png in <dir>) into game sprites:
transparent background, no ring, target size.
Usage: python process_batch.py <dir> <prefix> <target_px>
"""
import os, sys, glob
from PIL import Image


def content_bbox(rgb, bg, thresh=34, step=2):
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
    return (minx, miny, maxx, maxy) if maxx >= 0 else None


def transparent_from_border(rgba, bg, thresh=34):
    import collections
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


def main():
    d, prefix, target = sys.argv[1], sys.argv[2], int(sys.argv[3])
    files = sorted(glob.glob(os.path.join(d, prefix + '*.png')))
    for p in files:
        im = Image.open(p).convert('RGB')
        w, h = im.size
        bg = im.getpixel((2, 2))
        bbox = content_bbox(im, bg)
        if bbox is None:
            print(f'{os.path.basename(p)}: no content, skip'); continue
        x0, y0, x1, y1 = bbox
        pad = 20
        x0 = max(0, x0 - pad); y0 = max(0, y0 - pad)
        x1 = min(w - 1, x1 + pad); y1 = min(h - 1, y1 + pad)
        crop = im.crop((x0, y0, x1 + 1, y1 + 1)).convert('RGBA')
        crop = transparent_from_border(crop, bg)
        cw, ch = crop.size
        side = max(cw, ch)
        canvas = Image.new('RGBA', (side, side), (0, 0, 0, 0))
        canvas.paste(crop, ((side - cw) // 2, (side - ch) // 2), crop)
        canvas = canvas.resize((target, target), Image.LANCZOS)
        canvas.save(p)
        print(f'{os.path.basename(p)}: {target}x{target} OK')
    print('BATCH DONE')


if __name__ == '__main__':
    main()
