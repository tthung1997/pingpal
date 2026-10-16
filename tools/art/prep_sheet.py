#!/usr/bin/env python3
"""Turn a folder of reference strips (one image per animation, 4 panels each) into a clean sprite sheet.

Each reference is a 4-panel image of the same character on a dark floor. For every panel this
script cuts the character out (warm fur colours, plus the dark outline hugging it, plus floating
bits such as Zzz and "?"), re-pixelates it onto a true pixel grid, aligns all frames of an
animation to one ground line and body centre, and quantizes everything to one shared palette.

  python tools/art/prep_sheet.py <refs-dir> art/corgi/base_sheet.png [--layout art/corgi/layout.json]
                                 [--scale 8] [--colors 32]

<refs-dir> holds <name>.webp|png for each name in ANIMS (the order of rows in the sheet).
Writes the sheet (RGBA) and a layout JSON (cell size, anchor, per-frame body boxes) that
tools/art/corgi.js uses to place extras such as hearts and the ball.
"""
import argparse
import json
import os
import sys

import numpy as np
from PIL import Image, ImageFilter

ANIMS = ["idle", "walk", "sleep", "thinking", "happy", "alert", "sad"]   # the shared, species-neutral set
FRAMES = 4
# Frame order per animation as (source panel, mirrored). The alert strip turns the dog around
# (head and tail swap sides between panels 2 and 3), so panels 3 and 4 are mirrored to keep one
# orientation across the loop.
FRAME_ORDER = {"alert": [(0, False), (1, False), (2, True), (3, True)]}
MARGIN_TOP, MARGIN_RIGHT, MARGIN_BOTTOM, MARGIN_LEFT = 14, 16, 2, 4   # room for scripted extras


def find_ref(folder, name):
    for ext in (".webp", ".png"):
        p = os.path.join(folder, name + ext)
        if os.path.exists(p):
            return p
    raise SystemExit(f"missing reference for '{name}' in {folder}")


def morph(mask, grow, k):
    """Square dilate (grow=True) or erode by k pixels."""
    img = Image.fromarray((mask * 255).astype(np.uint8))
    f = ImageFilter.MaxFilter(2 * k + 1) if grow else ImageFilter.MinFilter(2 * k + 1)
    return np.asarray(img.filter(f)) > 127


def fill_holes(mask):
    h, w = mask.shape
    outside = np.zeros_like(mask, dtype=bool)
    stack = [(y, x) for y in range(h) for x in (0, w - 1)] + [(y, x) for x in range(w) for y in (0, h - 1)]
    while stack:
        y, x = stack.pop()
        if not (0 <= y < h and 0 <= x < w) or outside[y, x] or mask[y, x]:
            continue
        outside[y, x] = True
        stack.extend(((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)))
    return ~outside


def components(mask):
    """4-connected components, as a list of (area, (ys, xs)) sorted largest first."""
    h, w = mask.shape
    seen = np.zeros_like(mask, dtype=bool)
    out = []
    for sy in range(h):
        for sx in range(w):
            if not mask[sy, sx] or seen[sy, sx]:
                continue
            stack, cells = [(sy, sx)], []
            seen[sy, sx] = True
            while stack:
                y, x = stack.pop()
                cells.append((y, x))
                for ny, nx in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)):
                    if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not seen[ny, nx]:
                        seen[ny, nx] = True
                        stack.append((ny, nx))
            ys = np.array([c[0] for c in cells])
            xs = np.array([c[1] for c in cells])
            out.append((len(cells), (ys, xs)))
    out.sort(key=lambda c: -c[0])
    return out


def segment_panel(rgb):
    """rgb: float array (h, w, 3) of one panel at working resolution. Returns (dog_mask, full_mask)."""
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    lum = 0.3 * r + 0.59 * g + 0.11 * b
    warm = (r > 110) & (r - b > 35) & (r >= g - 4)
    white = (r > 215) & (g > 200) & (r >= b)                        # white muzzle/blaze; excludes bluish motion lines
    comps = components(warm | white)
    if not comps:
        raise SystemExit("no dog found in a panel")
    dog = np.zeros(warm.shape, dtype=bool)
    dog[comps[0][1]] = True
    y0, y1 = comps[0][1][0].min(), comps[0][1][0].max()
    x0, x1 = comps[0][1][1].min(), comps[0][1][1].max()
    extras = np.zeros(warm.shape, dtype=bool)
    reach = 40                                                      # floating bits must be near the dog
    for area, (ys, xs) in components(warm & ~dog):
        if area >= 6 and ys.min() > y0 - 2 * reach and ys.max() < y1 + reach \
                and xs.min() > x0 - reach and xs.max() < x1 + reach:
            extras[ys, xs] = True
    body = fill_holes(morph(morph(dog, True, 2), False, 2))         # close pinholes, fill eyes/nose
    near = morph(body, True, 3)
    outline = (lum < 75) & near                                     # the dark outline
    tears = (b > r + 25) & (b > 130) & morph(body, True, 6)
    full = body | outline | extras | tears
    # A profile nose sits on the silhouette edge and is bigger than the outline band: close small
    # notches in the outline, but only with very dark pixels so the floor never sneaks in.
    notch = morph(morph(full, True, 4), False, 4) & ~full & (lum < 50)
    out = full | notch
    out[:, :2] = False                                              # the dark divider line between panels
    out[:, -2:] = False
    return body, out


