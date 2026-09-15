# -*- coding: utf-8 -*-
"""Traces the tracker's grey line exactly, in order, from assets/ptracker.png.

    python tool/trace_tracker.py

Writes lib/features/home/widgets/cycle_tracker_guide.dart: the line's centre
as ordered points in image space (0..1), from the bottom-left tip round the
whole drawing to the bottom-right tip, and a check image at
build/ptracker_check.png with the guide drawn over the line.

The line crosses itself once at each loop, which is what defeats a plain
walk along its pixels. But a drawn line is a path through a graph: thin the
stroke to one pixel, take the crossings and the two tips as nodes and the
pixel chains between them as edges, and the drawing is the trail that uses
every edge once, from tip to tip (every crossing has four arms, so such a
trail exists). At a crossing the trail continues along the arm that best
carries on its heading -- as the pen did -- rather than turning off.
"""
import math
from collections import defaultdict

from PIL import Image, ImageFilter

ASSET = 'assets/ptracker.png'
OUT = 'lib/features/home/widgets/cycle_tracker_guide.dart'
SCALE = 3
POINTS = 260


def thin(m, w, h):
    """Zhang-Suen thinning to a one-pixel skeleton."""
    def nb(x, y):
        return [m[y - 1][x], m[y - 1][x + 1], m[y][x + 1], m[y + 1][x + 1],
                m[y + 1][x], m[y + 1][x - 1], m[y][x - 1], m[y - 1][x - 1]]
    changed = True
    while changed:
        changed = False
        for step in (0, 1):
            rm = []
            for y in range(1, h - 1):
                for x in range(1, w - 1):
                    if not m[y][x]:
                        continue
                    p = nb(x, y)
                    b = sum(p)
                    if b < 2 or b > 6:
                        continue
                    a = sum(1 for i in range(8) if p[i] == 0 and p[(i + 1) % 8] == 1)
                    if a != 1:
                        continue
                    if step == 0 and (p[0] * p[2] * p[4] or p[2] * p[4] * p[6]):
                        continue
                    if step == 1 and (p[0] * p[2] * p[6] or p[0] * p[4] * p[6]):
                        continue
                    rm.append((x, y))
            for x, y in rm:
                m[y][x] = 0
            if rm:
                changed = True
    return m


def skeleton(img):
    big = img.resize((img.width * SCALE, img.height * SCALE), Image.LANCZOS)
    # Smoothed and closed before thinning. The stroke's edges are ragged
    # where the drawing was restored from its mirror, and thinning turns
    # every notch into a junction of its own; a soft, closed mask thins to
    # the one line it is.
    alpha = (big.getchannel('A')
             .filter(ImageFilter.MaxFilter(7))
             .filter(ImageFilter.MinFilter(7))
             .filter(ImageFilter.GaussianBlur(2.2)))
    w, h = alpha.size
    a = alpha.load()
    m = [[1 if a[x, y] > 110 else 0 for x in range(w)] for y in range(h)]
    fill_small_holes(m, w, h, 600)
    m = thin(m, w, h)
    on = {(x, y) for y in range(h) for x in range(w) if m[y][x]}
    return on, w, h


def fill_small_holes(m, w, h, max_area):
    """Fills enclosed gaps in the stroke smaller than max_area. The stroke's
    edges are ragged where the drawing was restored from its mirror, and
    thinning turns every little gap into a loop of its own -- dozens of
    junctions along a line that has two. The real enclosed regions (inside
    the loops, under the arch) are far larger and are left alone."""
    seen = [[0] * w for _ in range(h)]
    # Background: everything reachable from the border.
    stack = [(x, y) for x in range(w) for y in (0, h - 1)] + [(x, y) for y in range(h) for x in (0, w - 1)]
    for x, y in stack:
        seen[y][x] = 1
    while stack:
        x, y = stack.pop()
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < w and 0 <= ny < h and not seen[ny][nx] and not m[ny][nx]:
                seen[ny][nx] = 1
                stack.append((nx, ny))
    # Every other empty region is enclosed; fill the small ones.
    for y in range(h):
        for x in range(w):
            if m[y][x] or seen[y][x]:
                continue
            region = [(x, y)]
            seen[y][x] = 1
            i = 0
            while i < len(region):
                cx, cy = region[i]
                i += 1
                for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
                    if 0 <= nx < w and 0 <= ny < h and not seen[ny][nx] and not m[ny][nx]:
                        seen[ny][nx] = 1
                        region.append((nx, ny))
            if len(region) <= max_area:
                for rx, ry in region:
                    m[ry][rx] = 1


def neighbours(p, on):
    x, y = p
    return [(x + dx, y + dy) for dx in (-1, 0, 1) for dy in (-1, 0, 1)
            if (dx or dy) and (x + dx, y + dy) in on]


