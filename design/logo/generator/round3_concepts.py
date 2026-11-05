#!/usr/bin/env python3
"""30 different J-muscle logo concepts for Jimmy, rendered in the cel-shade + shine style.

Most shapes are built as smooth unions of signed-distance primitives (circles, capsules, arcs,
rounded boxes) with a controllable fillet/blend (small = crisp geometric joins, large = gooey
bubbles), contoured with marching squares, smoothed, and emitted as one SVG path. A few are
explicit polygons (angular) or come from the brush-spine generator in shapes.py.
"""
import math, html, os
import numpy as np
from collections import defaultdict
from brush import Arm

HERE = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.join(HERE, "..", "rounds", "round-3-concepts")
OUT = os.path.join(OUT_DIR, "index.html")

BG, Y, Y_D, Y_DD, CREAM = "#0A0A0D", "#FFB84D", "#E58F1C", "#8A4F06", "#FFF6E0"
GLOVE, GLOVE_D = "#FFF3DA", "#E6D3AE"

# ---------------------------------------------------------------- field
H = 3
N = 1024 // H + 1
_ax = np.arange(N, dtype=float) * H
X, Y_ = np.meshgrid(_ax, _ax)           # X[j, i] = i*H ; Y_[j, i] = j*H


def circle(cx, cy, r):
    return np.hypot(X - cx, Y_ - cy) - r


def capsule(x1, y1, x2, y2, r):
    px, py = X - x1, Y_ - y1
    bx, by = x2 - x1, y2 - y1
    h = np.clip((px * bx + py * by) / (bx * bx + by * by), 0, 1)
    return np.hypot(px - bx * h, py - by * h) - r


def arc(cx, cy, R, a0, a1, r):
    """Tube of radius r along a circular arc of radius R from angle a0 to a1 (degrees, screen
    coordinates: 0 = right, 90 = down, 180 = left). Round ends."""
    dx, dy = X - cx, Y_ - cy
    ang = np.degrees(np.arctan2(dy, dx)) % 360
    on = (ang >= a0) & (ang <= a1)
    d_curve = np.abs(np.hypot(dx, dy) - R)
    e0 = (cx + R * math.cos(math.radians(a0)), cy + R * math.sin(math.radians(a0)))
    e1 = (cx + R * math.cos(math.radians(a1)), cy + R * math.sin(math.radians(a1)))
    d_end = np.minimum(np.hypot(X - e0[0], Y_ - e0[1]), np.hypot(X - e1[0], Y_ - e1[1]))
    return np.where(on, d_curve, d_end) - r


def box(cx, cy, hx, hy, r):
    qx = np.abs(X - cx) - hx + r
    qy = np.abs(Y_ - cy) - hy + r
    return np.hypot(np.maximum(qx, 0), np.maximum(qy, 0)) + np.minimum(np.maximum(qx, qy), 0) - r


def plane(px, py, nx, ny):
    """Half-space: negative (inside) where (p - p0) . n < 0."""
    return (X - px) * nx + (Y_ - py) * ny


def smin(a, b, k):
    if k <= 0:
        return np.minimum(a, b)
    h = np.clip(0.5 + 0.5 * (b - a) / k, 0, 1)
    return b * (1 - h) + a * h - k * h * (1 - h)


def smax(a, b, k):
    return -smin(-a, -b, k)


class Field:
    def __init__(self, k=30):
        self.f, self.k = None, k

    def add(self, d, k=None):
        self.f = d if self.f is None else smin(self.f, d, self.k if k is None else k)
        return self

    def cut(self, d, k=None):
        self.f = smax(self.f, -d, self.k if k is None else k)
        return self

    def keep(self, d, k=None):     # intersect
        self.f = smax(self.f, d, self.k if k is None else k)
        return self


# ---------------------------------------------------------------- contouring
_TABLE = {1: [(3, 2)], 2: [(1, 2)], 3: [(3, 1)], 4: [(0, 1)], 6: [(0, 2)], 7: [(0, 3)], 8: [(0, 3)],
          9: [(0, 2)], 11: [(0, 1)], 12: [(3, 1)], 13: [(1, 2)], 14: [(3, 2)]}