def bleed(rgb, mask, iters=12):
    """Push the colours of masked pixels outward so box-downsampling never mixes in the floor."""
    col = rgb.copy()
    filled = mask.copy()
    for _ in range(iters):
        acc = np.zeros_like(col)
        cnt = np.zeros(filled.shape)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            f = np.roll(filled, (dy, dx), (0, 1))
            acc += np.roll(col, (dy, dx), (0, 1)) * f[..., None]
            cnt += f
        new = (~filled) & (cnt > 0)
        col[new] = acc[new] / cnt[new][:, None]
        filled |= new
        if not new.any():
            break
    return col


def box(arr, f):
    """Average-downsample an (h, w[, c]) float array by integer factor f."""
    h, w = arr.shape[:2]
    h2, w2 = h // f, w // f
    arr = arr[: h2 * f, : w2 * f]
    shape = (h2, f, w2, f) + arr.shape[2:]
    return arr.reshape(shape).mean(axis=(1, 3))


def process(path, scale, name=""):
    im = Image.open(path).convert("RGB")
    work = 4
    small = np.asarray(im.resize((im.width // work, im.height // work), Image.BOX)).astype(float)
    h, w, _ = small.shape
    pw = w // FRAMES
    f2 = scale // work
    panels = []
    for i in range(FRAMES):
        panel = small[:, i * pw:(i + 1) * pw]
        dog, full = segment_panel(panel)
        col = bleed(panel, full)
        art_rgb = box(col, f2)
        art_a = box(full.astype(float), f2) >= 0.5
        art_dog = box(dog.astype(float), f2) >= 0.5
        panels.append((art_rgb, art_a, art_dog))
    frames = []
    for index, mirrored in FRAME_ORDER.get(name, [(i, False) for i in range(FRAMES)]):
        rgb, a, dog = panels[index]
        frames.append((rgb[:, ::-1], a[:, ::-1], dog[:, ::-1]) if mirrored else (rgb, a, dog))
    return frames


def bbox(mask):
    ys, xs = np.where(mask)
    return xs.min(), ys.min(), xs.max() + 1, ys.max() + 1


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("refs")
    ap.add_argument("out")
    ap.add_argument("--layout", default=None)
    ap.add_argument("--scale", type=int, default=8, help="source pixels per art pixel (multiple of 4)")
    ap.add_argument("--colors", type=int, default=32)
    args = ap.parse_args()

    data = {}
    for name in ANIMS:
        data[name] = process(find_ref(args.refs, name), args.scale, name)
        print("processed", name, [tuple(int(v) for v in bbox(f[1])) for f in data[name]])

    # Per animation: one ground line (the lowest body pixel of any frame) and per-frame body centre.
    info = {}
    left = right = up = 0
    for name, frames in data.items():
        boxes = [bbox(f[1]) for f in frames]
        dogs = [bbox(f[2]) for f in frames]
        ground = max(b[3] for b in dogs)
        cx = [int(round(np.where(f[2])[1].mean())) for f in frames]
        info[name] = {"ground": ground, "cx": cx, "boxes": boxes, "dogs": dogs}
        for k in range(FRAMES):
            left = max(left, cx[k] - boxes[k][0])
            right = max(right, boxes[k][2] - cx[k])
            up = max(up, ground - boxes[k][1])
    cw = MARGIN_LEFT + left + right + MARGIN_RIGHT
    ch = MARGIN_TOP + up + MARGIN_BOTTOM
    cx_cell = MARGIN_LEFT + left
    ground_cell = MARGIN_TOP + up
    print("cell", cw, ch, "anchor", cx_cell, ground_cell)

    sheet_rgb = np.zeros((ch * len(ANIMS), cw * FRAMES, 3), dtype=np.uint8)
    sheet_a = np.zeros((ch * len(ANIMS), cw * FRAMES), dtype=bool)
    layout = {"cell": [int(cw), int(ch)], "anchor": [int(cx_cell), int(ground_cell)], "frames": {}}
    for row, name in enumerate(ANIMS):
        layout["frames"][name] = []
        for k, (rgb, a, dog) in enumerate(data[name]):
            dx = cx_cell - info[name]["cx"][k]
            dy = ground_cell - info[name]["ground"]
            ys, xs = np.where(a)
            ty, tx = ys + dy + row * ch, xs + dx + k * cw
            ok = (ty >= row * ch) & (ty < (row + 1) * ch) & (tx >= k * cw) & (tx < (k + 1) * cw)
            sheet_rgb[ty[ok], tx[ok]] = np.clip(rgb[ys[ok], xs[ok]], 0, 255).astype(np.uint8)
            sheet_a[ty[ok], tx[ok]] = True
            d = info[name]["dogs"][k]
            layout["frames"][name].append({"dog": [int(d[0] + dx), int(d[1] + dy), int(d[2] + dx), int(d[3] + dy)]})

    # One shared palette for the whole sheet.
    px = sheet_rgb[sheet_a].reshape(-1, 1, 3)
    pal_src = Image.fromarray(px, "RGB")
    pal = pal_src.quantize(colors=args.colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    q = Image.fromarray(sheet_rgb, "RGB").quantize(palette=pal, dither=Image.Dither.NONE).convert("RGB")
    out = np.dstack([np.asarray(q), (sheet_a * 255).astype(np.uint8)])
    os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
    Image.fromarray(out, "RGBA").save(args.out)
    print("wrote", args.out, (cw * FRAMES, ch * len(ANIMS)), "colors:", len(set(map(tuple, np.asarray(q)[sheet_a].tolist()))))
    if args.layout:
        with open(args.layout, "w", encoding="utf-8", newline="\n") as f:
            json.dump(layout, f, indent=1)
        print("wrote", args.layout)


if __name__ == "__main__":
    sys.exit(main())