def build_graph(on):
    """Nodes: tips and crossings (clusters of pixels with 3+ neighbours).
    Edges: the pixel chains between them."""
    degree = {p: len(neighbours(p, on)) for p in on}
    special = {p for p, d in degree.items() if d != 2}
    # Cluster touching special pixels into one node.
    node_of = {}
    nodes = []
    for p in special:
        if p in node_of:
            continue
        stack = [p]
        node_of[p] = len(nodes)
        members = [p]
        while stack:
            q = stack.pop()
            for r in neighbours(q, on):
                if r in special and r not in node_of:
                    node_of[r] = len(nodes)
                    stack.append(r)
                    members.append(r)
        nodes.append(members)
    # Walk edges out of every node member.
    edges = []
    seen = set()
    for ni, members in enumerate(nodes):
        for m0 in members:
            for q in neighbours(m0, on):
                if q in node_of:
                    continue
                if (m0, q) in seen:
                    continue
                chain = [m0, q]
                seen.add((m0, q))
                prev, cur = m0, q
                while cur not in node_of:
                    nxt = [r for r in neighbours(cur, on) if r != prev and r not in chain[-3:]]
                    if not nxt:
                        break
                    prev, cur = cur, nxt[0]
                    chain.append(cur)
                if cur in node_of:
                    seen.add((cur, chain[-2]))
                    edges.append((ni, node_of[cur], chain))
    return nodes, edges


def merge_close_nodes(nodes, edges, radius, keep=frozenset()):
    """Thinning splits a crossing into two three-way junctions a few pixels
    apart, joined by a stub. Nodes that close are one crossing: they are
    merged, and the stub between them dropped, so the crossing has its four
    arms and the graph is Eulerian."""
    def centre(members):
        return (sum(m[0] for m in members) / len(members), sum(m[1] for m in members) / len(members))
    centres = [centre(m) for m in nodes]
    parent = list(range(len(nodes)))

    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i
    for i in range(len(nodes)):
        if i in keep:
            continue  # a tip is never merged into anything
        for j in range(i + 1, len(nodes)):
            if j in keep:
                continue
            if math.hypot(centres[i][0] - centres[j][0], centres[i][1] - centres[j][1]) <= radius:
                parent[find(i)] = find(j)
    remap = {i: find(i) for i in range(len(nodes))}
    merged = []
    for a, b, chain in edges:
        a2, b2 = remap[a], remap[b]
        # Nothing is dropped: a stub inside a merged crossing, or a bead's
        # rung, is a tiny closed circuit the trail walks and returns from in
        # a few pixels, invisible under the stroke -- while dropping it left
        # gaps that the trail bridged with straight chords.
        merged.append((a2, b2, chain))
    return merged, remap


def heading(chain, from_start, k=10):
    pts = chain[:k] if from_start else chain[::-1][:k]
    dx, dy = pts[-1][0] - pts[0][0], pts[-1][1] - pts[0][1]
    n = math.hypot(dx, dy) or 1
    return dx / n, dy / n


def prune_spurs(nodes, edges, keep, min_len):
    """Drops short edges that end at a tip: thinning leaves such spurs at
    the stroke's corners, and each one is an odd-degree node that would
    break the trail. The two real tips are kept."""
    while True:
        deg = defaultdict(int)
        for a, b, _ in edges:
            deg[a] += 1
            deg[b] += 1
        drop = None
        for i, (a, b, chain) in enumerate(edges):
            for end in (a, b):
                if end in keep:
                    continue
                if deg[end] == 1 and len(chain) < min_len:
                    drop = i
                    break
            if drop is not None:
                break
        if drop is None:
            return edges
        edges = edges[:drop] + edges[drop + 1:]


def trail(nodes, edges, start_node, end_node):
    """Hierholzer's trail from start to end. At each node the arm that best
    carries on the heading is tried first, so the order is the pen's; the
    stack completes any circuit the greedy pass leaves out, so every edge
    is used exactly once."""
    adj = defaultdict(list)
    for i, (a, b, chain) in enumerate(edges):
        adj[a].append((i, b, True))
        adj[b].append((i, a, False))
    used = set()

    def arms(node, hd, avoid_end):
        opts = [(i, nxt, fwd) for i, nxt, fwd in adj[node] if i not in used]

        def score(opt):
            i, nxt, fwd = opt
            hx, hy = heading(edges[i][2], fwd)
            sc = hx * hd[0] + hy * hd[1]
            if avoid_end and nxt == end_node and len(opts) > 1:
                sc -= 10
            return sc
        return sorted(opts, key=score, reverse=True)

    # Each stack frame: (node, heading on arrival, the chain that led here).
    stack = [(start_node, (0.0, -1.0), [])]
    order = []  # chains, in reverse trail order
    while stack:
        node, hd, chain_in = stack[-1]
        opts = arms(node, hd, True)
        if not opts:
            order.append(chain_in)
            stack.pop()
            continue
        i, nxt, fwd = opts[0]
        used.add(i)
        chain = edges[i][2] if fwd else edges[i][2][::-1]
        stack.append((nxt, heading(chain, False), chain))
    order.reverse()
    path = []
    for chain in order:
        path.extend(chain)
    return path