def contours(F):
    inside = F < 0
    a, b, c, d = inside[:-1, :-1], inside[:-1, 1:], inside[1:, 1:], inside[1:, :-1]
    case = a.astype(int) * 8 + b.astype(int) * 4 + c.astype(int) * 2 + d.astype(int)
    cells = np.argwhere((case != 0) & (case != 15))
    pts, adj = {}, defaultdict(list)

    def edge(i, j, e):
        if e == 0:
            key, n1, n2 = ('h', i, j), (j, i), (j, i + 1)
        elif e == 1:
            key, n1, n2 = ('v', i + 1, j), (j, i + 1), (j + 1, i + 1)
        elif e == 2:
            key, n1, n2 = ('h', i, j + 1), (j + 1, i), (j + 1, i + 1)
        else:
            key, n1, n2 = ('v', i, j), (j, i), (j + 1, i)
        if key not in pts:
            f1, f2 = F[n1], F[n2]
            t = f1 / (f1 - f2)
            pts[key] = (n1[1] * H + (n2[1] - n1[1]) * H * t, n1[0] * H + (n2[0] - n1[0]) * H * t)
        return key

    for j, i in cells:
        cs = int(case[j, i])
        if cs in (5, 10):
            centre_inside = (F[j, i] + F[j, i + 1] + F[j + 1, i + 1] + F[j + 1, i]) < 0
            if cs == 5:
                segs = [(3, 0), (1, 2)] if centre_inside else [(0, 1), (3, 2)]
            else:
                segs = [(0, 1), (3, 2)] if centre_inside else [(0, 3), (1, 2)]
        else:
            segs = _TABLE[cs]
        for e1, e2 in segs:
            k1, k2 = edge(i, j, e1), edge(i, j, e2)
            adj[k1].append(k2); adj[k2].append(k1)
    loops, seen = [], set()
    for start in list(adj):
        if start in seen:
            continue
        loop, prev, cur = [start], None, start
        seen.add(start)
        while True:
            nxt = [n for n in adj[cur] if n != prev]
            if not nxt or nxt[0] == start or nxt[0] in seen:
                break
            loop.append(nxt[0]); seen.add(nxt[0]); prev, cur = cur, nxt[0]
        if len(loop) > 12:
            loops.append([pts[k] for k in loop])
    return loops


def chaikin(pts, n=2):
    for _ in range(n):
        out = []
        for i in range(len(pts)):
            p, q = pts[i], pts[(i + 1) % len(pts)]
            out.append((0.75 * p[0] + 0.25 * q[0], 0.75 * p[1] + 0.25 * q[1]))
            out.append((0.25 * p[0] + 0.75 * q[0], 0.25 * p[1] + 0.75 * q[1]))
        pts = out
    return pts


def rdp(pts, eps=0.5):
    if len(pts) < 3:
        return pts
    (x1, y1), (x2, y2) = pts[0], pts[-1]
    dx, dy = x2 - x1, y2 - y1
    L = math.hypot(dx, dy) or 1e-9
    dmax, idx = 0, 0
    for i in range(1, len(pts) - 1):
        d = abs(dy * pts[i][0] - dx * pts[i][1] + x2 * y1 - y2 * x1) / L
        if d > dmax:
            dmax, idx = d, i
    if dmax > eps:
        return rdp(pts[:idx + 1], eps)[:-1] + rdp(pts[idx:], eps)
    return [pts[0], pts[-1]]


def rdp_closed(pts, eps=0.45):
    """RDP on a closed loop: split at the point farthest from the start so neither half is degenerate."""
    x0, y0 = pts[0]
    m = max(range(len(pts)), key=lambda i: (pts[i][0] - x0) ** 2 + (pts[i][1] - y0) ** 2)
    first = rdp(pts[: m + 1], eps)
    second = rdp(pts[m:] + [pts[0]], eps)
    return first[:-1] + second[:-1]


