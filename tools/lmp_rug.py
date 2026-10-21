"""Table 05 (The Lamplight) M9 round 1b: the rug between the slingshots, an original rug in the style Aaron picked
(a worn tribal/Persian-style rug: navy field, rust, terracotta, cream and brown, a stepped hooked medallion with two
pendants, key-shaped corner motifs, a dark border of cream rosettes, distressed pile, fringe at the ends).
draw_rug(cr, x0, y0, w, h, seed) paints it into a pycairo context in world points, y up (y0 = the rug's bottom)."""
import math, random

NAVY = (0.12, 0.16, 0.29)
NAVY_L = (0.24, 0.29, 0.42)
RUST = (0.62, 0.30, 0.16)
TERRA = (0.80, 0.50, 0.33)
CREAM = (0.90, 0.82, 0.65)
TAN = (0.70, 0.54, 0.36)
BROWN = (0.28, 0.17, 0.09)
DARK = (0.17, 0.10, 0.06)
RED = (0.50, 0.14, 0.09)
BLUE = (0.30, 0.38, 0.55)


def draw_rug(cr, x0, y0, w, h, seed=7):
    rnd = random.Random(seed)
    cx, cy = x0 + w / 2, y0 + h / 2

    def rgb(c, a=1.0):
        cr.set_source_rgba(c[0], c[1], c[2], a)

    def poly(pts, c, a=1.0):
        cr.move_to(*pts[0])
        for p in pts[1:]:
            cr.line_to(*p)
        cr.close_path(); rgb(c, a); cr.fill()

    def rect(x, y, ww, hh, c, a=1.0):
        rgb(c, a); cr.rectangle(x, y, ww, hh); cr.fill()

    def mirror4(fn):
        """Calls fn(sx, sy) for the four quadrants (sx, sy = ±1) about the rug's centre."""
        for sx in (1, -1):
            for sy in (1, -1):
                fn(sx, sy)

    def stepped_diamond(px, py, rx, ry, steps, c):
        """A diamond with stepped (knotted) edges."""
        pts = []
        for i in range(steps + 1):
            t = i / steps
            pts += [(px + rx * t, py + ry * (1 - t)), (px + rx * t, py + ry * (1 - t) - ry / steps)] if i < steps else [(px + rx, py)]
        quarter = pts
        full = quarter + [(2 * px - x, y) for x, y in reversed(quarter)][1:]
        full = [(x, y) for x, y in full]
        lower = [(x, 2 * py - y) for x, y in reversed(full)]
        poly(full + lower, c)

    def rosette(px, py, r, petal, center):
        """An eight-petal rosette in an octagon (the border's repeating flower)."""
        oct_ = [(px + r * math.cos(a), py + r * 0.82 * math.sin(a)) for a in [i * math.pi / 4 + math.pi / 8 for i in range(8)]]
        poly(oct_, CREAM)
        for i in range(8):
            a = i * math.pi / 4
            cr.save(); cr.translate(px, py); cr.rotate(a); cr.scale(1, 0.82)
            poly([(r * 0.18, 0), (r * 0.62, r * 0.14), (r * 0.78, 0), (r * 0.62, -r * 0.14)], petal)
            cr.restore()
        rgb(center); cr.arc(px, py, r * 0.2, 0, 2 * math.pi); cr.fill()

    def hooks(points, c, size, outward):
        """Latch hooks: small curled teeth along a list of (x, y, dir) points."""
        for (hx, hy, dx, dy) in points:
            nx, ny = dx * outward, dy * outward
            cr.save(); cr.translate(hx, hy)
            rgb(c); cr.set_line_width(size * 0.45)
            cr.move_to(0, 0); cr.line_to(nx * size, ny * size)
            cr.line_to(nx * size - ny * size * 0.7, ny * size + nx * size * 0.7)
            cr.stroke(); cr.restore()

    # ---- fringe at the two ends
    for end, yy in ((1, y0 + h), (-1, y0)):
        x = x0 + 4
        while x < x0 + w - 4:
            rgb(CREAM, 0.95); cr.set_line_width(0.9)
            cr.move_to(x, yy); cr.line_to(x + rnd.uniform(-1, 1), yy + end * rnd.uniform(6, 10)); cr.stroke()
            x += 2.4
    # ---- shadow and the dark outer edge
    for i in range(5):
        rgb((0.08, 0.03, 0.01), 0.08); cr.rectangle(x0 - 2 + i * 0.5, y0 - 3 + i * 0.5, w + 4 - i, h + 4 - i); cr.fill()
    rect(x0, y0, w, h, NAVY)

    # ---- main border: dark brown with cream rosettes and rust lozenges between, a rust wave inside it
    B = 30
    rect(x0 + 4, y0 + 4, w - 8, h - 8, BROWN)
    # rosettes round the border
    def border_run(ax, ay, bx, by, n):
        for i in range(n):
            t = (i + 0.5) / n
            px, py = ax + (bx - ax) * t, ay + (by - ay) * t
            rosette(px, py, 9.5, TERRA, RED)
            if i < n - 1:
                t2 = (i + 1) / n
                qx, qy = ax + (bx - ax) * t2, ay + (by - ay) * t2
                stepped_diamond(qx, qy, 3.2, 5, 3, RUST)
                rgb(BLUE); cr.arc(qx, qy, 1.2, 0, 2 * math.pi); cr.fill()
    mid = 4 + (B - 4) / 2
    border_run(x0 + mid, y0 + mid, x0 + mid, y0 + h - mid, 12)            # left
    border_run(x0 + w - mid, y0 + mid, x0 + w - mid, y0 + h - mid, 12)    # right
    border_run(x0 + mid + 22, y0 + mid, x0 + w - mid - 22, y0 + mid, 7)   # bottom
    border_run(x0 + mid + 22, y0 + h - mid, x0 + w - mid - 22, y0 + h - mid, 7)   # top
    # navy dots sprinkled in the border
    for i in range(220):
        side = rnd.randrange(4)
        if side < 2:
            px = x0 + (rnd.uniform(5, B - 2) if side == 0 else w - rnd.uniform(5, B - 2)); py = y0 + rnd.uniform(5, h - 5)
        else:
            py = y0 + (rnd.uniform(5, B - 2) if side == 2 else h - rnd.uniform(5, B - 2)); px = x0 + rnd.uniform(5, w - 5)
        rect(px, py, 1.4, 1.4, BLUE, 0.7)
    # guard stripes: cream line, rust running wave, cream line
    G0 = B
    rect(x0 + G0, y0 + G0, w - 2 * G0, h - 2 * G0, CREAM)
    rect(x0 + G0 + 1.5, y0 + G0 + 1.5, w - 2 * G0 - 3, h - 2 * G0 - 3, RUST)
    # the wave: zigzag cream line inside the rust band
    rgb(CREAM); cr.set_line_width(1.0)
    gx0, gy0, gx1, gy1 = x0 + G0 + 4, y0 + G0 + 4, x0 + w - G0 - 4, y0 + h - G0 - 4
    for (ax, ay, bx, by) in ((gx0, gy0, gx1, gy0), (gx1, gy0, gx1, gy1), (gx1, gy1, gx0, gy1), (gx0, gy1, gx0, gy0)):
        ln = math.hypot(bx - ax, by - ay); n = int(ln / 6)
        ux, uy = (bx - ax) / ln, (by - ay) / ln
        cr.move_to(ax, ay)
        for k in range(1, n + 1):
            off = 1.6 if k % 2 else -1.6
            cr.line_to(ax + ux * ln * k / n - uy * off, ay + uy * ln * k / n + ux * off)
        cr.stroke()
    F = G0 + 8
    fx0, fy0, fw, fh = x0 + F, y0 + F, w - 2 * F, h - 2 * F
    rect(fx0, fy0, fw, fh, NAVY)

    # ---- field: corner keys (stepped L hooks in terracotta), small scattered motifs
    def corner_key(sx, sy):
        """A stepped key/hook motif in the field's corner, pointing inward."""
        cr.save(); cr.translate(cx + sx * fw / 2, cy + sy * fh / 2); cr.scale(-sx, -sy)
        u = 5.0
        cells = [(0, 0), (1, 0), (2, 0), (3, 0), (0, 1), (0, 2), (0, 3), (2, 2), (3, 2), (2, 3), (4, 4), (5, 4), (4, 5)]
        for (i, j) in cells:
            rect(i * u + 2, j * u + 2, u, u, TERRA if (i + j) % 3 else CREAM)
        # a small boteh beside it
        cr.translate(38, 14)
        rgb(CREAM); cr.arc(0, 0, 4.5, 0, 2 * math.pi); cr.fill()
        poly([(-3, 2.5), (5, 9), (2, 1)], CREAM)
        rgb(RUST); cr.arc(0, 0, 2.2, 0, 2 * math.pi); cr.fill()
        cr.restore()
    mirror4(corner_key)

    # ---- field fill: small stepped crosses and florals scattered (kept off the medallion and pendants), comb rows
    def small_cross(px, py, c1, c2):
        for (i, j) in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)):
            rect(px + i * 2.4 - 1.2, py + j * 2.4 - 1.2, 2.4, 2.4, c1 if (i, j) != (0, 0) else c2)
    placed = 0
    tries = 0
    while placed < 46 and tries < 2000:
        tries += 1
        px, py = fx0 + rnd.uniform(8, fw - 8), fy0 + rnd.uniform(8, fh - 8)
        dx, dy = abs(px - cx), abs(py - cy)
        if dx < fw * 0.40 and dy < fh * 0.42 and (dx < 26 or dy < fh * 0.20): continue   # medallion, pendants, stems
        if dx < fw * 0.40 and abs(dy - (fh * 0.15 + 46)) < 16: continue                  # the pendant bars
        if dx > fw / 2 - 40 and dy > fh / 2 - 40: continue                               # corner keys
        small_cross(px, py, rnd.choice([TERRA, CREAM, RED, BLUE]), rnd.choice([CREAM, RUST, NAVY_L]))
        placed += 1
    for sx in (1, -1):                       # comb rows beside the medallion, teeth pointing outward
        for j in range(-3, 4):
            by_ = cy + j * 9
            bx_ = cx + sx * (fw * 0.42)
            rect(min(bx_, bx_ + sx * 12), by_ - 1, 12, 2, TERRA)
            for t in range(4):
                rect(bx_ + sx * (2 + t * 3) - 0.6, by_ + 1, 1.2, 3.2, TERRA)

    # ---- central medallion: a stepped hexagon, rust outlined in cream with latch hooks, brown centre, four rosettes
    MW, MH = fw * 0.62, fh * 0.30
    def hexagon(rw, rh, steps):
        """A stepped hexagon about the centre: flat top and bottom (half-width 0.55 rw), points at (±rw, 0)."""
        q = []                                   # upper-right quarter, from the top edge down to the right point
        for i in range(steps):
            x_a = rw * 0.55 + rw * 0.45 * i / steps
            x_b = rw * 0.55 + rw * 0.45 * (i + 1) / steps
            y_a = rh * (1 - i / steps)
            q += [(x_a, y_a), (x_b, y_a)]
        q.append((rw, 0))
        right = q + [(x, -y) for x, y in reversed(q)][1:]          # top-right → right point → bottom-right
        full = right + [(-x, y) for x, y in reversed(right)]        # then bottom-left → left point → top-left
        return [(cx + x, cy + y) for x, y in full]
    poly(hexagon(MW / 2 + 6, MH / 2 + 10, 6), CREAM)
    edge = hexagon(MW / 2 + 6, MH / 2 + 10, 6)
    for (ax, ay), (bx, by) in zip(edge, edge[1:] + edge[:1]):      # little cream teeth all round (the jagged edge)
        ln = math.hypot(bx - ax, by - ay)
        if ln < 1: continue
        nx_, ny_ = -(by - ay) / ln, (bx - ax) / ln                     # outward normal
        n = max(1, int(ln / 5))
        for k in range(n):
            t0, t1 = k / n, (k + 0.5) / n
            p0 = (ax + (bx - ax) * t0, ay + (by - ay) * t0); p1 = (ax + (bx - ax) * t1, ay + (by - ay) * t1)
            poly([p0, p1, ((p0[0] + p1[0]) / 2 + nx_ * 3, (p0[1] + p1[1]) / 2 + ny_ * 3)], CREAM)
    poly(hexagon(MW / 2 + 3, MH / 2 + 7, 6), TERRA)
    poly(hexagon(MW / 2, MH / 2 + 4, 6), RUST)
    poly(hexagon(MW / 2 - 8, MH / 2 - 4, 6), BROWN)
    cr.save(); cr.new_path()
    for x_, y_ in hexagon(MW / 2 - 8, MH / 2 - 4, 6)[:1]: cr.move_to(x_, y_)
    for x_, y_ in hexagon(MW / 2 - 8, MH / 2 - 4, 6)[1:]: cr.line_to(x_, y_)
    cr.close_path(); cr.clip()
    for gx in range(-12, 13):
        for gy in range(-8, 9):
            if (gx + gy) % 2: continue
            rect(cx + gx * 6 - 0.8, cy + gy * 6 - 0.8, 1.6, 1.6, TAN, 0.6)
    cr.restore()
    # latch hooks round the medallion's top and bottom
    pts = []
    for k in range(-6, 7):
        x = cx + k * (MW / 13)
        pts.append((x, cy + MH / 2 + 10, 0, 1)); pts.append((x, cy - MH / 2 - 10, 0, -1))
    hooks(pts, CREAM, 3.2, 1)
    # side bars of little cream lozenges (the "spine" rows)
    for sx in (1, -1):
        for j in range(-5, 6):
            stepped_diamond(cx + sx * (MW / 2 - 3), cy + j * 6.5, 2.2, 2.6, 2, CREAM)
    for sx in (1, -1):
        for sy in (1, -1):
            rosette(cx + sx * MW * 0.2, cy + sy * MH * 0.22, 8, TAN, BROWN)
    # centre: a small navy cross with a cream outline
    stepped_diamond(cx, cy, 14, 9, 4, CREAM)
    stepped_diamond(cx, cy, 11, 7, 4, NAVY)
    stepped_diamond(cx, cy, 4, 3, 2, TERRA)

    # ---- pendants above and below: a stepped diamond on a hooked horizontal bar, and a small diamond beyond
    for sy in (1, -1):
        py = cy + sy * (MH / 2 + 46)
        bar = [(cx - fw * 0.36, py - 3), (cx + fw * 0.36, py - 3), (cx + fw * 0.36, py + 3), (cx - fw * 0.36, py + 3)]
        poly(bar, TERRA)
        hooks([(cx + k * 9, py + sy * 3, 0, sy) for k in range(-6, 7)], RUST, 3, 1)
        for ex in (1, -1):
            stepped_diamond(cx + ex * fw * 0.36, py, 6, 5, 3, CREAM)
        stepped_diamond(cx, py, 22, 14, 5, CREAM)
        stepped_diamond(cx, py, 18, 11, 5, RUST)
        stepped_diamond(cx, py, 8, 6, 3, CREAM)
        # the stem joining the medallion and the far tip diamond
        rect(cx - 2, min(py, cy + sy * (MH / 2 + 10)) if sy > 0 else py, 4, abs(py - (cy + sy * (MH / 2 + 10))), TERRA)
        tip = cy + sy * (MH / 2 + 76)
        stepped_diamond(cx, tip, 9, 8, 3, TERRA)
        stepped_diamond(cx, tip, 4, 4, 2, CREAM)
        # small arrow motifs either side of the pendant
        for ex in (1, -1):
            stepped_diamond(cx + ex * fw * 0.24, cy + sy * (MH / 2 + 22), 5, 4, 2, RED)

    # ---- wear: mottled navy, faded patches and pile speckle over the whole rug
    yy = y0
    while yy < y0 + h:                      # abrash: soft horizontal bands where the dye lot changed
        bh = rnd.uniform(6, 26)
        rect(x0, yy, w, bh, (1, 1, 1) if rnd.random() < 0.5 else (0, 0, 0), rnd.uniform(0.0, 0.05))
        yy += bh
    for i in range(110):
        px, py = x0 + rnd.uniform(0, w), y0 + rnd.uniform(0, h)
        r = rnd.uniform(8, 30)
        g = __import__('cairo').RadialGradient(px, py, 0, px, py, r)
        g.add_color_stop_rgba(0, *NAVY_L, 0.26); g.add_color_stop_rgba(1, *NAVY_L, 0)
        cr.set_source(g); cr.arc(px, py, r, 0, 2 * math.pi); cr.fill()
    for i in range(16000):
        px, py = x0 + rnd.uniform(0, w), y0 + rnd.uniform(0, h)
        light = rnd.random() < 0.55
        rgb((0.95, 0.92, 0.86) if light else (0.05, 0.03, 0.02), rnd.uniform(0.05, 0.16))
        cr.rectangle(px, py, rnd.uniform(0.5, 1.4), 0.6); cr.fill()
