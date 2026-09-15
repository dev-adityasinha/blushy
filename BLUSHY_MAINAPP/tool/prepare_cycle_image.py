# -*- coding: utf-8 -*-
"""Turns the uterus sticker into the hero illustration.

    python tool/prepare_cycle_image.py <path-to-source-image>

Writes assets/cycle_uterus.png: the sticker on a transparent background,
cropped to its edge, 3840px on the long side.

What this does and does not do, plainly:

* The sticker is found from the drawing, not the backdrop. The backdrop is
  a grey gradient that fades to near-white at the bottom, which is the same
  colour as the sticker's border, so nothing that looks for "backdrop" can
  tell the two apart there. The drawing is pink and the backdrop has no
  colour, so: take every pink pixel, grow that by the width of the white
  border, fill the holes, and keep only what is inside. The white border
  survives because it is inside the grown shape; the backdrop does not.
* Upscaling is Lanczos resampling. It gives the file 4K dimensions; it does
  not give it 4K detail. A 1080px source cannot grow information, and a
  screenshot of a sticker is already soft. On a phone the illustration is
  drawn at ~190dp, which needs ~570px at 3x -- the 4K file is far above
  that, and the resampled softness will not show at that size.
"""
import sys
from collections import deque

from PIL import Image, ImageFilter

TARGET_LONG_SIDE = 3840

# The drawing: anything with real colour where red leads. The backdrop's
# saturation is under 0.05 everywhere; the palest part of the drawing (the
# ovaries) is over 0.12.
MIN_DRAWING_SAT = 0.10

# The white border, in source pixels. Measured off the 1080px screenshot:
# the border is 20-26px wide, so the drawing is grown by 22 to cover it.
BORDER_PX = 22


def drawing_mask(img):
    """1 where the pixel is part of the pink drawing, 0 elsewhere."""
    w, h = img.size
    px = img.convert('RGB').load()
    mask = Image.new('L', img.size, 0)
    m = mask.load()
    for y in range(h):
        for x in range(w):
            r, g, b = px[x, y]
            hi, lo = max(r, g, b), min(r, g, b)
            sat = 0 if hi == 0 else (hi - lo) / hi
            if sat >= MIN_DRAWING_SAT and r >= g and r >= b:
                m[x, y] = 255
    return mask


def grow(mask, radius):
    """Dilates the mask by radius pixels."""
    return mask.filter(ImageFilter.MaxFilter(radius * 2 + 1))


def fill_holes(mask):
    """Everything not reachable from the corners through empty pixels."""
    w, h = mask.size
    m = mask.load()
    outside = bytearray(w * h)
    queue = deque()
    for x, y in [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]:
        if m[x, y] == 0 and not outside[y * w + x]:
            outside[y * w + x] = 1
            queue.append((x, y))
    while queue:
        x, y = queue.popleft()
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < w and 0 <= ny < h:
                i = ny * w + nx
                if not outside[i] and m[nx, ny] == 0:
                    outside[i] = 1
                    queue.append((nx, ny))
    filled = Image.new('L', mask.size, 255)
    f = filled.load()
    for y in range(h):
        for x in range(w):
            if outside[y * w + x]:
                f[x, y] = 0
    return filled


def cut_out(img):
    rgba = img.convert('RGBA')
    sticker = fill_holes(grow(drawing_mask(rgba), BORDER_PX))
    # A pixel of softening on the cut, so the edge is not a staircase.
    sticker = sticker.filter(ImageFilter.GaussianBlur(0.8))
    rgba.putalpha(sticker)
    return rgba


def main(source):
    img = cut_out(Image.open(source))
    box = img.getbbox()
    if box is None:
        raise SystemExit('no drawing found; lower MIN_DRAWING_SAT')
    img = img.crop(box)

    w, h = img.size
    scale = TARGET_LONG_SIDE / max(w, h)
    img = img.resize((round(w * scale), round(h * scale)), Image.LANCZOS)

    out = 'assets/cycle_uterus.png'
    img.save(out, optimize=True)
    print('wrote %s at %dx%d' % (out, *img.size))


if __name__ == '__main__':
    if len(sys.argv) != 2:
        raise SystemExit(__doc__)
    main(sys.argv[1])