def field_path(F, smooth=2):
    ds = []
    for loop in contours(F):
        pts = chaikin(loop, smooth) if smooth else loop
        pts = rdp_closed(pts)
        ds.append("M " + " L ".join(f"{x:.1f} {y:.1f}" for x, y in pts) + " Z")
    return " ".join(ds)


def poly_path(pts):
    return "M " + " L ".join(f"{x:.1f} {y:.1f}" for x, y in pts) + " Z"


# ---------------------------------------------------------------- rendering
_uid = [0]


def uid():
    _uid[0] += 1
    return f"c{_uid[0]}"


def cel_layer(d, base=Y, shade=Y_D, off=22):
    i = uid()
    return (f'<clipPath id="{i}"><path d="{d}"/></clipPath><path d="{d}" fill="{shade}" fill-rule="evenodd"/>'
            f'<g clip-path="url(#{i})"><path d="{d}" fill="{base}" fill-rule="evenodd" transform="translate(-{off} -{off})"/></g>')


def shine(cx, cy, rx, ry, ang=-30, col=CREAM):
    return f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" transform="rotate({ang} {cx} {cy})" fill="{col}"/>'


class Concept:
    def __init__(self, cid, group, title, note):
        self.cid, self.group, self.title, self.note = cid, group, title, note
        self.layers, self.shines, self.before, self.after, self.transform = [], [], "", "", ""

    def layer(self, d, base=Y, shade=Y_D):
        self.layers.append((d, base, shade)); return self

    def hi(self, *args, **kw):
        self.shines.append(shine(*args, **kw)); return self

    def body(self):
        return self.before + "".join(cel_layer(d, b, s) for d, b, s in self.layers) + "".join(self.shines) + self.after

    def symbol(self):
        t = f' transform="{self.transform}"' if self.transform else ""
        return (f'<symbol id="{self.cid}" viewBox="0 0 1024 1024"><rect width="1024" height="1024" fill="{BG}"/>'
                f'<g{t}>{self.body()}</g></symbol>')

    def standalone(self):
        """A self-contained 1024 px SVG of this mark on its black tile."""
        t = f' transform="{self.transform}"' if self.transform else ""
        return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">'
                f'<rect width="1024" height="1024" fill="{BG}"/><g{t}>{self.body()}</g></svg>\n')


def write_svgs(concepts, out_dir):
    d = os.path.join(out_dir, "svg")
    os.makedirs(d, exist_ok=True)
    for c in concepts:
        with open(os.path.join(d, f"{c.cid}.svg"), "w") as f:
            f.write(c.standalone())


# ---------------------------------------------------------------- the J skeleton
SX, EY, R = 700, 600, 192          # stem centre x, elbow (hook centre) y, hook centreline radius
CX = SX - R                         # hook centre x = 508
ITALIC = "matrix(1 0 -0.2 1 112 0)"


def hook(r, a1=180, cy=EY, R_=R, cx=None):
    return arc(CX if cx is None else cx, cy, R_, 0, a1, r)


