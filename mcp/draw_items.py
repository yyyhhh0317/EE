#!/usr/bin/env python3
"""Programmatic clean pixel-art item sprites (transparent, crisp, recolorable).
Outputs art/items/: coin, stabilizer, energy_<emotion> x8, essence_<emotion> x8."""
import os
import math
import numpy as np
from PIL import Image, ImageDraw

from factor_colors import EMO_COLOR   # 配色唯一源头（权威源：data/factors/*.json）

OUT = r'D:\yyy\EE\art\items'
PIX = 48            # pixel-grid resolution (draw at this size, then upscale)
UP = 2              # upscale -> final 96px sprites
FINAL = PIX * UP

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


def draw_memory():
    """记忆碎片 — a broken glass shard of a memory."""
    img = Image.new('RGBA', (PIX, PIX), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    shard = [(24, 5), (38, 17), (35, 34), (26, 45), (14, 40), (9, 26), (13, 12)]
    d.polygon(shard, fill=(120, 175, 215), outline=(70, 110, 150))
    d.polygon([(24, 5), (38, 17), (24, 26)], fill=(170, 215, 245))
    d.polygon([(24, 5), (13, 12), (24, 26)], fill=(95, 150, 195))
    d.polygon([(24, 26), (35, 34), (26, 45), (14, 40), (9, 26)], fill=(140, 190, 230))
    d.polygon([(24, 26), (35, 34), (26, 45)], fill=(110, 165, 210))
    d.line([(20, 10), (17, 20)], fill=(255, 255, 255, 200), width=2)
    return img


def draw_potion():
    """药剂 — a round flask with red liquid."""
    img = Image.new('RGBA', (PIX, PIX), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx = PIX / 2
    d.ellipse([cx - 15, 16, cx + 15, 44], fill=(232, 236, 242), outline=(150, 160, 175), width=2)
    d.ellipse([cx - 12, 25, cx + 12, 41], fill=(215, 70, 70))
    d.rectangle([cx - 12, 32, cx + 12, 41], fill=(215, 70, 70))
    d.ellipse([cx - 12, 25, cx + 12, 41], outline=(150, 160, 175))
    d.rectangle([cx - 5, 8, cx + 5, 18], fill=(232, 236, 242), outline=(150, 160, 175), width=1)
    d.rectangle([cx - 6, 3, cx + 6, 9], fill=(160, 110, 70), outline=(110, 75, 45))
    d.line([(cx - 8, 24), (cx - 8, 34)], fill=(255, 255, 255, 170), width=2)
    return img


def draw_syringe():
    """注射器 — injects factor essence (core mechanic)."""
    img = Image.new('RGBA', (PIX, PIX), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx = PIX / 2
    d.rectangle([cx - 7, 12, cx + 7, 36], fill=(235, 238, 244), outline=(140, 150, 165), width=2)
    d.rectangle([cx - 5, 22, cx + 5, 34], fill=(150, 90, 200))
    for yy in (16, 20, 24, 28, 32):
        d.line([cx + 2, yy, cx + 6, yy], fill=(175, 185, 200), width=1)
    d.rectangle([cx - 4, 6, cx + 4, 13], fill=(150, 160, 175))
    d.rectangle([cx - 8, 3, cx + 8, 7], fill=(180, 190, 205), outline=(120, 130, 145))
    d.rectangle([cx - 1, 36, cx + 1, 45], fill=(205, 210, 220))
    return img


def draw_trait():
    """词条 — a rune stone pickup."""
    img = Image.new('RGBA', (PIX, PIX), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([10, 8, 38, 40], radius=6, fill=(58, 52, 74), outline=(125, 115, 155), width=2)
    d.polygon([(24, 14), (31, 24), (24, 34), (17, 24)], outline=(180, 240, 255), width=2)
    d.line([(24, 17), (24, 31)], fill=(180, 240, 255), width=2)
    return img


def draw_chest():
    """宝箱 — reward container."""
    img = Image.new('RGBA', (PIX, PIX), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([9, 14, 39, 26], radius=6, fill=(140, 95, 50), outline=(90, 60, 30), width=2)
    d.rectangle([10, 25, 38, 42], fill=(120, 80, 42), outline=(90, 60, 30), width=2)
    d.rectangle([21, 14, 27, 42], fill=(225, 185, 70), outline=(160, 125, 40))
    d.rectangle([20, 24, 28, 33], fill=(240, 200, 80), outline=(150, 115, 35), width=1)
    d.ellipse([22, 27, 26, 31], fill=(120, 90, 25))
    return img


def draw_hp():
    """HP — a pixel heart."""
    img = Image.new('RGBA', (PIX, PIX), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([7, 12, 25, 30], fill=(225, 60, 75), outline=(140, 25, 40), width=2)
    d.ellipse([23, 12, 41, 30], fill=(225, 60, 75), outline=(140, 25, 40), width=2)
    d.polygon([(6, 22), (24, 44), (42, 22)], fill=(225, 60, 75), outline=(140, 25, 40))
    d.line([(11, 17), (11, 24)], fill=(255, 210, 215, 220), width=3)
    return img


def draw_san():
    """SAN — a brain (mental/sanity resource)."""
    img = Image.new('RGBA', (PIX, PIX), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([7, 13, 25, 35], fill=(228, 152, 172), outline=(150, 80, 105), width=2)
    d.ellipse([23, 13, 41, 35], fill=(228, 152, 172), outline=(150, 80, 105), width=2)
    d.line([24, 14, 24, 34], fill=(150, 80, 105), width=2)
    for y in (19, 25, 31):
        d.arc([9, y - 4, 23, y + 4], 195, 345, fill=(150, 80, 105), width=2)
        d.arc([25, y - 4, 39, y + 4], 195, 345, fill=(150, 80, 105), width=2)
    d.line([(12, 17), (15, 20)], fill=(255, 220, 230, 200), width=2)
    return img


def draw_unstable():
    """失控值 — a spiky unstable burst."""
    img = Image.new('RGBA', (PIX, PIX), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx = cy = PIX / 2
    pts = []
    for i in range(20):
        ang = i * math.pi / 10
        r = 21 if i % 2 == 0 else 13
        pts.append((cx + math.cos(ang) * r, cy + math.sin(ang) * r))
    d.polygon(pts, fill=(205, 55, 70), outline=(85, 18, 35), width=2)
    d.ellipse([cx - 11, cy - 11, cx + 11, cy + 11], fill=(140, 25, 55))
    d.ellipse([cx - 5, cy - 5, cx + 5, cy + 5], fill=(255, 200, 70))
    return img


def draw_slot():
    """Empty slot frame for skills / items."""
    img = Image.new('RGBA', (PIX, PIX), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([6, 6, 42, 42], radius=7, fill=(28, 26, 40, 165), outline=(140, 130, 172), width=3)
    d.line([(11, 11), (11, 17)], fill=(95, 88, 120), width=2)
    d.line([(11, 11), (17, 11)], fill=(95, 88, 120), width=2)
    return img


DARK = (38, 33, 50)


def draw_skill_joy():
    """喜 — 加速/分裂：三重加速箭头."""
    img = Image.new('RGBA', (PIX, PIX), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c = EMO_COLOR['joy']
    for yy in (26, 36, 46):
        d.line([(14, yy), (24, yy - 10), (34, yy)], fill=DARK, width=7, joint='curve')
        d.line([(14, yy), (24, yy - 10), (34, yy)], fill=c, width=4, joint='curve')
    return img


def draw_skill_rage():
    """怒 — 狂暴/震地：烈焰."""
    img = Image.new('RGBA', (PIX, PIX), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c = EMO_COLOR['rage']
    flame = [(24, 5), (31, 19), (28, 22), (34, 30), (30, 41), (24, 45), (18, 41), (14, 30), (20, 22), (17, 19)]
    d.polygon(flame, fill=c, outline=DARK)
    d.polygon([(24, 20), (28, 31), (24, 39), (20, 31)], fill=(255, 225, 130))
    return img


def draw_skill_sorrow():
    """哀 — 减速/吸魂：泪滴."""
    img = Image.new('RGBA', (PIX, PIX), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c = EMO_COLOR['sorrow']
    d.ellipse([13, 22, 35, 44], fill=c, outline=DARK, width=2)
    d.polygon([(24, 6), (34, 30), (14, 30)], fill=c, outline=DARK)
    d.line([(19, 17), (17, 25)], fill=(255, 255, 255, 190), width=2)
    return img


def draw_skill_fear():
    """惧 — 恐惧/隐身：凝视之眼."""
    img = Image.new('RGBA', (PIX, PIX), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c = EMO_COLOR['fear']
    d.ellipse([6, 15, 42, 33], fill=(238, 238, 245), outline=DARK, width=2)
    d.ellipse([17, 13, 31, 35], fill=c, outline=DARK, width=2)
    d.ellipse([21, 20, 27, 28], fill=(18, 12, 26))
    d.ellipse([22, 21, 25, 24], fill=(255, 255, 255))
    return img


def draw_skill_disgust():
    """厌 — 中毒/腐蚀：毒液滴."""
    img = Image.new('RGBA', (PIX, PIX), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c = EMO_COLOR['disgust']
    d.ellipse([13, 20, 35, 42], fill=c, outline=DARK, width=2)
    d.polygon([(24, 7), (33, 28), (15, 28)], fill=c, outline=DARK)
    d.ellipse([18, 27, 23, 32], fill=(225, 255, 205))
    d.ellipse([26, 32, 30, 36], fill=(225, 255, 205))
    return img


def draw_skill_surprise():
    """惊 — 瞬移/惊骇：闪电."""
    img = Image.new('RGBA', (PIX, PIX), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c = EMO_COLOR['surprise']
    bolt = [(29, 4), (14, 26), (23, 26), (18, 44), (35, 20), (25, 20)]
    d.polygon(bolt, fill=c, outline=DARK)
    return img


def draw_skill_anxiety():
    """忧 — 焦虑叠层：螺旋."""
    img = Image.new('RGBA', (PIX, PIX), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c = EMO_COLOR['anxiety']
    pts = []
    for t in range(0, 760, 10):
        r = 2.5 + t * 0.028
        a = math.radians(t)
        pts.append((24 + math.cos(a) * r, 24 + math.sin(a) * r))
    d.line(pts, fill=DARK, width=6, joint='curve')
    d.line(pts, fill=c, width=3, joint='curve')
    return img


def draw_skill_chaos():
    """混沌 — 彩虹爆星."""
    img = Image.new('RGBA', (PIX, PIX), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for i in range(6):
        col = hsv2rgb(i / 6.0, 0.9, 0.95)
        a = i * math.pi / 3
        d.line([(24 + math.cos(a) * 3, 24 + math.sin(a) * 3),
                (24 + math.cos(a) * 21, 24 + math.sin(a) * 21)], fill=col, width=6)
    d.ellipse([20, 20, 28, 28], fill=(255, 255, 255), outline=(60, 50, 70), width=1)
    return img


def draw_cd():
    """Cooldown overlay — translucent dark cover for a skill slot."""
    img = Image.new('RGBA', (PIX, PIX), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([6, 6, 42, 42], radius=7, fill=(10, 8, 16, 175), outline=(70, 62, 92), width=2)
    return img


def draw_card():
    """Card / panel frame for shop and trait selection."""
    img = Image.new('RGBA', (PIX, PIX), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([4, 4, 44, 44], radius=6, fill=(34, 31, 48), outline=(152, 142, 182), width=3)
    d.line([(9, 15), (39, 15)], fill=(92, 86, 118), width=2)
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    save(draw_coin(), 'coin.png')
    save(draw_stabilizer(), 'stabilizer.png')
    save(draw_memory(), 'memory_fragment.png')
    save(draw_potion(), 'potion.png')
    save(draw_syringe(), 'syringe.png')
    save(draw_trait(), 'trait.png')
    save(draw_chest(), 'chest.png')
    save(draw_hp(), 'hp.png')
    save(draw_san(), 'san.png')
    save(draw_unstable(), 'unstable.png')
    save(draw_slot(), 'slot.png')
    for fn in (draw_skill_joy, draw_skill_rage, draw_skill_sorrow, draw_skill_fear,
               draw_skill_disgust, draw_skill_surprise, draw_skill_anxiety, draw_skill_chaos):
        save(fn(), f'skill_{fn.__name__.split("_")[-1]}.png')
    save(draw_cd(), 'cd_overlay.png')
    save(draw_card(), 'card.png')
    for emo, col in EMO_COLOR.items():
        save(draw_energy(col), f'energy_{emo}.png')
        save(draw_crystal(col), f'essence_{emo}.png')
    save(draw_energy(None, chaos=True), 'energy_chaos.png')
    save(draw_crystal(None, chaos=True), 'essence_chaos.png')
    print('DONE')


if __name__ == '__main__':
    main()