def bridge_gaps(path, on):
    """Joins consecutive pixels that are not neighbours by the shortest
    route along the skeleton between them. A crossing is merged from two
    junctions a few pixels apart, so the trail can leave it from a pixel it
    did not arrive at; without this, that step was a straight chord."""
    from collections import deque
    out = [path[0]]
    for q in path[1:]:
        p = out[-1]
        if max(abs(q[0] - p[0]), abs(q[1] - p[1])) <= 1:
            out.append(q)
            continue
        # BFS over the skeleton from p to q.
        prev = {p: None}
        dq = deque([p])
        found = False
        while dq and not found:
            cur = dq.popleft()
            for nb in neighbours(cur, on):
                if nb in prev:
                    continue
                prev[nb] = cur
                if nb == q:
                    found = True
                    break
                dq.append(nb)
        if not found:
            out.append(q)
            continue
        route = []
        cur = q
        while cur != p:
            route.append(cur)
            cur = prev[cur]
        out.extend(reversed(route))
    return out


def resample(path, n):
    d = [0.0]
    for a, b in zip(path, path[1:]):
        d.append(d[-1] + math.hypot(b[0] - a[0], b[1] - a[1]))
    total = d[-1]
    out = []
    j = 0
    for i in range(n):
        t = total * i / (n - 1)
        while j < len(d) - 2 and d[j + 1] < t:
            j += 1
        a, b = path[j], path[j + 1]
        seg = d[j + 1] - d[j] or 1
        f = (t - d[j]) / seg
        out.append((a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f))
    return out


def smooth(pts, k=2):
    out = []
    n = len(pts)
    for i in range(n):
        xs = [pts[max(0, min(n - 1, i + j))][0] for j in range(-k, k + 1)]
        ys = [pts[max(0, min(n - 1, i + j))][1] for j in range(-k, k + 1)]
        out.append((sum(xs) / len(xs), sum(ys) / len(ys)))
    return out


def main():
    img = Image.open(ASSET).convert('RGBA')
    on, w, h = skeleton(img)
    nodes, edges = build_graph(on)
    tips = [i for i, members in enumerate(nodes) if len(members) == 1 and len(neighbours(members[0], on)) == 1]
    if len(tips) < 2:
        raise SystemExit('expected two tips, found %d' % len(tips))
    # Start at the tip lowest on the left, end at the one lowest on the right.
    # The two real tips are the lowest ones on each side; everything else
    # of degree one is a spur from thinning.
    left = [i for i in tips if nodes[i][0][0] < w / 2]
    right = [i for i in tips if nodes[i][0][0] >= w / 2]
    start = max(left, key=lambda i: nodes[i][0][1])
    end = max(right, key=lambda i: nodes[i][0][1])
    # A crossing here is two junctions up to ~30px apart with a stub
    # between; the sides are ladders of tiny beads. Both merge into one
    # node each. The tips never merge.
    edges, remap = merge_close_nodes(nodes, edges, 32, keep={start, end})
    start, end = remap[start], remap[end]
    edges = prune_spurs(nodes, edges, {start, end}, 60)
    deg = defaultdict(int)
    for a, b, _ in edges:
        deg[a] += 1
        deg[b] += 1
    odd = [n for n, d in deg.items() if d % 2 == 1]
    print('after pruning: edges %d, odd-degree nodes %d (expect the two tips)' % (len(edges), len(odd)))
    for n in odd:
        members = nodes[n]
        cx_ = sum(m[0] for m in members) / len(members); cy_ = sum(m[1] for m in members) / len(members)
        print('   odd node %d at (%.0f, %.0f) degree %d%s' % (n, cx_, cy_, deg[n], '  <- tip' if n in (start, end) else ''))
    path = trail(nodes, edges, start, end)
    used_len = len(path)
    print('skeleton %d px, nodes %d, edges %d, trail %d px' % (len(on), len(nodes), len(edges), used_len))
    path = bridge_gaps(path, on)
    pts = resample(smooth(path), POINTS)
    norm = [(x / w, y / h) for x, y in pts]

    lines = [
        "import 'package:flutter/painting.dart';",
        '',
        '// Generated by tool/trace_tracker.py from assets/ptracker.png.',
        '// Do not edit by hand: rerun the tool after changing the image.',
        '',
        '/// Width over height of the tracker image.',
        'const double cycleTrackerAspect = %.6f;' % (img.width / img.height),
        '',
        "/// The line's centre in image space (0..1), from the bottom-left tip",
        '/// round the whole drawing to the bottom-right tip.',
        'const List<Offset> cycleTrackerGuide = [',
    ]
    for x, y in norm:
        lines.append('  Offset(%.4f, %.4f),' % (x, y))
    lines.append('];')
    lines.append('')
    open(OUT, 'w', encoding='utf-8').write('\n'.join(lines))
    print('wrote %s: %d points' % (OUT, len(norm)))

    from PIL import ImageDraw
    big = img.resize((w, h), Image.LANCZOS)
    chk = Image.new('RGBA', (w, h), (250, 246, 240, 255))
    chk.alpha_composite(big)
    d = ImageDraw.Draw(chk)
    for i, (a, b) in enumerate(zip(pts, pts[1:])):
        v = int(220 * i / len(pts))
        d.line([a, b], fill=(v, 0, 0), width=3)
    chk.convert('RGB').save('build/ptracker_check.png')
    print('check image: build/ptracker_check.png')


if __name__ == '__main__':
    main()
