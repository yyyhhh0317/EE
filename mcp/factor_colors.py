#!/usr/bin/env python3
"""单一配色源头（single source of truth）——所有因子相关素材的颜色都由这里派生。

权威色来自数据表 `data/factors/*.json` 的 `color` 字段；数据表尚未填写的因子
用「临时·待定」建议色，等数据表补齐后改这里的 CANON 即可，全部素材重跑一致。

用法：
    from factor_colors import EMO_COLOR, PALETTES, CANON
    EMO_COLOR[name]   -> (r, g, b)          单色（能量球 / 精华晶体 / 技能图标）
    PALETTES[name]    -> (shadow, mid, high) 三段色板（地图着色）
"""
import os
import json

# name -> (hex, 是否来自数据表)
CANON = {
    'joy':      ('#ffd166', True),   # data/factors/factor_joy.json
    'rage':     ('#e5484d', True),   # data/factors/factor_rage.json
    'sorrow':   ('#6fa8dc', True),   # data/factors/factor_sorrow.json
    'fear':     ('#5b2b8f', True),   # data/factors/factor_fear.json
    'disgust':  ('#7cb342', False),  # 临时·待定（数据表未做）
    'surprise': ('#a8dcff', False),  # 临时·待定
    'anxiety':  ('#a79ed0', False),  # 临时·待定
}
# 混沌（factor_chaos）：特殊处理，保留彩虹效果，不使用单色。

FACTORS_DIR = r'D:\yyy\EE\data\factors'


def hex2rgb(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def mix(c1, c2, t):
    return tuple(int(a + (b - a) * t) for a, b in zip(c1, c2))


def shade(c, f):
    return tuple(max(0, min(255, int(v * f))) for v in c)


def palette(main):
    """一个权威主色 -> 三段色板 (shadow, mid, highlight)。"""
    return (shade(main, 0.35), main, mix(main, (255, 255, 255), 0.55))


def sync_from_data():
    """若 data/factors/*.json 存在，用其中的 color 覆盖 CANON（数据表为准）。"""
    changed = []
    for name in list(CANON):
        p = os.path.join(FACTORS_DIR, f'factor_{name}.json')
        if not os.path.exists(p):
            continue
        try:
            with open(p, encoding='utf-8') as f:
                col = json.load(f).get('color')
            if col and col.lower() != CANON[name][0].lower():
                changed.append((name, CANON[name][0], col))
                CANON[name] = (col, True)
        except Exception:
            continue
    return changed


sync_from_data()

EMO_COLOR = {n: hex2rgb(h) for n, (h, _ok) in CANON.items()}
PALETTES = {n: palette(hex2rgb(h)) for n, (h, _ok) in CANON.items()}

if __name__ == '__main__':
    for n, (h, ok) in CANON.items():
        r, g, b = hex2rgb(h)
        s, m, hi = palette((r, g, b))
        print(f'{n:9s} {h}  {"数据表" if ok else "临时·待定"}   shadow={s} mid={m} high={hi}')
    print('chaos     彩虹（特殊，不使用单色）')
