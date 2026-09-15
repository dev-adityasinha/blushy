# -*- coding: utf-8 -*-
"""The tracker from ptrackernew.jpeg: cleaned of its red, and traced.

    python tool/prepare_ptracker.py <path-to-ptrackernew.jpeg>

Writes two things:

* assets/ptracker.png -- the drawing with the red segment and the ring
  removed and the grey line restored under them, on a transparent
  background. The drawing is left-right symmetric, so the grey under the red
  is taken from the mirror pixel on the right; nothing is invented.
* lib/features/home/widgets/cycle_tracker_guide.dart -- the line's centre,
  in order, from the bottom-left tip up the left side, round the left loop,
  across the top, round the right loop and down the right side to the
  bottom-right tip. The app draws the cycle in red along it up to today,
  with a ring on today.

The line crosses itself at each loop, which defeats every walk along it, so
the order is built from landmarks measured on the drawing -- the tips, the
shoulders, each loop's extremes, the arch peaks and the centre dip -- joined
by a smooth spline through them. Under a five-pixel stroke that is the line.
"""
import math
import sys

from PIL import Image

ASSET = 'assets/ptracker.png'
OUT = 'lib/features/home/widgets/cycle_tracker_guide.dart'
SCALE = 3
POINTS = 240


def is_red(rgb):
    r, g, b = rgb
    hi, lo = max(rgb), min(rgb)
    return hi > 140 and (hi - lo) / hi > 0.30 and r > g and r > b


def is_ink(rgb):
    return not (rgb[0] > 236 and rgb[1] > 236 and rgb[2] > 236)


def clean(img):
    """Red and ring replaced by the mirror pixel; white made transparent."""
    w, h = img.size
    src = img.convert('RGB').load()
    out = Image.new('RGBA', img.size, (0, 0, 0, 0))
    dst = out.load()
    redset = set()
    for y in range(h):
        for x in range(w):
            if is_red(src[x, y]):
                for dx in range(-4, 5):
                    for dy in range(-4, 5):
                        redset.add((x + dx, y + dy))
    for y in range(h):
        for x in range(w):
            sx = w - 1 - x if (x, y) in redset else x
            rgb = src[sx, y]
            if is_ink(rgb) and not is_red(rgb):
                dst[x, y] = (rgb[0], rgb[1], rgb[2], 255)
    return out


def landmarks(cleaned):
    big = cleaned.resize((cleaned.width * SCALE, cleaned.height * SCALE), Image.LANCZOS)
    w, h = big.size
    px = big.load()
    ink = {(x, y) for y in range(h) for x in range(w) if px[x, y][3] > 40}
    cx = w / 2

    def lowest(pred):
        return max((p for p in ink if pred(p)), key=lambda p: p[1])

    def highest(pred):
        return min((p for p in ink if pred(p)), key=lambda p: p[1])

    # Tips: the lowest ink on each side of the centre, taken at the middle of
    # the stroke's width there.
    def tip(left):
        row = lowest(lambda p: p[0] < cx if left else p[0] > cx)
        xs = [p[0] for p in ink if p[1] == row[1] and ((p[0] < cx) if left else (p[0] > cx))]
        return (sum(xs) / len(xs), row[1])

    tip_l, tip_r = tip(True), tip(False)

    # Loops: the leftmost and rightmost ink, and around each, the loop's box.
    leftmost = min(ink, key=lambda p: p[0])
    rightmost = max(ink, key=lambda p: p[0])

    def loop_box(anchor, left):
        # The loop is the ink within a band of columns from the extreme.
        span = w * 0.16
        pts = [p for p in ink if (p[0] < anchor[0] + span if left else p[0] > anchor[0] - span)]
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        return min(xs), min(ys), max(xs), max(ys)

    lb = loop_box(leftmost, True)
    rb = loop_box(rightmost, False)

    # The top arch: the highest ink per column across the middle.
    def top_at(x):
        ys = [p[1] for p in ink if p[0] == int(x)]
        return min(ys) if ys else None

    # Centre dip: the lowest point of the top edge near the centre.
    dip_x = max(range(int(cx - w * 0.06), int(cx + w * 0.06)), key=lambda x: top_at(x) or -1)
    dip = (dip_x, top_at(dip_x) + SCALE * 2.5)
    # Arch peaks: the highest point of the top edge on each side.
    peak_l_x = min(range(int(w * 0.22), int(cx - w * 0.06)), key=lambda x: top_at(x) or 1e9)
    peak_r_x = min(range(int(cx + w * 0.06), int(w * 0.78)), key=lambda x: top_at(x) or 1e9)
    peak_l = (peak_l_x, top_at(peak_l_x) + SCALE * 2.5)
    peak_r = (peak_r_x, top_at(peak_r_x) + SCALE * 2.5)

    # Shoulders: where each side reaches the top -- the highest ink in the
    # column band just inside each loop box, taken at the stroke's centre.
    sh_l_x = lb[2] + w * 0.03
    sh_r_x = rb[0] - w * 0.03
    sh_l = (sh_l_x, top_at(sh_l_x) + SCALE * 2.5)
    sh_r = (sh_r_x, top_at(sh_r_x) + SCALE * 2.5)

    # Mid-side points: on each side, halfway between tip and shoulder in y,
    # at the stroke's centre.
    def side_mid(tip, shoulder, left):
        y = int((tip[1] + shoulder[1]) / 2)
        xs = [p[0] for p in ink if p[1] == y and ((p[0] < cx) if left else (p[0] > cx))]
        # the side is the run nearest the centre
        xs = sorted(xs, reverse=left)
        run = [xs[0]]
        for x in xs[1:]:
            if abs(x - run[-1]) <= 2:
                run.append(x)
            else:
                break
        return (sum(run) / len(run), y)

    mid_l = side_mid(tip_l, sh_l, True)
    mid_r = side_mid(tip_r, sh_r, False)

    # Loop points, at the stroke's centre: bottom, outer, top (the loop's
    # own top, under the tube), and the crossing near the shoulder.
    inset = SCALE * 2.5

    def loop_pts(box, left):
        x0, y0, x1, y1 = box
        bottom = ((x0 + x1) / 2, y1 - inset)
        outer = ((x0 + inset) if left else (x1 - inset), (y0 + y1) / 2)
        top = ((x0 + x1) / 2, y0 + inset + SCALE * 4)
        return bottom, outer, top

    lb_bottom, lb_outer, lb_top = loop_pts(lb, True)
    rb_bottom, rb_outer, rb_top = loop_pts(rb, False)

    # The path, in order. The tube leaves the shoulder outward and down into
    # the loop's bottom, round the outside, up over the loop's top, and back
    # in over the crossing to the arch peak.
    left_tube_mid = ((sh_l[0] + lb_bottom[0]) / 2, (sh_l[1] + lb_bottom[1]) / 2 + SCALE * 3)
    right_tube_mid = ((sh_r[0] + rb_bottom[0]) / 2, (sh_r[1] + rb_bottom[1]) / 2 + SCALE * 3)
    path = [
        tip_l, mid_l, sh_l, left_tube_mid, lb_bottom, lb_outer, lb_top,
        (sh_l[0] + SCALE * 2, sh_l[1] + SCALE * 4), peak_l, dip, peak_r,
        (sh_r[0] - SCALE * 2, sh_r[1] + SCALE * 4), rb_top, rb_outer, rb_bottom,
        right_tube_mid, sh_r, mid_r, tip_r,
    ]
    return [(x / w, y / h) for x, y in path], big


