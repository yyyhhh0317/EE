#!/usr/bin/env python3
"""Re-encode every sprite PNG under art/hero and art/enemies/* as a clean PNG
and delete its stale Godot .import so the editor re-imports it fresh.
Usage: python fix_sprites.py
"""
import os, glob
from PIL import Image

ROOTS = [r'D:\yyy\EE\art\hero', r'D:\yyy\EE\art\enemies']


def reencode(path):
    im = Image.open(path)
    im.load()
    tmp = path + '.fix.png'
    im.save(tmp, 'PNG')
    os.replace(tmp, path)
    # drop stale Godot import metadata so the editor re-imports
    imp = path + '.import'
    if os.path.exists(imp):
        os.remove(imp)
        return True
    return False


def main():
    pngs = []
    for root in ROOTS:
        pngs += glob.glob(os.path.join(root, '*.png'))
        pngs += glob.glob(os.path.join(root, '*', '*.png'))
    # dedupe
    seen = set()
    pngs = [p for p in pngs if not (p in seen or seen.add(p))]
    ok, failed = 0, 0
    ART = r'D:\yyy\EE\art'
    for p in sorted(pngs):
        try:
            rm = reencode(p)
            print(f'{os.path.relpath(p, ART)}: re-encoded' + (' (.import removed)' if rm else ''))
            ok += 1
        except Exception as e:
            print(f'{p}: FAILED -> {e}')
            failed += 1
    print(f'\nDONE: {ok} ok, {failed} failed')


if __name__ == '__main__':
    main()
