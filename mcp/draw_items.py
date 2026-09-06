#!/usr/bin/env python3
"""Programmatic clean pixel-art item sprites (transparent, crisp, recolorable).
Outputs art/items/: coin, stabilizer, energy_<emotion> x8, essence_<emotion> x8."""
import os
import math
import numpy as np
from PIL import Image, ImageDraw

OUT = r'D:\yyy\EE\art\items'
PIX = 48            # pixel-grid resolution (draw at this size, then upscale)
UP = 2              # upscale -> final 96px sprites
FINAL = PIX * UP

# theme main colour per emotion (for energy glow / essence crystal)
EMO_COLOR = {
    'joy':      (255, 200, 60),
    'rage':     (255, 80, 40),
    'sorrow':   (110, 150, 180),
    'fear':     (150, 70, 200),
    'disgust':  (110, 170, 60),
    'surprise': (190, 225, 255),
    'anxiety':  (170, 160, 205),
}

def hsv2rgb(h, s, v):
    h = h % 1.0
    import colorsys
    r, g, b = colorsys.hsv_to_rgb(h, s, v)
    return int(r * 255), int(g * 255), int(b * 255)


def save(img, name):
    img = img.resize((FINAL, FINAL), Image.NEAREST)
    img.save(os.path.join(OUT, name))
    print(name, (FINAL, FINAL))


def draw_energy(color, chaos=False):
    img = Image.new('RGBA', (PIX, PIX), (0, 0, 0, 0))
    px = img.load()
    cy = cx = (PIX - 1) / 2
    for y in range(PIX):
        for x in range(PIX):
            d = math.hypot(x - cx, y - cy) / (cx)
            if d >= 1.0:
                continue
            if chaos:
                col = hsv2rgb((math.atan2(y - cy, x - cx) / (2 * math.pi)) + 0.5, 0.95, 0.95)
            else:
                col = color
            core = max(0.0, 1.0 - d / 0.4)   # small white-hot core
            r = int(col[0] + (255 - col[0]) * core)
            g = int(col[1] + (255 - col[1]) * core)
            b = int(col[2] + (255 - col[2]) * core)
            a = 1.0 if d < 0.6 else max(0.0, (1.0 - d) / 0.4)   # solid body, glow fade edge
            px[x, y] = (r, g, b, int(a * 255))
    return img


def draw_crystal(color, chaos=False):
    img = Image.new('RGBA', (PIX, PIX), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx = PIX / 2
    top = 6
    bot = PIX - 6
    mid = PIX / 2
    left = 10
    right = PIX - 10
    # rhombus (diamond)
    pts = [(cx, top), (right, mid), (cx, bot), (left, mid)]
    body = color if not chaos else None
    if chaos:
        fill = None
        # draw per-face rainbow
        d.polygon([(cx, top), (right, mid), (cx, mid), (left, mid)], fill=hsv2rgb(0.55, 0.9, 0.9))
        d.polygon([(cx, top), (right, mid), (cx, bot)], fill=hsv2rgb(0.75, 0.9, 0.9))
        d.polygon([(cx, top), (left, mid), (cx, bot)], fill=hsv2rgb(0.95, 0.9, 0.9))
    else:
        d.polygon([(cx, top), (right, mid), (cx, bot), (left, mid)], fill=color)
        # facet shading
        d.polygon([(cx, top), (left, mid), (cx, mid)], fill=tuple(min(255, c + 45) for c in color))
        d.polygon([(cx, top), (right, mid), (cx, mid)], fill=tuple(max(0, c - 35) for c in color))
    # outline
    outline_col = tuple(int(c * 0.6) for c in color) if color else (60, 60, 70)
    d.polygon([(cx, top), (right, mid), (cx, bot), (left, mid)], outline=outline_col, width=2)
    # bright top highlight
    d.polygon([(cx, top + 2), (cx - 3, mid - 8), (cx + 3, mid - 8)], fill=(255, 255, 255, 220))
    return img


def draw_coin():
    img = Image.new('RGBA', (PIX, PIX), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx = cy = PIX / 2
    r = PIX / 2 - 4
    # outer rim
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(120, 85, 20), outline=(80, 55, 10), width=2)
    # inner gold
    r2 = r - 4
    d.ellipse([cx - r2, cy - r2, cx + r2, cy + r2], fill=(240, 190, 70))
    # emboss star
    s = r2 * 0.9
    star = []
    for i in range(10):
        ang = -math.pi / 2 + i * math.pi / 5
        rr = s if i % 2 == 0 else s * 0.45
        star.append((cx + math.cos(ang) * rr, cy + math.sin(ang) * rr))
    d.polygon(star, fill=(200, 150, 45), outline=(150, 110, 30))
    # sparkle
    d.line([cx + r * 0.2, cy - r * 0.9, cx + r * 0.55, cy - r * 0.55], fill=(255, 255, 255, 230), width=2)
    return img


def draw_stabilizer():
    img = Image.new('RGBA', (PIX, PIX), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # body (rounded vial)
    bx0, by0, bx1, by1 = 14, 6, 34, 42
    d.rounded_rectangle([bx0, by0, bx1, by1], radius=5, fill=(230, 234, 240), outline=(140, 150, 165), width=2)
    # inner liquid (stabilizer blue)
    d.rounded_rectangle([bx0 + 2, 22, bx1 - 2, by1 - 2], radius=4, fill=(90, 180, 235), outline=(60, 140, 200), width=1)
    # cap
    d.rectangle([bx0 - 1, by0 - 5, bx1 + 1, by0 + 2], fill=(120, 130, 150), outline=(80, 90, 110), width=1)
    # shine
    d.line([bx0 + 3, by0 + 3, bx0 + 3, by1 - 3], fill=(255, 255, 255, 180), width=2)
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    save(draw_coin(), 'coin.png')
    save(draw_stabilizer(), 'stabilizer.png')
    for emo, col in EMO_COLOR.items():
        save(draw_energy(col), f'energy_{emo}.png')
        save(draw_crystal(col), f'essence_{emo}.png')
    save(draw_energy(None, chaos=True), 'energy_chaos.png')
    save(draw_crystal(None, chaos=True), 'essence_chaos.png')
    print('DONE')


if __name__ == '__main__':
    main()