def catmull_rom(points, per_segment):
    out = []
    n = len(points)
    for i in range(n - 1):
        p0 = points[max(i - 1, 0)]
        p1 = points[i]
        p2 = points[i + 1]
        p3 = points[min(i + 2, n - 1)]
        for k in range(per_segment):
            t = k / per_segment
            t2, t3 = t * t, t * t * t
            x = 0.5 * ((2 * p1[0]) + (-p0[0] + p2[0]) * t + (2 * p0[0] - 5 * p1[0] + 4 * p2[0] - p3[0]) * t2 + (-p0[0] + 3 * p1[0] - 3 * p2[0] + p3[0]) * t3)
            y = 0.5 * ((2 * p1[1]) + (-p0[1] + p2[1]) * t + (2 * p0[1] - 5 * p1[1] + 4 * p2[1] - p3[1]) * t2 + (-p0[1] + 3 * p1[1] - 3 * p2[1] + p3[1]) * t3)
            out.append((x, y))
    out.append(points[-1])
    return out


def resample(path, n):
    dists = [0.0]
    for a, b in zip(path, path[1:]):
        dists.append(dists[-1] + math.hypot(b[0] - a[0], b[1] - a[1]))
    total = dists[-1]
    out = []
    j = 0
    for i in range(n):
        t = total * i / (n - 1)
        while j < len(dists) - 2 and dists[j + 1] < t:
            j += 1
        a, b = path[j], path[j + 1]
        seg = dists[j + 1] - dists[j] or 1
        f = (t - dists[j]) / seg
        out.append((a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f))
    return out


def main(source):
    img = Image.open(source)
    cleaned = clean(img)
    cleaned.save(ASSET)
    print('wrote %s (%dx%d)' % (ASSET, cleaned.width, cleaned.height))

    anchors, big = landmarks(cleaned)
    pts = resample(catmull_rom(anchors, 24), POINTS)
    lines = [
        "import 'package:flutter/painting.dart';",
        '',
        '// Generated by tool/prepare_ptracker.py from ptrackernew.jpeg.',
        '// Do not edit by hand: rerun the tool after changing the image.',
        '',
        '/// Width over height of the tracker image.',
        'const double cycleTrackerAspect = %.6f;' % (cleaned.width / cleaned.height),
        '',
        "/// The line's centre in image space (0..1), from the bottom-left tip",
        '/// round the whole drawing to the bottom-right tip.',
        'const List<Offset> cycleTrackerGuide = [',
    ]
    for x, y in pts:
        lines.append('  Offset(%.4f, %.4f),' % (x, y))
    lines.append('];')
    lines.append('')
    open(OUT, 'w', encoding='utf-8').write('\n'.join(lines))
    print('wrote %s: %d points from %d landmarks' % (OUT, len(pts), len(anchors)))

    from PIL import ImageDraw
    chk = Image.new('RGBA', big.size, (250, 246, 240, 255))
    chk.alpha_composite(big)
    d = ImageDraw.Draw(chk)
    for i, (a, b) in enumerate(zip(pts, pts[1:])):
        v = int(220 * i / len(pts))
        d.line([(a[0] * big.width, a[1] * big.height), (b[0] * big.width, b[1] * big.height)],
               fill=(v, 0, 0), width=3)
    for x, y in anchors:
        d.ellipse([x * big.width - 4, y * big.height - 4, x * big.width + 4, y * big.height + 4], outline=(0, 90, 200), width=2)
    chk.convert('RGB').save('build/ptracker_check.png')
    print('check image: build/ptracker_check.png')


if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else '../ptrackernew.jpeg')
