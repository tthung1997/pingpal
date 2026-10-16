"""Builds icon.ico (the Windows exe icon) from icon.png.

    python tools/art/make_ico.py

Each size is a nearest-neighbour scale of the 104x104 pixel-art icon, so it stays crisp.
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SIZES = [16, 24, 32, 48, 64, 128, 256]

src = Image.open(ROOT / "icon.png").convert("RGBA")
frames = [src.resize((s, s), Image.NEAREST) for s in SIZES]
frames[-1].save(ROOT / "icon.ico", format="ICO", sizes=[(s, s) for s in SIZES], append_images=frames[:-1])
print("wrote icon.ico")
