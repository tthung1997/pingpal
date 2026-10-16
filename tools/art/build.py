#!/usr/bin/env python3
"""Build character-pack art with LibreSprite scripts.

LibreSprite resets its script environment on app.open(), so every sheet script is bundled as:
  var DIR=...; var DOC=app.open(<@open png>); var SPR=DOC.sprite;  <lib.js>  <script>

Header directives (first lines of a sheet script):
  // @open <repo-relative png>   document to open (created blank if missing)
  // @canvas <W>x<H>             size of the blank PNG to create when missing

Usage:
  python tools/art/build.py corgi        # bundle + run via `libresprite -b --script`
  python tools/art/build.py --no-run corgi   # only write tools/art/dist/corgi.bundle.js
Set LIBRESPRITE_EXE if libresprite is not on PATH.
"""
import os
import re
import shutil
import struct
import subprocess
import sys
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
DIST = os.path.join(HERE, "dist")
FALLBACK_EXES = [r"S:\LibreSprite\libresprite.exe", r"C:\Program Files\LibreSprite\libresprite.exe"]


def write_blank_png(path, w, h):
    raw = b"".join(b"\x00" + b"\x00" * (w * 4) for _ in range(h))

    def chunk(t, d):
        c = struct.pack(">I", len(d)) + t + d
        return c + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)

    png = (b"\x89PNG\r\n\x1a\n"
           + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
           + chunk(b"IDAT", zlib.compress(raw))
           + chunk(b"IEND", b""))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(png)


def find_exe():
    exe = os.environ.get("LIBRESPRITE_EXE") or shutil.which("libresprite")
    if exe:
        return exe
    for candidate in FALLBACK_EXES:
        if os.path.exists(candidate):
            return candidate
    raise SystemExit("libresprite not found: put it on PATH or set LIBRESPRITE_EXE")


def embed_source(rel):
    """Encode a small PNG as JS vars: SRC_W/SRC_H, SRC_PAL (hex colours) and SRC_ROWS (one string
    per row, '.' = transparent, else a letter indexing SRC_PAL). LibreSprite scripts can only
    read the document they opened, so the source art travels inside the bundle instead."""
    from PIL import Image
    im = Image.open(os.path.join(ROOT, *rel.split("/"))).convert("RGBA")
    pal, rows = [], []
    for y in range(im.height):
        row = ""
        for x in range(im.width):
            r, g, b, a = im.getpixel((x, y))
            if a < 128:
                row += "."
                continue
            c = "#%02x%02x%02x" % (r, g, b)
            if c not in pal:
                pal.append(c)
            row += chr(ord("a") + pal.index(c))
        rows.append(row)
    if len(pal) > 26:
        raise SystemExit(f"{rel}: {len(pal)} colours, at most 26 supported")
    return (f"var SRC_W = {im.width}, SRC_H = {im.height};\n"
            f"var SRC_PAL = {pal!r};\n"
            f"var SRC_ROWS = {rows!r};")


def bundle(name, proof=False):
    with open(os.path.join(HERE, name + ".js"), encoding="utf-8") as f:
        body = f.read()
    opened = re.search(r"^//\s*@open\s+(\S+)", body, re.M)
    if not opened:
        raise SystemExit(f"{name}.js: missing // @open directive")
    rel = opened.group(1)
    source = re.search(r"^//\s*@source\s+(\S+)", body, re.M)
    base = re.search(r"^//\s*@base\s+(\S+)", body, re.M)
    layout = re.search(r"^//\s*@layout\s+(\S+)", body, re.M)
    canvas = re.search(r"^//\s*@canvas\s+(\d+)x(\d+)", body, re.M)
    if proof:
        # Style proof: a single frame into local/ so the real sheet is untouched.
        rel = f"local/{name}_proof.png"
        canvas = re.search(r"^//\s*@proof-canvas\s+(\d+)x(\d+)", body, re.M)
        if not canvas:
            raise SystemExit(f"{name}.js has no // @proof-canvas")
    target = os.path.join(ROOT, *rel.split("/"))
    if base and not proof:
        # Start from the prepared base sheet so a re-run never stacks extras twice.
        os.makedirs(os.path.dirname(target), exist_ok=True)
        shutil.copyfile(os.path.join(ROOT, *base.group(1).split("/")), target)
    elif canvas:
        # Always start from a blank sheet so stale pixels never survive a re-run.
        write_blank_png(target, int(canvas.group(1)), int(canvas.group(2)))
    elif not os.path.exists(target):
        raise SystemExit(f"{rel} does not exist and {name}.js has no // @canvas or // @base")
    with open(os.path.join(HERE, "lib.js"), encoding="utf-8") as f:
        lib = f.read()
    layout_js = ""
    if layout:
        with open(os.path.join(ROOT, *layout.group(1).split("/")), encoding="utf-8") as f:
            layout_js = "var LAYOUT = " + f.read() + ";"
    parts = [
        f'var DIR = "{ROOT.replace(os.sep, "/")}/";',
        "var PROOF_MODE = true;" if proof else "",
        embed_source(source.group(1)) if source else "",
        layout_js,
        f'var DOC = app.open(DIR + "{rel}");',
        "var SPR = DOC.sprite;  // app.activeSprite is undefined in --batch mode",
        lib,
        body,
    ]
    os.makedirs(DIST, exist_ok=True)
    out = os.path.join(DIST, name + (".proof" if proof else "") + ".bundle.js")
    with open(out, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(parts))
    return out


if __name__ == "__main__":
    flags = [a for a in sys.argv[1:] if a.startswith("--")]
    names = [a for a in sys.argv[1:] if not a.startswith("--")] or ["corgi"]
    for n in names:
        out = bundle(n, "--proof" in flags)
        print("wrote", os.path.relpath(out, ROOT))
        if "--no-run" not in flags:
            subprocess.run([find_exe(), "-b", "--script", out], check=True)
