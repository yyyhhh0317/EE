#!/usr/bin/env python3
"""Slice a 3x3 character sheet into 9 named PNGs + report per-cell content stats."""
import os
from PIL import Image

SRC = r'D:\yyy\EE\art\hero\hero_sheet.png'
OUT = r'D:\yyy\EE\art\hero'
COLS = 3
ROWS = 3

# Compass layout around the center idle cell (row 0 = top of the image).
NAMES = [
    ['up_left', 'up', 'up_right'],
    ['left', 'idle', 'right'],
    ['down_left', 'down', 'down_right'],
]


def main():
    img = Image.open(SRC).convert('RGB')
    w, h = img.size
    print(f'sheet: {w}x{h}')
    cw, ch = w // COLS, h // ROWS
    os.makedirs(OUT, exist_ok=True)

    # Background reference: top-left corner pixel (assumed clean background).
    bg = img.getpixel((2, 2))
    print(f'bg ref pixel: {bg}')

    for r in range(ROWS):
        for c in range(COLS):
            box = (c * cw, r * ch, (c + 1) * cw, (r + 1) * ch)
            cell = img.crop(box)
            name = NAMES[r][c]
            outp = os.path.join(OUT, f'hero_{name}.png')
            cell.save(outp)

            # Content stats: sample every 2px, compare to background color.
            px = cell.load()
            minx, miny, maxx, maxy = cw, ch, -1, -1
            nbg = 0
            for y in range(0, ch, 2):
                for x in range(0, cw, 2):
                    p = px[x, y]
                    if abs(p[0] - bg[0]) + abs(p[1] - bg[1]) + abs(p[2] - bg[2]) > 30:
                        nbg += 1
                        if x < minx: minx = x
                        if y < miny: miny = y
                        if x > maxx: maxx = x
                        if y > maxy: maxy = y
            samples = ((ch + 1) // 2) * ((cw + 1) // 2)
            fill = round(100.0 * nbg / samples, 1)
            bbox = f'[{minx},{miny}..{maxx},{maxy}]' if maxx >= 0 else 'EMPTY'
            print(f'hero_{name}.png  {cell.size}  fill={fill}%  bbox={bbox}')

    print('DONE')


if __name__ == '__main__':
    main()
