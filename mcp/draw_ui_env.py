#!/usr/bin/env python3
"""Damage-number font, HP/SAN/失控值 bar art, and environment decorations.
Outputs art/items/ (and art/env/ for decorations)."""
import os
import math
from PIL import Image, ImageDraw

ITEMS = r'D:\yyy\EE\art\items'
ENV = r'D:\yyy\EE\art\env'
PIX = 48      # pixel grid for decor
UP = 2        # upscale -> 96px

# ── 3x5 pixel font (damage numbers) ─────────────────────────────────────────
FONT = {
    '0': ["###", "#.#", "#.#", "#.#", "###"],
    '1': [".#.", "##.", ".#.", ".#.", "###"],
    '2': ["###", "..#", "###", "#..", "###"],
    '3': ["###", "..#", "###", "..#", "###"],
    '4': ["#.#", "#.#", "###", "..#", "..#"],
    '5': ["###", "#..", "###", "..#", "###"],
    '6': ["###", "#..", "###", "#.#", "###"],
    '7': ["###", "..#", "..#", "..#", "..#"],
    '8': ["###", "#.#", "###", "#.#", "###"],
    '9': ["###", "#.#", "###", "..#", "###"],
    '+': ["...", ".#.", "###", ".#.", "..."],
    '-': ["...", "...", "###", "...", "..."],
    '!': [".#.", ".#.", ".#.", "...", ".#."],
}
DSCALE = 4


def render_glyph(ch, scale=DSCALE, fill=(255, 255, 255), outline=(32, 28, 42)):
    rows = FONT[ch]
    w = (3 + 2) * scale
    h = (5 + 2) * scale
    img = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for y, row in enumerate(rows):          # outline pass
        for x, c in enumerate(row):
            if c == '#':
                px, py = (x + 1) * scale, (y + 1) * scale
                d.rectangle([px - scale, py - scale, px + 2 * scale - 1, py + 2 * scale - 1], fill=outline)
    for y, row in enumerate(rows):          # fill pass
        for x, c in enumerate(row):
            if c == '#':
                px, py = (x + 1) * scale, (y + 1) * scale
                d.rectangle([px, py, px + scale - 1, py + scale - 1], fill=fill)
    return img


def make_digits():
    glyphs = list(FONT.keys())
    cells = []
    for ch in glyphs:
        g = render_glyph(ch)
        cells.append(g)
        name = f'digit_{ch}.png' if ch.isdigit() else f'sym_{ { "+": "plus", "-": "minus", "!": "excl" }[ch] }.png'
        g.save(os.path.join(ITEMS, name))
        print(name, g.size)
    cw = max(c.width for c in cells) + 6
    ch = max(c.height for c in cells) + 6
    sheet = Image.new('RGBA', (cw * len(cells), ch), (0, 0, 0, 0))
    for i, c in enumerate(cells):
        sheet.paste(c, (i * cw + 3, 3), c)
    sheet.save(os.path.join(ITEMS, 'dmg_sheet.png'))
    print('dmg_sheet.png', sheet.size, f'(cell {cw}x{ch})')


# ── bars ────────────────────────────────────────────────────────────────────
def _shade(c, f):
    return tuple(max(0, min(255, int(v * f))) for v in c)


def bar_frame(w=192, h=28):
    img = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 0, w - 1, h - 1], radius=7, fill=(24, 22, 34, 225), outline=(140, 132, 172), width=3)
    return img


