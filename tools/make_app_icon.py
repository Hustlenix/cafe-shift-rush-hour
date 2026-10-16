"""Draw the original CAFE SHIFT app icon (window icon / Web favicon).

Deterministic pixel art on a 32x32 grid, nearest-upscaled 8x to 256x256.
The palette matches the in-game colours; no external art is loaded. This is
the same code-authored approach used for the menu icons and chimes in
tools/import_assets.py.
"""
from pathlib import Path

from PIL import Image, ImageDraw

SCALE = 8
GRID = 32

BG = (0x21, 0x1B, 0x22, 255)      # dark plum backdrop
PAPER = (0xFF, 0xF3, 0xD2, 255)   # cream cup
WOOD = (0x3A, 0x2B, 0x2B, 255)    # dark roast coffee
MUTED = (0xB9, 0xA2, 0x8F, 255)   # saucer
LINE = (0x6C, 0x51, 0x49, 255)    # saucer shadow
GOLD = (0xE7, 0xBA, 0x72, 255)    # steam
CORAL = (0xC8, 0x66, 0x52, 255)   # heart accent


def build() -> Image.Image:
    image = Image.new("RGBA", (GRID, GRID), (0, 0, 0, 0))
    d = ImageDraw.Draw(image)

    # Rounded app-tile backdrop.
    d.rounded_rectangle([0, 0, 31, 31], radius=6, fill=BG)

    # Saucer under the cup.
    d.rectangle([4, 25, 23, 25], fill=MUTED)
    d.rectangle([6, 26, 21, 26], fill=LINE)

    # Cup: rim, cream body with tapered base, dark coffee inset.
    d.rectangle([6, 13, 21, 13], fill=PAPER)
    d.rectangle([7, 14, 20, 23], fill=PAPER)
    d.rectangle([8, 24, 19, 24], fill=PAPER)
    d.rectangle([8, 14, 19, 15], fill=WOOD)

    # Handle ring attached at the right edge.
    for x in range(21, 25):
        d.point((x, 15), fill=PAPER)
        d.point((x, 19), fill=PAPER)
    for y in range(16, 19):
        d.point((25, y), fill=PAPER)

    # Steam wisps.
    for x, y in ((11, 12), (11, 11), (12, 10), (12, 9),
                 (15, 12), (15, 11), (16, 10), (16, 9)):
        d.point((x, y), fill=GOLD)

    # Small heart.
    for x, y in ((23, 4), (25, 4),
                 (22, 5), (23, 5), (24, 5), (25, 5), (26, 5),
                 (23, 6), (24, 6), (25, 6),
                 (24, 7)):
        d.point((x, y), fill=CORAL)

    return image


def main() -> None:
    root = Path(__file__).resolve().parent.parent
    out = root / "assets" / "original" / "icon.png"
    icon = build().resize((GRID * SCALE, GRID * SCALE), Image.NEAREST)
    icon.save(out)
    print(f"Wrote {out} ({icon.width}x{icon.height}, {SCALE}x pixel scale).")


if __name__ == "__main__":
    main()
