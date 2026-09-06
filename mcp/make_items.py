#!/usr/bin/env python3
"""Build in-game item sprites from raw Pollinations outputs.
- flood-fill background removal -> transparent
- crop to content, pixelate
- energy / essence: recolor to 8 emotion variants (same PALETTES as the maps)
Outputs art/items/."""
import os
import numpy as np
from collections import deque
from PIL import Image, ImageOps

SRC = r'D:\yyy\EE\art\items'
OUT = r'D:\yyy\EE\art\items'
GRID = 48   # pixel-block grid (item max dimension in blocks)
UPS = 2     # upscale after pixel grid
DS = 2      # downsample factor for fast flood fill

PALETTES = {
    'joy':      ((150, 40, 80),  (255, 190, 90),  (255, 244, 180)),
    'rage':     ((70, 8, 8),     (210, 70, 25),   (255, 150, 60)),
    'sorrow':   ((26, 40, 62),   (110, 138, 162), (190, 206, 220)),
    'fear':     ((12, 8, 22),    (98, 60, 122),   (170, 120, 190)),
    'disgust':  ((20, 46, 18),   (92, 116, 66),   (168, 152, 164)),
    'surprise': ((6, 6, 6),      (110, 110, 110), (255, 255, 255)),
    'anxiety':  ((58, 58, 68),   (138, 132, 152), (216, 210, 230)),
}


def remove_bg(img, tol=30):
    a_full = np.asarray(img.convert('RGB')).astype(np.int16)
    small = img.convert('RGB').resize((img.width // DS, img.height // DS), Image.BOX)
    a = np.asarray(small).astype(np.int16)
    h, w, _ = a.shape
    bg = np.zeros((h, w), bool)
    q = deque()
    for x in range(w):
        for y in (0, h - 1):
            if not bg[y, x]:
                bg[y, x] = True
                q.append((y, x))
    for y in range(h):
        for x in (0, w - 1):
            if not bg[y, x]:
                bg[y, x] = True
                q.append((y, x))
    while q:
        y, x = q.popleft()
        c = a[y, x]
        for ny, nx in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)):
            if 0 <= ny < h and 0 <= nx < w and not bg[ny, nx]:
                if int(np.abs(a[ny, nx] - c).sum()) <= tol * 3:
                    bg[ny, nx] = True
                    q.append((ny, nx))
    bgimg = Image.fromarray((bg * 255).astype(np.uint8)).resize(img.size, Image.NEAREST)
    bgmask = np.asarray(bgimg) > 0
    alpha = np.where(bgmask, 0, 255).astype(np.uint8)
    rgba = np.dstack([a_full.astype(np.uint8), alpha])
    return Image.fromarray(rgba, 'RGBA')


def crop_to_content(img, margin=6):
    alpha = np.asarray(img)[:, :, 3]
    ys, xs = np.where(alpha > 10)
    if len(xs) == 0:
        return img
    x0 = max(0, xs.min() - margin)
    x1 = min(img.width, xs.max() + margin + 1)
    y0 = max(0, ys.min() - margin)
    y1 = min(img.height, ys.max() + margin + 1)
    return img.crop((x0, y0, x1, y1))


def pixelate(img):
    w, h = img.size
    scale = GRID / max(w, h)
    nw, nh = max(1, int(w * scale)), max(1, int(h * scale))
    small = img.resize((nw, nh), Image.NEAREST)
    return small.resize((nw * UPS, nh * UPS), Image.NEAREST)


def colorize_emotion(img, name):
    pal = PALETTES[name]
    gray = img.convert('L')
    col = ImageOps.colorize(gray, pal[0], pal[2], mid=pal[1]).convert('RGBA')
    col.putalpha(img.split()[3])
    return col


def process(src_name, out_name):
    img = Image.open(os.path.join(SRC, src_name)).convert('RGB')
    img = pixelate(crop_to_content(remove_bg(img)))
    img.save(os.path.join(OUT, out_name))
    print(f'{out_name}  {img.size}')


def main():
    process('raw_coin2.png', 'coin.png')
    process('raw_stabilizer2.png', 'stabilizer.png')

    for base, fam in [('raw_energy.png', 'energy'), ('raw_essence.png', 'essence')]:
        img = Image.open(os.path.join(SRC, base)).convert('RGB')
        img = pixelate(crop_to_content(remove_bg(img)))
        img.save(os.path.join(OUT, f'{fam}.png'))
        print(f'{fam}.png  {img.size}')
        for emo in PALETTES:
            v = colorize_emotion(img, emo)
            v.save(os.path.join(OUT, f'{fam}_{emo}.png'))
            print(f'{fam}_{emo}.png  {v.size}')
    print('DONE')


if __name__ == '__main__':
    main()
