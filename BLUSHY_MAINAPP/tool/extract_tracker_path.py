# -*- coding: utf-8 -*-
"""Traces the tracker's stroke from ptracker.jpeg, in order along the path.

    python tool/extract_tracker_path.py <path-to-ptracker.jpeg>

Writes lib/features/home/widgets/cycle_tracker_guide.dart: the stroke's
centreline as points in image space (0..1), from the path's start (the red
tip at the bottom left) to its end (the marker at the bottom centre), plus
the image's aspect ratio. The app draws that line in grey and the cycle in
red along it up to today; nothing from the source's colours is kept.

How the order is found: the stroke is thinned to a one-pixel skeleton and
walked from the start. At the two loops the skeleton crosses itself; the walk
takes the branch that best continues its current heading, which is what a
pen would do, so each loop is walked round rather than cut across.
"""
import math
import sys
from collections import deque

from PIL import Image

OUT = 'lib/features/home/widgets/cycle_tracker_guide.dart'
POINTS = 220


def stroke_mask(img):
    """1 where the pixel is stroke: anything with colour or grey, not white."""
    w, h = img.size
    px = img.convert('RGB').load()
    m = [[0] * w for _ in range(h)]
    for y in range(h):
        for x in range(w):
            r, g, b = px[x, y]
            if r > 238 and g > 238 and b > 238:
                continue
            m[y][x] = 1
    return m, w, h


def marker_centre(img):
    """The ring at the path's end: the white hole with colour around it,
    lowest on the page. Found as the white pixel farthest down that is
    enclosed by stroke within a few pixels on every side."""
    w, h = img.size
    px = img.convert('RGB').load()

    def white(x, y):
        r, g, b = px[x, y]
        return r > 238 and g > 238 and b > 238

    best = None
    for y in range(h - 1, 0, -1):
        for x in range(1, w - 1):
            if not white(x, y):
                continue
            ok = True
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                hit = False
                for k in range(1, 14):
                    xx, yy = x + dx * k, y + dy * k
                    if not (0 <= xx < w and 0 <= yy < h):
                        break
                    if not white(xx, yy):
                        hit = True
                        break
                if not hit:
                    ok = False
                    break
            if ok:
                best = (x, y)
                break
        if best:
            break
    return best


def thin(m, w, h):
    """Zhang-Suen thinning to a one-pixel skeleton."""
    def neighbours(x, y):
        return [m[y - 1][x], m[y - 1][x + 1], m[y][x + 1], m[y + 1][x + 1],
                m[y + 1][x], m[y + 1][x - 1], m[y][x - 1], m[y - 1][x - 1]]

    changed = True
    while changed:
        changed = False
        for step in (0, 1):
            remove = []
            for y in range(1, h - 1):
                for x in range(1, w - 1):
                    if not m[y][x]:
                        continue
                    p = neighbours(x, y)
                    b = sum(p)
                    if b < 2 or b > 6:
                        continue
                    a = sum(1 for i in range(8) if p[i] == 0 and p[(i + 1) % 8] == 1)
                    if a != 1:
                        continue
                    p2, p4, p6, p8 = p[0], p[2], p[4], p[6]
                    if step == 0 and (p2 * p4 * p6 or p4 * p6 * p8):
                        continue
                    if step == 1 and (p2 * p4 * p8 or p2 * p6 * p8):
                        continue
                    remove.append((x, y))
            for x, y in remove:
                m[y][x] = 0
            if remove:
                changed = True
    return m


def walk(m, w, h, start, stop):
    """Orders the skeleton from start, continuing straight through crossings."""
    on = {(x, y) for y in range(h) for x in range(w) if m[y][x]}
    visited = set()
    path = [start]
    visited.add(start)
    heading = (0.0, -1.0)
    cur = start
    while True:
        x, y = cur
        def score(c):
            vx, vy = c[0] - x, c[1] - y
            n = math.hypot(vx, vy) or 1
            return (vx / n) * heading[0] + (vy / n) * heading[1]

        def around(r, fresh):
            return [(x + dx, y + dy) for dx in range(-r, r + 1) for dy in range(-r, r + 1)
                    if (dx or dy) and (x + dx, y + dy) in on
                    and ((x + dx, y + dy) not in visited if fresh else True)
                    and (x + dx, y + dy) not in path[-12:]]

        cands = around(1, True) or around(2, True)
        if not cands:
            # Stuck on a stretch already walked (each loop crosses itself and
            # rejoins the tube). The way on is a fresh pixel branching off
            # somewhere in the last stretch: find the fresh pixel nearest to
            # any recent path pixel, and continue from there. The splice is a
            # step of a few pixels, invisible under the stroke.
            recent = path[-80:]
            best = None
            for q in on:
                if q in visited:
                    continue
                for idx in range(len(recent) - 1, -1, -1):
                    rp = recent[idx]
                    d = math.hypot(q[0] - rp[0], q[1] - rp[1])
                    if d <= 3.5:
                        key = (idx, -d)
                        if best is None or key > best[0]:
                            best = (key, q)
                        break
            if best is None:
                break
            cands = [best[1]]
        nxt = max(cands, key=score)
        visited.add(nxt)
        path.append(nxt)
        if math.hypot(nxt[0] - stop[0], nxt[1] - stop[1]) <= 28:
            break
        # heading: smoothed over the last few steps
        k = min(len(path) - 1, 8)
        hx, hy = path[-1][0] - path[-1 - k][0], path[-1][1] - path[-1 - k][1]
        n = math.hypot(hx, hy) or 1
        heading = (hx / n, hy / n)
        cur = nxt
    return path


