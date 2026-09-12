#!/usr/bin/env python3
"""Audit every PNG under art/: real-PNG check, size, mode, per-folder counts,
and spec compliance. Read-only."""
import os
from collections import defaultdict
from PIL import Image

ROOT = r'D:\yyy\EE\art'
PNG_MAGIC = b'\x89PNG\r\n\x1a\n'

# spec from 素材需求.md
SPEC = {
    'hero': [(128, 128)],
    'enemies': None,
    'items': [(96, 96)],
    'maps': [(768, 768)],
    'env': [(96, 96)],
}

rows = []
bad = []
for dirpath, dirs, files in os.walk(ROOT):
    dirs[:] = [d for d in dirs if not d.startswith('_')]   # 跳过 _preview / _backup 等临时目录
    for fn in sorted(files):
        if not fn.lower().endswith('.png'):
            continue
        p = os.path.join(dirpath, fn)
        rel = os.path.relpath(p, ROOT).replace('\\', '/')
        try:
            with open(p, 'rb') as f:
                magic = f.read(8)
            im = Image.open(p)
            im.load()
            rows.append({
                'rel': rel, 'dir': rel.split('/')[0],
                'fmt': im.format, 'mode': im.mode, 'size': im.size,
                'real_png': magic == PNG_MAGIC, 'kb': round(os.path.getsize(p) / 1024, 1),
            })
        except Exception as e:  # noqa: BLE001
            bad.append((rel, str(e)))

# summary
per_dir = defaultdict(lambda: {'n': 0, 'sizes': defaultdict(int), 'modes': defaultdict(int), 'notpng': 0})
for r in rows:
    d = per_dir[r['dir']]
    d['n'] += 1
    d['sizes'][r['size']] += 1
    d['modes'][r['mode']] += 1
    if not r['real_png']:
        d['notpng'] += 1

print(f'TOTAL PNG: {len(rows)}   UNREADABLE: {len(bad)}')
print()
for d in sorted(per_dir):
    s = per_dir[d]
    sizes = ', '.join(f'{k[0]}x{k[1]}×{v}' for k, v in sorted(s['sizes'].items(), key=lambda x: -x[1]))
    modes = ', '.join(f'{k}×{v}' for k, v in sorted(s['modes'].items()))
    flag = '  ⚠️ 非真PNG ' + str(s['notpng']) if s['notpng'] else ''
    print(f'{d:10s} {s["n"]:3d} 张 | 尺寸: {sizes} | 色型: {modes}{flag}')

print()
print('--- 尺寸不符合规范的项 ---')
for r in sorted(rows, key=lambda x: x['rel']):
    d = r['dir']
    allowed = SPEC.get(d)
    if allowed is not None and r['size'] not in allowed:
        print(f'  {r["rel"]:42s} {r["size"][0]}x{r["size"][1]}')
    if d == 'enemies':
        base = os.path.basename(r['rel'])
        want = (128, 128) if 'boss' in base else (96, 96)
        if r['size'] != want:
            print(f'  {r["rel"]:42s} {r["size"][0]}x{r["size"][1]} (期望 {want[0]}x{want[1]})')

print()
print('--- 透明度检查（精灵应为 RGBA）---')
for r in sorted(rows, key=lambda x: x['rel']):
    if r['dir'] in ('hero', 'enemies', 'items', 'env') and r['mode'] != 'RGBA':
        print(f'  {r["rel"]:42s} mode={r["mode"]}')

if bad:
    print()
    print('--- 无法读取的文件 ---')
    for rel, err in bad:
        print(f'  {rel}: {err}')