# ---------------------------------------------------------------- concepts
def build():
    C = []

    # ---- Bubble & balloon -------------------------------------------------
    c = Concept("B01", "Bubble & balloon", "Bubble flex", "Fist bubble, forearm, big bicep bubble, shoulder bubble, gooey joins")
    f = Field(40).add(circle(658, 262, 94)).add(capsule(700, 330, 700, 600, 64)).add(hook(80)).add(circle(462, 552, 124)).add(circle(318, 604, 92))
    c.layer(field_path(f.f)).hi(628, 232, 30, 14, -20).hi(418, 496, 40, 18, -35).hi(290, 574, 20, 9, -30); C.append(c)

    c = Concept("B02", "Bubble & balloon", "Balloon letter", "A fat balloon J with a pinch at the elbow; the hook lobe swells up like a bicep")
    f = Field(50).add(capsule(700, 300, 700, 580, 94)).add(arc(CX, EY, 176, 0, 180, 96)).add(circle(466, 556, 118), 70)
    c.layer(field_path(f.f)).hi(662, 252, 36, 16, -25).hi(416, 500, 46, 20, -35); C.append(c)

    c = Concept("B03", "Bubble & balloon", "Swole bubble J", "Thin forearm stem, the whole hook is one huge bicep bubble")
    f = Field(45).add(capsule(700, 300, 700, 600, 66)).add(hook(84)).add(circle(452, 548, 142), 60).add(circle(318, 606, 88))
    c.layer(field_path(f.f)).hi(672, 266, 18, 9, -20).hi(400, 480, 46, 20, -35); C.append(c)

    c = Concept("B04", "Bubble & balloon", "Balloon animal", "Separate spheres with little necks: fist, forearm beads, bicep, shoulder")
    f = Field(14).add(circle(654, 262, 90)).add(circle(698, 382, 56)).add(circle(700, 486, 64)).add(circle(696, 598, 76))
    for a in (30, 60, 90, 120, 150):
        f.add(circle(CX + R * math.cos(math.radians(a)), EY + R * math.sin(math.radians(a)), 76))
    f.add(circle(318, 604, 92)).add(circle(458, 552, 122))
    c.layer(field_path(f.f)).hi(626, 232, 28, 13, -20).hi(414, 496, 40, 18, -35).hi(290, 574, 20, 9, -30); C.append(c)

    c = Concept("B05", "Bubble & balloon", "Goo J", "Same parts as B01 melted together: one soft organic mass that implies J and bicep")
    f = Field(95).add(circle(658, 262, 94)).add(capsule(700, 330, 700, 600, 64)).add(hook(80)).add(circle(458, 556, 134)).add(circle(318, 604, 92))
    c.layer(field_path(f.f)).hi(628, 232, 30, 14, -20).hi(414, 496, 42, 19, -35); C.append(c)

    c = Concept("B06", "Bubble & balloon", "Double bubble", "Two big bubbles, fist and bicep, on a thin J; almost a bent dumbbell")
    f = Field(30).add(circle(652, 268, 108)).add(capsule(700, 360, 700, 600, 50)).add(hook(54)).add(circle(466, 592, 150)).add(circle(316, 606, 62))
    c.layer(field_path(f.f)).hi(616, 230, 36, 16, -20).hi(412, 528, 48, 22, -35); C.append(c)

    c = Concept("B07", "Bubble & balloon", "Italic bubble flex", "B01 leaning forward, more motion")
    f = Field(40).add(circle(658, 262, 94)).add(capsule(700, 330, 700, 600, 64)).add(hook(80)).add(circle(462, 552, 124)).add(circle(318, 604, 92))
    c.layer(field_path(f.f)).hi(628, 232, 30, 14, -20).hi(418, 496, 40, 18, -35); c.transform = ITALIC; C.append(c)

    # ---- Cartoon arm --------------------------------------------------------
    c = Concept("C01", "Cartoon arm", "Popeye", "The forearm is the muscle: huge forearm stem, small fist, modest bicep")
    f = Field(36).add(circle(666, 246, 80)).add(circle(700, 312, 58)).add(capsule(702, 360, 702, 600, 110)).add(hook(72)).add(circle(470, 588, 90)).add(circle(318, 604, 80))
    c.layer(field_path(f.f)).hi(640, 220, 26, 12, -20).hi(636, 440, 18, 64, 0).hi(430, 544, 30, 14, -35); C.append(c)

    c = Concept("C02", "Cartoon arm", "Bodybuilder", "Fist leaning to the shoulder, tapered forearm, tall bicep peak, big deltoid")
    f = Field(36).add(capsule(618, 256, 712, 240, 70)).add(circle(702, 340, 54)).add(capsule(702, 340, 702, 600, 64)).add(circle(698, 604, 76)).add(hook(84))
    f.add(circle(470, 540, 118)).add(circle(470, 500, 94)).add(circle(318, 598, 98))
    c.layer(field_path(f.f)).hi(628, 226, 36, 15, -15).hi(420, 462, 42, 19, -35).hi(286, 566, 22, 10, -30); C.append(c)

    c = Concept("C03", "Cartoon arm", "Curl with dumbbell", "Stem is the upper arm with the bicep bulging left; the hook is the forearm curling a dumbbell")
    f = Field(30).add(circle(690, 292, 100)).add(capsule(700, 300, 700, 600, 78)).add(circle(612, 444, 100), 50).add(hook(64, a1=172)).add(circle(332, 616, 84))
    db = Field(6).add(capsule(150, 616, 514, 616, 18)).add(capsule(182, 548, 182, 684, 36)).add(capsule(482, 548, 482, 684, 36))
    c.layer(field_path(db.f), Y_D, Y_DD).layer(field_path(f.f)).hi(660, 262, 36, 16, -20).hi(570, 400, 32, 15, -70).hi(306, 590, 24, 11, -20); C.append(c)

    c = Concept("C04", "Cartoon arm", "Fist forward", "Knuckles face you on top of the J; bicep in the bowl")
    f = Field(20)
    for kx, ky, kr in ((614, 262, 36), (656, 248, 38), (702, 248, 38), (746, 262, 36)):
        f.add(circle(kx, ky, kr))
    f.add(box(680, 300, 84, 48, 30)).add(circle(590, 322, 30)).add(capsule(700, 340, 700, 600, 64)).add(hook(80)).add(circle(462, 552, 122)).add(circle(318, 604, 90))
    c.layer(field_path(f.f)).hi(648, 236, 12, 6, 0).hi(694, 236, 12, 6, 0).hi(418, 496, 40, 18, -35); C.append(c)

    c = Concept("C05", "Cartoon arm", "Glove", "Cartoon glove fist in cream on a yellow arm: two colours, strong character")
    f = Field(36).add(circle(702, 340, 54)).add(capsule(702, 340, 702, 600, 64)).add(circle(698, 604, 76)).add(hook(84)).add(circle(470, 540, 118)).add(circle(470, 500, 94)).add(circle(318, 598, 98))
    g = Field(26).add(capsule(612, 256, 716, 238, 76)).add(circle(598, 300, 34))
    c.layer(field_path(f.f)).layer(field_path(g.f), GLOVE, GLOVE_D).hi(632, 226, 34, 14, -15, "#FFFFFF").hi(420, 462, 42, 19, -35).hi(286, 566, 22, 10, -30); C.append(c)

    c = Concept("C06", "Cartoon arm", "Curl", "C03 without the dumbbell: upper-arm stem, bicep left, forearm hook, fist terminal")
    f = Field(30).add(circle(690, 292, 100)).add(capsule(700, 300, 700, 600, 78)).add(circle(612, 444, 100), 50).add(hook(64, a1=178)).add(circle(330, 618, 92))
    c.layer(field_path(f.f)).hi(660, 262, 36, 16, -20).hi(570, 400, 32, 15, -70).hi(300, 590, 26, 12, -20); C.append(c)

    c = Concept("C07", "Cartoon arm", "Shoulder up", "The hook curls past horizontal so the shoulder rises: a shrugging flex")
    f = Field(36).add(capsule(618, 256, 712, 240, 70)).add(circle(702, 340, 54)).add(capsule(702, 340, 702, 600, 64)).add(circle(698, 604, 76)).add(hook(84, a1=204))
    f.add(circle(476, 534, 112)).add(circle(476, 494, 90)).add(circle(336, 514, 96))
    c.layer(field_path(f.f)).hi(628, 226, 36, 15, -15).hi(428, 458, 40, 18, -35).hi(306, 484, 22, 10, -30); C.append(c)

    # ---- Negative space -------------------------------------------------------
    mass = lambda: Field(24).add(circle(668, 244, 96)).add(capsule(712, 310, 712, 640, 86)).add(circle(466, 560, 168)).add(arc(508, 626, 192, 0, 180, 92)).add(circle(318, 626, 104))
    chan = lambda: Field(12).add(capsule(628, 350, 628, 560, 34)).add(capsule(628, 560, 616, 626, 34)).add(arc(508, 626, 112, 0, 160, 34))

    c = Concept("N01", "Negative space", "J crease", "A glossy arm mass with the J carved out as the black crease between forearm and bicep")
    f = mass(); f.cut(chan().f, 12)
    c.layer(field_path(f.f)).hi(640, 214, 34, 15, -20).hi(412, 492, 48, 22, -35); C.append(c)

    c = Concept("N02", "Negative space", "J groove", "Same mass, but the J is a darker groove instead of a hole: two-tone")
    f = mass(); dm = field_path(f.f); dc = field_path(chan().f)
    i = uid()
    c.layer(dm); c.after = f'<clipPath id="{i}"><path d="{dm}"/></clipPath><g clip-path="url(#{i})"><path d="{dc}" fill="{Y_D}"/></g>'
    c.hi(640, 214, 34, 15, -20).hi(412, 492, 48, 22, -35); C.append(c)

    # ---- Geometric ---------------------------------------------------------
    c = Concept("G01", "Geometric", "Geometric J, dome", "Flat-topped bar, even hook, one semicircular dome as the bicep. Icon-font clean")
    f = Field(16).add(box(706, 420, 72, 210, 30)).add(arc(508, 630, 198, 0, 180, 72)).add(circle(452, 600, 112))
    c.layer(field_path(f.f)).hi(404, 544, 40, 18, -35).hi(664, 290, 12, 46, 0); C.append(c)

    c = Concept("G02", "Geometric", "Open J, dome", "Helvetica-like J that stops early with a flat cut, dome in the bowl")
    open_hook = smax(arc(512, 630, 194, 0, 150, 72), plane(344, 727, -0.5, -0.866), 4)   # flat cut at the terminal
    f = Field(14).add(box(706, 420, 72, 210, 26)).add(open_hook).add(circle(470, 596, 100))
    c.layer(field_path(f.f)).hi(424, 540, 36, 16, -35).hi(664, 290, 12, 46, 0); C.append(c)

    c = Concept("G03", "Geometric", "Chunky toy letter", "Very fat J whose hook swells upward: the pumped letter")
    f = Field(70).add(capsule(702, 300, 702, 580, 104)).add(arc(508, 600, 172, 0, 180, 104)).add(circle(470, 556, 124), 80)
    c.layer(field_path(f.f)).hi(660, 250, 40, 18, -25).hi(420, 496, 48, 22, -35); C.append(c)

    c = Concept("G04", "Geometric", "Knot", "A rope-thin J with one round knot at the bottom of the hook")
    f = Field(24).add(capsule(702, 250, 702, 600, 54)).add(arc(508, 600, 192, 0, 190, 54)).add(circle(490, 780, 96))
    c.layer(field_path(f.f)).hi(448, 728, 34, 16, -35).hi(690, 270, 12, 36, 0); C.append(c)

    c = Concept("G05", "Geometric", "Pumped outside", "Clean J bowl inside; the muscle swells on the outside of the hook")
    f = Field(50).add(capsule(702, 260, 702, 600, 72)).add(arc(508, 600, 190, 0, 180, 72)).add(circle(474, 806, 104))
    c.layer(field_path(f.f)).hi(690, 290, 12, 40, 0).hi(432, 756, 40, 18, -35); C.append(c)

    c = Concept("G06", "Geometric", "Thin letter, solid muscle", "A slim J line that grows one big glossy bicep sphere: contrast between letter and muscle")
    f = Field(34).add(capsule(702, 240, 702, 600, 34)).add(arc(508, 600, 192, 0, 184, 34)).add(circle(474, 582, 132), 60)
    c.layer(field_path(f.f)).hi(420, 512, 48, 22, -35).hi(692, 262, 8, 30, 0); C.append(c)

    # ---- Angular & graffiti ----------------------------------------------------
    c = Concept("A01", "Angular & graffiti", "Faceted flex", "The bubble flex cut into flat planes: the Samurai Jack / Primal look")
    f = Field(40).add(circle(658, 262, 94)).add(capsule(700, 330, 700, 600, 64)).add(hook(80)).add(circle(462, 552, 124)).add(circle(318, 604, 92))
    loops = contours(f.f)
    facets = [rdp_closed(chaikin(lp, 1), 22) for lp in loops]
    c.layer(" ".join(poly_path(p) for p in facets))
    c.shines.append(f'<path d="M 400 500 L 432 476 L 452 498 L 418 520 Z" fill="{CREAM}"/>')
    c.shines.append(f'<path d="M 612 232 L 644 222 L 652 240 L 620 250 Z" fill="{CREAM}"/>'); C.append(c)

    c = Concept("A03", "Angular & graffiti", "Graffiti throw-up", "Swole bubble J with an inline, streak highlights and a bubble dot: the wall piece")
    f = Field(45).add(capsule(700, 300, 700, 600, 66)).add(hook(84)).add(circle(452, 548, 142), 60).add(circle(318, 606, 88))
    d = field_path(f.f); i = uid()
    c.layer(d)
    c.after = (f'<clipPath id="{i}"><path d="{d}"/></clipPath><g clip-path="url(#{i})"><path d="{d}" fill="none" stroke="{Y_DD}" stroke-width="26"/></g>'
               f'<path d="M 664 330 L 666 450" stroke="{CREAM}" stroke-width="14" stroke-linecap="round" fill="none"/>'
               f'<path d="M 376 516 Q 420 456 484 462" stroke="{CREAM}" stroke-width="14" stroke-linecap="round" fill="none"/>'
               f'<circle cx="394" cy="586" r="14" fill="{CREAM}"/>')
    C.append(c)

    # ---- Character & props --------------------------------------------------------
    c = Concept("K01", "Character & props", "Eyes on the bicep", "The bodybuilder J with a face on the muscle: full mascot energy")
    f = Field(36).add(capsule(618, 256, 712, 240, 70)).add(circle(702, 340, 54)).add(capsule(702, 340, 702, 600, 64)).add(circle(698, 604, 76)).add(hook(84))
    f.add(circle(470, 540, 118)).add(circle(470, 500, 94)).add(circle(318, 598, 98))
    c.layer(field_path(f.f)).hi(628, 226, 36, 15, -15)
    c.after = (f'<circle cx="438" cy="492" r="27" fill="#FFFFFF"/><circle cx="498" cy="484" r="27" fill="#FFFFFF"/>'
               f'<circle cx="446" cy="494" r="12" fill="{BG}"/><circle cx="506" cy="486" r="12" fill="{BG}"/>'
               f'<path d="M 404 454 L 462 466 M 476 460 L 532 444" stroke="{Y_DD}" stroke-width="18" stroke-linecap="round" fill="none"/>')
    C.append(c)

    c = Concept("L01", "Character & props", "Lowercase j, fist dot", "Short stem with the bicep hook; the dot is the fist")
    f = Field(36).add(capsule(700, 392, 700, 600, 66)).add(hook(78)).add(circle(466, 574, 112)).add(circle(318, 604, 84))
    c.layer(field_path(f.f)).layer(field_path(circle(680, 264, 82))).hi(650, 236, 28, 13, -20).hi(420, 518, 40, 18, -35); C.append(c)

    c = Concept("L02", "Character & props", "Lowercase j, plate dot", "Same j, but the dot is a weight plate")
    f = Field(36).add(capsule(700, 392, 700, 600, 66)).add(hook(78)).add(circle(466, 574, 112)).add(circle(318, 604, 84))
    pl = Field(4).add(circle(680, 262, 86)); pl.cut(circle(680, 262, 28), 2)
    c.layer(field_path(f.f)).layer(field_path(pl.f)).hi(646, 230, 24, 10, -25).hi(420, 518, 40, 18, -35); C.append(c)

    c = Concept("L03", "Character & props", "Barbell overhead", "The J's top serif is a barbell held in the fist; bicep in the bowl")
    bb = Field(6).add(capsule(470, 240, 930, 240, 18)).add(capsule(548, 180, 548, 300, 34)).add(capsule(852, 180, 852, 300, 34))
    f = Field(16).add(circle(700, 254, 68)).add(circle(700, 340, 52))
    f.add(capsule(700, 340, 700, 600, 62)).add(circle(698, 602, 74)).add(hook(82)).add(circle(468, 544, 114)).add(circle(468, 506, 92)).add(circle(318, 600, 94))
    c.layer(field_path(bb.f), Y_D, Y_DD).layer(field_path(f.f)).hi(676, 228, 20, 10, -20).hi(420, 466, 40, 18, -35); C.append(c)

    # ---- Brush ---------------------------------------------------------------
    c = Concept("R01", "Brush", "Thick brush flex", "One continuous brush stroke: heavy forearm, bigger bicep, ball shoulder, soft fist")
    a = Arm(w0=94, upper_w=8, bicep=160, bicep_sig=0.19, tri=36, ball=28, cap_top_ratio=0.8, R=186)
    c.layer(a.path_d())
    for pts in a.shines():
        c.shines.append(f'<path d="{poly_path(pts)}" fill="{CREAM}"/>')
    C.append(c)

    c = Concept("R02", "Brush", "Calligraphic", "Brush J with a pointed shoulder taper and a thinner top; the bicep is the thick of the stroke")
    a = Arm(w0=78, bicep=150, bicep_pos=0.44, tri=30, taper=46, taper_sig=150, cap_top_ratio=0.6, wrist=14, wrist_pos=120, R=190)
    c.layer(a.path_d())
    for pts in a.shines():
        c.shines.append(f'<path d="{poly_path(pts)}" fill="{CREAM}"/>')
    C.append(c)

    return C


