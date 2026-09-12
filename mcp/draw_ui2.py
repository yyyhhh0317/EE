#!/usr/bin/env python3
"""Round-2 UI/anim: spike retracted, door + teleport animation frames,
extra damage-number styles (crit / shadow), vertical energy bar, boss health bar."""
import os
from PIL import Image, ImageDraw

ITEMS = r'D:\yyy\EE\art\items'
ENV = r'D:\yyy\EE\art\env'
PIX = 48
UP = 2

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
}


def render_glyph(ch, scale=4, fill=(255, 255, 255), outline=(32, 28, 42),
                 outline_px=1, shadow=None, shadow_off=1):
    rows = FONT[ch]
    w = (3 + 2 * outline_px) * scale
    h = (5 + 2 * outline_px) * scale
    pad = shadow_off * scale if shadow else 0
    img = Image.new('RGBA', (w + pad, h + pad), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    def stamp(ox, oy, color, expand):
        for y, row in enumerate(rows):
            for x, c in enumerate(row):
                if c == '#':
                    px = ox + (x + outline_px) * scale
                    py = oy + (y + outline_px) * scale
                    d.rectangle([px - expand * scale, py - expand * scale,
                                 px + scale - 1 + expand * scale, py + scale - 1 + expand * scale], fill=color)

    if shadow:
        stamp(pad, pad, shadow, outline_px)
    stamp(0, 0, outline, outline_px)
    stamp(0, 0, fill, 0)
    return img


def make_digit_styles():
    styles = {
        'crit': dict(scale=5, fill=(255, 214, 80), outline=(122, 28, 22), outline_px=2),
        'shadow': dict(scale=4, fill=(255, 255, 255), outline=(32, 28, 42), outline_px=1,
                       shadow=(0, 0, 0, 150), shadow_off=1),
    }
    for style, kw in styles.items():
        cells = []
        for ch in '0123456789':
            g = render_glyph(ch, **kw)
            g.save(os.path.join(ITEMS, f'digit_{style}_{ch}.png'))
            cells.append(g)
        cw = max(c.width for c in cells) + 6
        chh = max(c.height for c in cells) + 6
        sheet = Image.new('RGBA', (cw * len(cells), chh), (0, 0, 0, 0))
        for i, c in enumerate(cells):
            sheet.paste(c, (i * cw + 3, 3), c)
        sheet.save(os.path.join(ITEMS, f'dmg_{style}_sheet.png'))
        print(f'dmg_{style}_sheet.png', sheet.size, f'(cell {cw}x{chh})')


# ── environment animation frames ────────────────────────────────────────────
def save_env(img, name):
    img = img.resize((PIX * UP, PIX * UP), Image.NEAREST)
    img.save(os.path.join(ENV, name))
    print(name, img.size)


def draw_spike_retracted():
    img = Image.new('RGBA', (PIX, PIX), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([6, 34, 42, 42], fill=(88, 94, 110), outline=(48, 52, 66), width=2)
    for x in (12, 22, 32):                       # closed slits
        d.rectangle([x, 36, x + 6, 40], fill=(38, 42, 54))
        d.line([x + 1, 36, x + 5, 36], fill=(120, 126, 142))
    return img


def _door_common(d):
    d.rectangle([13, 5, 35, 44], fill=(20, 18, 26))            # dark opening
    d.rectangle([9, 3, 39, 6], fill=(120, 122, 134), outline=(70, 72, 84))  # lintel


def draw_door_frame(f):
    img = Image.new('RGBA', (PIX, PIX), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    _door_common(d)
    w = (22, 14, 5)[f]                            # hinge on the left, panel foreshortens
    x0, x1 = 13, 13 + w
    d.rectangle([x0, 5, x1, 44], fill=(126, 94, 56), outline=(66, 46, 26), width=2)
    if w > 8:
        d.line([x0 + w // 2, 7, x0 + w // 2, 42], fill=(96, 70, 40), width=2)
    if w > 4:
        d.ellipse([x1 - 4, 23, x1 - 1, 27], fill=(226, 194, 92), outline=(150, 120, 40))
    d.rectangle([9, 3, 39, 6], fill=(120, 122, 134), outline=(70, 72, 84))  # lintel on top
    return img


def draw_teleport_frame(f):
    img = Image.new('RGBA', (PIX, PIX), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([10, 6, 38, 44], fill=(46, 30, 84), outline=(158, 126, 236), width=3)
    d.ellipse([15, 11, 33, 39], fill=(96, 70, 190))
    d.ellipse([19, 16, 29, 34], fill=(150, 120, 240))
    for k in range(3):                            # swirl rotates per frame
        off = f * 60
        d.arc([17 + k * 2, 14, 31 - k * 2, 36], 200 + off + k * 30, 330 + off + k * 30,
              fill=(225, 215, 255), width=2)
    core = ((248, 244, 255), (255, 255, 255), (232, 224, 255))[f]   # pulse
    d.ellipse([21, 22, 27, 28], fill=core)
    return img


# ── bars ────────────────────────────────────────────────────────────────────
def _shade(c, f):
    return tuple(max(0, min(255, int(v * f))) for v in c)


def bar_v_frame(w=28, h=192):
    img = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 0, w - 1, h - 1], radius=8, fill=(24, 22, 34, 225), outline=(140, 132, 172), width=3)
    return img


def bar_v_fill(color, w=18, h=182):
    img = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 0, w - 1, h - 1], radius=4, fill=color, outline=_shade(color, 0.65))
    d.rounded_rectangle([3, 3, w // 2, h - 4], radius=3, fill=_shade(color, 1.4))
    return img


def boss_frame(w=384, h=36):
    img = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 0, w - 1, h - 1], radius=6, fill=(20, 16, 22, 235), outline=(150, 60, 60), width=3)
    for x in (6, w - 18):                         # angled end caps
        d.polygon([(x, 4), (x + 12, h // 2), (x, h - 5)], fill=(190, 150, 70))
    d.rectangle([2, 2, w - 3, 5], fill=(70, 40, 44))
    return img


def boss_fill(color=(206, 44, 52), w=368, h=24):
    img = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 0, w - 1, h - 1], radius=4, fill=color, outline=_shade(color, 0.6))
    d.rounded_rectangle([3, 2, w - 4, h // 2], radius=3, fill=_shade(color, 1.35))
    return img


def make_bars():
    bar_v_frame().save(os.path.join(ITEMS, 'bar_v_frame.png'))
    bar_v_fill((90, 205, 220)).save(os.path.join(ITEMS, 'bar_v_fill_energy.png'))
    bar_v_fill((220, 60, 75)).save(os.path.join(ITEMS, 'bar_v_fill_hp.png'))
    boss_frame().save(os.path.join(ITEMS, 'boss_bar_frame.png'))
    boss_fill().save(os.path.join(ITEMS, 'boss_bar_fill.png'))
    print('bar_v_frame.png / bar_v_fill_energy.png / bar_v_fill_hp.png / boss_bar_frame.png / boss_bar_fill.png')


def main():
    os.makedirs(ITEMS, exist_ok=True)
    os.makedirs(ENV, exist_ok=True)
    make_digit_styles()
    save_env(draw_spike_retracted(), 'spike_trap_retracted.png')
    for f in range(3):
        save_env(draw_door_frame(f), f'door_{f}.png')
        save_env(draw_teleport_frame(f), f'teleport_{f}.png')
    make_bars()
    print('DONE')


if __name__ == '__main__':
    main()
