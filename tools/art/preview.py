#!/usr/bin/env python3
"""Upscale a character sheet over a checkerboard for eyeballing: python preview.py packs/corgi/sheet.png out.png [scale]"""
import sys
from PIL import Image

src, dst = sys.argv[1], sys.argv[2]
scale = int(sys.argv[3]) if len(sys.argv) > 3 else 4
im = Image.open(src).convert("RGBA")
bg = Image.new("RGBA", im.size, (70, 90, 120, 255))
bg.alpha_composite(im)
bg.resize((im.width * scale, im.height * scale), Image.NEAREST).save(dst)