# ---------------------------------------------------------------- page
def main():
    C = build()
    symbols = "".join(c.symbol() for c in C)
    groups = []
    for grp in dict.fromkeys(c.group for c in C):
        cards = []
        for c in [x for x in C if x.group == grp]:
            use = lambda s="": f'<svg viewBox="0 0 1024 1024" class="tile"{s}><use href="#{c.cid}"/></svg>'
            cards.append(f'<figure><div class="wrap">{use()}</div>'
                         f'<div class="row"><span class="mini">{use(" width=64 height=64")}</span><span class="mini">{use(" width=40 height=40")}</span>'
                         f'<figcaption><b>{c.cid} {html.escape(c.title)}</b><br><span>{html.escape(c.note)}</span></figcaption></div></figure>')
        groups.append(f'<h2>{html.escape(grp)}</h2><div class="grid">{"".join(cards)}</div>')
    page = f'''<!DOCTYPE html><html><head><meta charset="utf-8"><title>Jimmy logo concepts</title>
<style>
body{{background:#15151a;color:#e8e8ee;font:15px/1.45 -apple-system,Inter,system-ui,sans-serif;margin:0;padding:28px 36px 60px;max-width:1480px}}
h1{{font-size:24px;margin:0 0 6px}} h2{{font-size:17px;margin:30px 0 10px;color:#ffd27a}} p.intro{{color:#b7b7c4;max-width:1000px;margin:0 0 6px}} code{{color:#ffb84d}}
.grid{{display:grid;grid-template-columns:repeat(5,1fr);gap:20px 18px}}
figure{{margin:0}} .wrap svg.tile{{width:100%;height:auto;border-radius:22%;display:block}}
.row{{display:flex;gap:10px;align-items:flex-start;margin-top:8px}} .mini svg{{border-radius:22%;display:block}}
figcaption{{font-size:12.5px;color:#d6d6de;line-height:1.3}} figcaption span{{color:#9a9aa8;font-size:11.5px}}
.sym{{position:absolute;width:0;height:0;overflow:hidden}}
</style></head><body>
<svg class="sym" xmlns="http://www.w3.org/2000/svg"><defs>{symbols}</defs></svg>
<h1>Jimmy logo: 30 concepts (round 3)</h1>
<p class="intro">Thirty different takes on "a J that is also a flexing muscle", all in the cel shade + shine style, yellow <code>{Y}</code> on black <code>{BG}</code>.
Each tile also appears at 64 and 40 px. Shapes are built as smooth unions (bubbles and tubes that melt together), explicit facets, or a single brush stroke.</p>
{"".join(groups)}</body></html>'''
    os.makedirs(OUT_DIR, exist_ok=True)
    with open(OUT, "w") as f:
        f.write(page)
    write_svgs(C, OUT_DIR)
    print("wrote", OUT, len(page), "bytes,", len(C), "concepts")


if __name__ == "__main__":
    main()
