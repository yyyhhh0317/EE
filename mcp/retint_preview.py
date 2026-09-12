#!/usr/bin/env python3
"""Re-tint color assets from the authoritative factor colours (data/factors/*.json).
Generates a PREVIEW folder + a comparison sheet (old vs new). Does NOT overwrite
anything under art/ except creating art/_preview/."""
import os
import sys
import math
from PIL import Image, ImageDraw, ImageFont, ImageOps

sys.path.insert(0, r'D:\yyy\EE\mcp')
import draw_items as di  # noqa: E402  (its main() is guarded)

ART = r'D:\yyy\EE\art'
OUT = os.path.join(ART, '_preview')

# ── canonical factor colours ────────────────────────────────────────────────
# authoritative = from data/factors/*.json ; provisional = data not written yet
CANON = [
    ('joy',      '#ffd166', True,  '喜'),
    ('rage',     '#e5484d', True,  '怒'),
    ('sorrow',   '#6fa8dc', True,  '哀'),
    ('fear',     '#5b2b8f', True,  '惧'),
    ('disgust',  '#7cb342', False, '厌'),
    ('surprise', '#a8dcff', False, '惊'),
    ('anxiety',  '#a79ed0', False, '忧'),
    ('chaos',    None,      False, '混沌'),   # 特殊：彩虹，保持不变
]
SKILL_FN = {
    'joy': di.draw_skill_joy, 'rage': di.draw_skill_rage, 'sorrow': di.draw_skill_sorrow,
    'fear': di.draw_skill_fear, 'disgust': di.draw_skill_disgust,
    'surprise': di.draw_skill_surprise, 'anxiety': di.draw_skill_anxiety,
    'chaos': di.draw_skill_chaos,
}


def hex2rgb(h, a=None):
    h = h.lstrip('#')
    c = tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))
    return c + (a,) if a is not None else c


def mix(c1, c2, t):
    return tuple(int(a + (b - a) * t) for a, b in zip(c1, c2))


def shade(c, f):
    return tuple(max(0, min(255, int(v * f))) for v in c)


def palette(main):
    """One canonical colour -> 3-stop grade (shadow, mid, highlight)."""
    return (shade(main, 0.35), main, mix(main, (255, 255, 255), 0.55))


def pixelate(img, grid=128):
    s = img.resize((grid, grid), Image.NEAREST)
    return s.resize(img.size, Image.NEAREST)


def new_map(pal):
    base = Image.open(os.path.join(ART, 'maps', 'base_map.png')).convert('RGB')
    gray = pixelate(base.convert('L'))
    g = ImageOps.colorize(gray, black=pal[0], white=pal[2], mid=pal[1])
    return g.quantize(colors=16).convert('RGB')


def build():
    os.makedirs(OUT, exist_ok=True)
    # apply canonical colours to draw_items' palette so skill icons re-tint too
    di.EMO_COLOR.clear()
    for name, hexv, auth, _cn in CANON:
        if hexv:
            di.EMO_COLOR[name] = hex2rgb(hexv)
            main = hex2rgb(hexv)
            pal = palette(main)
            # essence + energy (new)
            di.draw_crystal(main).resize((di.FINAL, di.FINAL), Image.NEAREST).save(
                os.path.join(OUT, f'new_essence_{name}.png'))
            di.draw_energy(main).resize((di.FINAL, di.FINAL), Image.NEAREST).save(
                os.path.join(OUT, f'new_energy_{name}.png'))
            # skill icon (new)
            SKILL_FN[name]().resize((di.FINAL, di.FINAL), Image.NEAREST).save(
                os.path.join(OUT, f'new_skill_{name}.png'))
            # map (new)
            new_map(pal).save(os.path.join(OUT, f'new_map_{name}.png'))
        else:
            di.EMO_COLOR[name] = (200, 120, 220)
            SKILL_FN[name]().resize((di.FINAL, di.FINAL), Image.NEAREST).save(
                os.path.join(OUT, 'new_skill_chaos.png'))
    print('preview assets ->', OUT)