def main(source):
    img = Image.open(source).convert('RGB')
    w, h = img.size
    ring = marker_centre(img)
    if ring is None:
        raise SystemExit('could not find the marker ring')
    m, _, _ = stroke_mask(img)
    # Cut the ring out of the mask so the walk ends at the path's end rather
    # than circling the marker.
    rx, ry = ring
    for y in range(max(0, ry - 26), min(h, ry + 26)):
        for x in range(max(0, rx - 26), min(w, rx + 26)):
            if math.hypot(x - rx, y - ry) <= 24:
                m[y][x] = 0
    m = thin(m, w, h)

    # Start: the skeleton endpoint (one neighbour) lowest on the left half,
    # which is the red tip.
    on = {(x, y) for y in range(h) for x in range(w) if m[y][x]}
    ends = []
    for (x, y) in on:
        n = sum(1 for dx in (-1, 0, 1) for dy in (-1, 0, 1)
                if (dx or dy) and (x + dx, y + dy) in on)
        if n == 1:
            ends.append((x, y))
    # The red tip: an endpoint whose source pixel is red, farthest from the
    # ring. (Cutting the ring out creates endpoints of its own beside it,
    # which is why "lowest on the left" was not enough.)
    src = img.load()

    def is_red(pt):
        r, g, b = src[pt]
        hi, lo = max(r, g, b), min(r, g, b)
        return hi > 150 and (hi - lo) / hi > 0.35 and r > g and r > b

    red_ends = [e for e in ends if is_red(e)]
    pool = red_ends or ends
    start = max(pool, key=lambda e: math.hypot(e[0] - rx, e[1] - ry))
    path = walk(m, w, h, start, ring)
    # It ends near the ring by construction; append the ring's centre so the
    # last point is the marker.
    path.append(ring)

    # Even resampling along the path length.
    dists = [0.0]
    for a, b in zip(path, path[1:]):
        dists.append(dists[-1] + math.hypot(b[0] - a[0], b[1] - a[1]))
    total = dists[-1]
    out = []
    j = 0
    for i in range(POINTS):
        t = total * i / (POINTS - 1)
        while j < len(dists) - 2 and dists[j + 1] < t:
            j += 1
        a, b = path[j], path[j + 1]
        seg = dists[j + 1] - dists[j] or 1
        f = (t - dists[j]) / seg
        out.append((a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f))

    lines = [
        "import 'package:flutter/painting.dart';",
        '',
        '// Generated by tool/extract_tracker_path.py from ptracker.jpeg.',
        '// Do not edit by hand: rerun the tool after changing the image.',
        '',
        "/// Width over height of the tracker image.",
        'const double cycleTrackerAspect = %.6f;' % (w / h),
        '',
        "/// The stroke's centreline in image space (0..1), from the path's start",
        '/// (bottom left) to its end (the marker at the bottom centre).',
        'const List<Offset> cycleTrackerGuide = [',
    ]
    for x, y in out:
        lines.append('  Offset(%.4f, %.4f),' % (x / w, y / h))
    lines.append('];')
    lines.append('')
    open(OUT, 'w', encoding='utf-8').write('\n'.join(lines))
    print('wrote %s: %d points, skeleton walk %d px, start %s, ring %s' % (OUT, len(out), len(path), start, ring))

    # A check image: the ordered path drawn back with a dark-to-light ramp,
    # so a wrong turn at a loop shows as a jump in shade.
    from PIL import ImageDraw
    dbg = img.copy().convert('RGB')
    d = ImageDraw.Draw(dbg)
    for i, (a, b) in enumerate(zip(out, out[1:])):
        v = int(255 * i / len(out))
        d.line([a, b], fill=(v, v, v), width=5)
    d.ellipse([ring[0] - 8, ring[1] - 8, ring[0] + 8, ring[1] + 8], outline=(0, 0, 0), width=3)
    dbg.save('build/tracker_trace_check.png')
    print('check image: build/tracker_trace_check.png')


if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else '../ptracker.jpeg')