def bar_fill(color, w=182, h=18):
    img = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 0, w - 1, h - 1], radius=4, fill=color, outline=_shade(color, 0.65))
    d.rounded_rectangle([3, 2, w - 4, h // 2], radius=3, fill=_shade(color, 1.35))
    return img


def make_bars():
    bar_frame().save(os.path.join(ITEMS, 'bar_frame.png'))
    for name, col in (('hp', (220, 60, 75)), ('san', (185, 165, 215)), ('unstable', (215, 75, 150))):
        bar_fill(col).save(os.path.join(ITEMS, f'bar_fill_{name}.png'))
        print(f'bar_fill_{name}.png')
    print('bar_frame.png')


# ── environment decorations ─────────────────────────────────────────────────
def save_env(img, name):
    img = img.resize((PIX * UP, PIX * UP), Image.NEAREST)
    img.save(os.path.join(ENV, name))
    print(name, img.size)


def draw_crate():
    img = Image.new('RGBA', (PIX, PIX), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([8, 8, 40, 40], fill=(158, 112, 58), outline=(92, 62, 30), width=3)
    d.line([11, 11, 37, 37], fill=(124, 84, 42), width=3)
    d.line([37, 11, 11, 37], fill=(124, 84, 42), width=3)
    d.rectangle([8, 8, 40, 40], outline=(112, 78, 38), width=2)
    for (x, y) in ((12, 12), (36, 12), (12, 36), (36, 36)):
        d.rectangle([x - 2, y - 2, x + 2, y + 2], fill=(200, 200, 205))
    return img


def draw_crate_broken():
    img = Image.new('RGBA', (PIX, PIX), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    planks = [
        [(8, 34), (24, 30), (26, 36), (10, 40)],
        [(26, 32), (42, 36), (40, 42), (26, 38)],
        [(12, 22), (30, 18), (32, 24), (14, 28)],
    ]
    for p in planks:
        d.polygon(p, fill=(150, 106, 55), outline=(92, 62, 30))
    d.polygon([(16, 10), (24, 6), (28, 14), (20, 18)], fill=(176, 132, 72), outline=(92, 62, 30))
    d.rectangle([30, 22, 34, 26], fill=(200, 200, 205))
    return img


def draw_spike_trap():
    img = Image.new('RGBA', (PIX, PIX), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([6, 34, 42, 42], fill=(88, 94, 110), outline=(48, 52, 66), width=2)
    for x in (10, 20, 30):
        d.polygon([(x, 34), (x + 5, 12), (x + 10, 34)], fill=(206, 212, 222), outline=(120, 126, 142))
        d.polygon([(x + 5, 34), (x + 5, 12), (x + 10, 34)], fill=(168, 175, 190))
    return img


def draw_door():
    img = Image.new('RGBA', (PIX, PIX), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([13, 5, 35, 44], fill=(126, 94, 56), outline=(66, 46, 26), width=3)
    d.line([24, 7, 24, 42], fill=(96, 70, 40), width=2)
    d.line([16, 16, 32, 16], fill=(96, 70, 40), width=2)
    d.line([16, 32, 32, 32], fill=(96, 70, 40), width=2)
    d.ellipse([29, 23, 33, 27], fill=(226, 194, 92), outline=(150, 120, 40))
    # stone frame
    d.rectangle([9, 3, 39, 6], fill=(120, 122, 134), outline=(70, 72, 84))
    return img


def draw_teleport():
    img = Image.new('RGBA', (PIX, PIX), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # standing oval portal
    d.ellipse([10, 6, 38, 44], fill=(46, 30, 84), outline=(158, 126, 236), width=3)
    d.ellipse([15, 11, 33, 39], fill=(96, 70, 190))
    d.ellipse([19, 16, 29, 34], fill=(150, 120, 240))
    for k in range(3):                       # swirl arcs
        d.arc([17 + k * 2, 14, 31 - k * 2, 36], 200 + k * 40, 340 + k * 40, fill=(225, 215, 255), width=2)
    d.ellipse([21, 22, 27, 28], fill=(245, 240, 255))
    return img


def make_env():
    os.makedirs(ENV, exist_ok=True)
    save_env(draw_crate(), 'crate.png')
    save_env(draw_crate_broken(), 'crate_broken.png')
    save_env(draw_spike_trap(), 'spike_trap.png')
    # 门 / 传送门统一由 draw_ui2.py 输出动画帧（door_0/1/2、teleport_0/1/2），
    # 这里不再生成单帧的 door.png / teleport.png，避免重复。


def main():
    os.makedirs(ITEMS, exist_ok=True)
    make_digits()
    make_bars()
    make_env()
    print('DONE')


if __name__ == '__main__':
    main()