# ── comparison sheet ────────────────────────────────────────────────────────
def font(sz):
    for p in (r'C:\Windows\Fonts\msyh.ttc', r'C:\Windows\Fonts\simhei.ttf',
              r'C:\Windows\Fonts\consola.ttf'):
        try:
            return ImageFont.truetype(p, sz)
        except Exception:
            continue
    return ImageFont.load_default()


def small(img, box):
    return img.resize((box, box), Image.NEAREST)


def sheet():
    CELL, PAD, LBL = 78, 6, 176
    HDR, FOOT = 46, 30
    rows = len(CANON)
    W = LBL + 7 * (CELL + PAD) + PAD
    H = HDR + rows * (CELL + PAD) + FOOT
    sh = Image.new('RGB', (W, H), (24, 22, 32))
    d = ImageDraw.Draw(sh)
    f14, f12, f11 = font(14), font(12), font(11)

    heads = ['因子 / 数据表色', '精华 旧', '精华 新', '能量 旧', '能量 新', '地图 旧', '地图 新', '技能 新']
    for i, h in enumerate(heads):
        x = PAD if i == 0 else LBL + (i - 1) * (CELL + PAD) + PAD
        d.text((x + 2, 16), h, font=f12, fill=(210, 205, 230))

    for r, (name, hexv, auth, cn) in enumerate(CANON):
        y = HDR + r * (CELL + PAD)
        # label block
        c = hex2rgb(hexv) if hexv else (200, 120, 220)
        d.rectangle([PAD, y, PAD + 30, y + 30], fill=c, outline=(200, 195, 220))
        d.text((PAD + 38, y - 1), f'{name}', font=f14, fill=(235, 232, 245))
        d.text((PAD + 38, y + 16), f'{cn}  {hexv or "彩虹"}', font=f11, fill=(170, 165, 195))
        tag = '数据表' if auth else ('特殊' if name == 'chaos' else '临时·待定')
        d.text((PAD, y + 36), tag, font=f11,
               fill=(120, 220, 150) if auth else (240, 190, 90))

        # old vs new assets
        cells = [
            Image.open(os.path.join(ART, 'items', f'essence_{name}.png')).convert('RGBA'),
            Image.open(os.path.join(OUT, f'new_essence_{name}.png')).convert('RGBA')
            if hexv else Image.open(os.path.join(ART, 'items', f'essence_{name}.png')).convert('RGBA'),
            Image.open(os.path.join(ART, 'items', f'energy_{name}.png')).convert('RGBA'),
            Image.open(os.path.join(OUT, f'new_energy_{name}.png')).convert('RGBA')
            if hexv else Image.open(os.path.join(ART, 'items', f'energy_{name}.png')).convert('RGBA'),
            Image.open(os.path.join(ART, 'maps', f'{name}_map.png')).convert('RGB'),
            Image.open(os.path.join(OUT, f'new_map_{name}.png')).convert('RGB')
            if hexv else Image.open(os.path.join(ART, 'maps', f'{name}_map.png')).convert('RGB'),
            Image.open(os.path.join(OUT, f'new_skill_{name}.png')).convert('RGBA'),
        ]
        for i, im in enumerate(cells):
            x = LBL + i * (CELL + PAD) + PAD
            thumb = small(im, CELL)
            if thumb.mode == 'RGBA':
                sh.paste(thumb, (x, y), thumb)
            else:
                sh.paste(thumb, (x, y))

    d.text((PAD, H - 21),
           '全部资产按数据表色重出；「临时·待定」的 4 个因子暂无数据表，暂用建议色；混沌保持彩虹不变。',
           font=f11, fill=(150, 145, 175))
    sh.save(os.path.join(OUT, '配色样张.png'))
    print('sheet ->', os.path.join(OUT, '配色样张.png'), sh.size)


if __name__ == '__main__':
    build()
    sheet()
    print('DONE')
