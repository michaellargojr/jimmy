#!/usr/bin/env python3
"""Shape exploration for the Jimmy J-muscle logo.

Construction: a J "spine" (straight stem, then a round or superelliptic hook) swept with a
smoothly varying width on each side. The inner side (toward the bowl) swells into the bicep,
the outer side swells gently into the triceps; optional fist bump at the top, wrist pinch,
ball or cut terminal, italic shear. Everything is one continuous outline, so every curve is
smooth. Rendered in the "cel shade + shine" style (flat fill, hard shadow side, one highlight).
"""
import math, html, os

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "shapes.html")
BG, Y, Y_D, CREAM = "#0A0A0D", "#FFB84D", "#E58F1C", "#FFF6E0"

DEFAULTS = dict(
    # spine
    x_stem=712, y_top=232, y_elbow=598, R=192, theta_end=180, exp=2.0,
    # widths (half-widths, px)
    w0=70, upper_w=0,
    fist_in=0, fist_out=0, fist_sig=85, wrist=0, wrist_pos=165, wrist_sig=55, wrist_bend=0,
    crease=0, crease_sig=45,
    bicep=125, bicep_pos=0.42, bicep_sig=0.17,
    tri=20, tri_pos=0.5, tri_sig=0.3,
    ball=0, ball_sig=70, taper=0, taper_sig=120,
    cap_top="round", cap_top_ratio=1.0, cap_end="round", cut_trim=0,
    shear=0.0,
)


def bump(s, c, sig, amp):
    return amp * math.exp(-0.5 * ((s - c) / sig) ** 2) if amp else 0.0


def smoothstep(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


class Arm:
    def __init__(self, **kw):
        p = dict(DEFAULTS); p.update(kw); self.p = p
        self._build()

    # -- spine -------------------------------------------------------------
    def _spine(self, n_stem=140, n_hook=460):
        p = self.p
        xs, yt, ye, R = p["x_stem"], p["y_top"], p["y_elbow"], p["R"]
        pts = []
        for i in range(n_stem):
            t = i / n_stem
            y = yt + (ye - yt) * t
            x = xs - p["wrist_bend"] * math.exp(-0.5 * ((y - yt) / 110) ** 2)   # wrist curling toward the shoulder
            pts.append((x, y))
        cx, cy = xs - R, ye
        th = math.radians(p["theta_end"]); e = p["exp"]
        for i in range(n_hook + 1):
            a = th * i / n_hook
            ca, sa = math.cos(a), math.sin(a)
            pts.append((cx + R * math.copysign(abs(ca) ** (2 / e), ca), cy + R * math.copysign(abs(sa) ** (2 / e), sa)))
        self.Ls = ye - yt
        return pts

    def _widths(self, s):
        p = self.p; Ls, Lh, L = self.Ls, self.Lh, self.L
        base = p["w0"] + p["upper_w"] * smoothstep((s - Ls + 70) / 140)
        win = wout = base
        win += bump(s, 0, p["fist_sig"], p["fist_in"]); wout += bump(s, 0, p["fist_sig"], p["fist_out"])
        pinch = bump(s, p["wrist_pos"], p["wrist_sig"], p["wrist"]); win -= pinch; wout -= pinch
        win -= bump(s, Ls, p["crease_sig"], p["crease"])
        win += bump(s, Ls + p["bicep_pos"] * Lh, p["bicep_sig"] * Lh, p["bicep"])
        wout += bump(s, Ls + p["tri_pos"] * Lh, p["tri_sig"] * Lh, p["tri"])
        end = bump(s, L, p["ball_sig"], p["ball"]) - bump(s, L, p["taper_sig"], p["taper"])
        win += end; wout += end
        return max(win, 8.0), max(wout, 8.0)

    def _build(self):
        p = self.p
        sp = self._spine()
        # arc length and tangents
        s = [0.0]
        for i in range(1, len(sp)):
            s.append(s[-1] + math.dist(sp[i - 1], sp[i]))
        self.L = s[-1]; self.Lh = self.L - self.Ls
        tang = []
        for i in range(len(sp)):
            a, b = sp[max(i - 1, 0)], sp[min(i + 1, len(sp) - 1)]
            dx, dy = b[0] - a[0], b[1] - a[1]; n = math.hypot(dx, dy) or 1
            tang.append((dx / n, dy / n))
        self.sp, self.s, self.tang = sp, s, tang
        inner, outer, win_l, wout_l = [], [], [], []
        for (x, y), (dx, dy), si in zip(sp, tang, s):
            wi, wo = self._widths(si)
            nx, ny = -dy, dx                         # inner normal: toward the bowl
            inner.append((x + nx * wi, y + ny * wi)); outer.append((x - nx * wo, y - ny * wo))
            win_l.append(wi); wout_l.append(wo)
        self.inner, self.outer, self.win, self.wout = inner, outer, win_l, wout_l
        # bicep apex index (for the shine)
        sb = self.Ls + p["bicep_pos"] * self.Lh
        self.i_bicep = min(range(len(s)), key=lambda i: abs(s[i] - sb))

    # -- caps and outline ----------------------------------------------------
    def _cap(self, i, forward, n_pts=40):
        """Half-ellipse from inner[i] around the spine end to outer[i]. forward = unit vector pointing out of the shape."""
        (x, y), wi, wo = self.sp[i], self.win[i], self.wout[i]
        dx, dy = self.tang[i]; nx, ny = -dy, dx
        fx, fy = forward
        r = (wi + wo) / 2 * self.p["cap_top_ratio"] if i == 0 else (wi + wo) / 2
        pts = []
        for k in range(1, n_pts):
            ph = math.pi * k / n_pts
            w = wi if math.cos(ph) >= 0 else wo
            pts.append((x + nx * w * math.cos(ph) + fx * r * math.sin(ph), y + ny * w * math.cos(ph) + fy * r * math.sin(ph)))
        return pts

    def outline(self):
        p = self.p
        n = len(self.sp)
        # terminal: optional slanted cut (trim the inner edge so the cut slants like a sleeve)
        i_end_in = n - 1
        if p["cap_end"] == "cut" and p["cut_trim"]:
            target = self.L - p["cut_trim"]
            i_end_in = min(range(n), key=lambda i: abs(self.s[i] - target))
        pts = list(self.inner[: i_end_in + 1])
        if p["cap_end"] == "round":
            pts += self._cap(n - 1, self.tang[n - 1])
        pts += list(reversed(self.outer))
        if p["cap_top"] == "round":
            tx, ty = self.tang[0]
            pts += list(reversed(self._cap(0, (-tx, -ty))))   # from outer[0] back around to inner[0]
        return [self._shear(q) for q in pts]

    def _shear(self, q):
        k = self.p["shear"]
        return (q[0] + k * (560 - q[1]), q[1]) if k else q

    def path_d(self, pts=None):
        pts = pts or self.outline()
        return "M " + " L ".join(f"{x:.1f} {y:.1f}" for x, y in pts) + " Z"

    # -- shines --------------------------------------------------------------
    def shines(self):
        """Highlight blobs: on the bicep apex, and on the fist if there is one."""
        out = []
        i = self.i_bicep
        (x, y), (dx, dy), wi = self.sp[i], self.tang[i], self.win[i]
        nx, ny = -dy, dx
        cx, cy = x + nx * wi * 0.64, y + ny * wi * 0.64
        out.append(self._ellipse_pts(cx, cy, wi * 0.34, wi * 0.15, math.atan2(dy, dx)))
        if self.p["fist_in"] > 30:
            (x, y), (dx, dy), wi = self.sp[0], self.tang[0], self.win[0]
            nx, ny = -dy, dx
            cx, cy = x + nx * wi * 0.42 - dx * wi * 0.35, y + ny * wi * 0.42 - dy * wi * 0.35
            out.append(self._ellipse_pts(cx, cy, wi * 0.30, wi * 0.13, math.radians(-15)))
        return out

    def _ellipse_pts(self, cx, cy, rx, ry, ang, n=36):
        ca, sa = math.cos(ang), math.sin(ang)
        pts = []
        for k in range(n):
            t = 2 * math.pi * k / n
            ex, ey = rx * math.cos(t), ry * math.sin(t)
            pts.append(self._shear((cx + ex * ca - ey * sa, cy + ex * sa + ey * ca)))
        return pts


# ---------------------------------------------------------------- rendering
_uid = [0]


def uid():
    _uid[0] += 1
    return f"s{_uid[0]}"


def cel(paths, shines, off=22, size=None):
    """paths: list of path d strings drawn back to front, each cel-shaded; shines: list of point lists."""
    s = f' width="{size}" height="{size}"' if size else ''
    body = ""
    for d in paths:
        i = uid()
        body += (f'<defs><clipPath id="{i}"><path d="{d}"/></clipPath></defs>'
                 f'<path d="{d}" fill="{Y_D}"/>'
                 f'<g clip-path="url(#{i})"><path d="{d}" fill="{Y}" transform="translate(-{off} -{off})"/></g>')
    for pts in shines:
        body += '<path d="' + "M " + " L ".join(f"{x:.1f} {y:.1f}" for x, y in pts) + f' Z" fill="{CREAM}"/>'
    return (f'<svg viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg"{s} class="tile">'
            f'<rect width="1024" height="1024" fill="{BG}"/>{body}</svg>')


def layered(front: Arm, back: Arm, shadow=18, size=None):
    """Forearm (front) drawn over the upper arm (back) with a cast shadow onto it."""
    s = f' width="{size}" height="{size}"' if size else ''
    db, df = back.path_d(), front.path_d()
    ib, ifr, ic = uid(), uid(), uid()
    body = (f'<defs><clipPath id="{ib}"><path d="{db}"/></clipPath><clipPath id="{ifr}"><path d="{df}"/></clipPath></defs>'
            f'<path d="{db}" fill="{Y_D}"/>'
            f'<g clip-path="url(#{ib})"><path d="{db}" fill="{Y}" transform="translate(-22 -22)"/>'
            f'<path d="{df}" fill="none" stroke="{Y_D}" stroke-width="{shadow * 2}"/></g>'
            f'<path d="{df}" fill="{Y_D}"/>'
            f'<g clip-path="url(#{ifr})"><path d="{df}" fill="{Y}" transform="translate(-22 -22)"/></g>')
    for pts in back.shines()[:1] + front.shines()[1:]:
        body += '<path d="' + "M " + " L ".join(f"{x:.1f} {y:.1f}" for x, y in pts) + f' Z" fill="{CREAM}"/>'
    return (f'<svg viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg"{s} class="tile">'
            f'<rect width="1024" height="1024" fill="{BG}"/>{body}</svg>')


# ---------------------------------------------------------------- the variants
def variants():
    V = []
    def add(code, title, note, arm=None, render=None):
        V.append((code, title, note, arm, render))

    # Row 1: brush J, no fist
    add("S01", "Brush J", "Round hook, thin forearm, bicep swells into the bowl, round shoulder",
        Arm())
    add("S02", "Brush J, ball shoulder", "Same with a ball terminal as the deltoid",
        Arm(ball=36, bicep=118))
    add("S03", "Brush J, sleeve cut", "Shoulder ends in a slanted cut, like a sleeve",
        Arm(cap_end="cut", cut_trim=70, tri=30, theta_end=176))
    add("S04", "Open hook", "Hook stops low (Helvetica-like J), bicep further toward the elbow",
        Arm(theta_end=158, bicep=112, bicep_pos=0.36, R=200))
    add("S05", "Tall and narrow", "A taller letter with a smaller hook and modest bicep",
        Arm(y_top=196, R=168, w0=64, bicep=104, tri=16))

    # Row 2: with a fist
    add("S06", "Fist J", "Fist bulges toward the shoulder, wrist pinch, ball shoulder",
        Arm(fist_in=78, fist_out=22, wrist=10, ball=30, bicep=118))
    add("S07", "Fist, curling", "Fist leans in toward the shoulder, like the top of a flex",
        Arm(fist_in=70, fist_out=24, wrist=12, wrist_bend=44, ball=26, bicep=118))
    add("S08", "Big fist", "Heavier fist, wider hook",
        Arm(fist_in=102, fist_out=38, fist_sig=92, wrist=14, theta_end=184, bicep=122, R=200))
    add("S09", "Fist, sleeve cut", "Fist on top, slanted sleeve at the shoulder",
        Arm(fist_in=78, fist_out=22, wrist=10, cap_end="cut", cut_trim=70, tri=28, theta_end=176))
    add("S10", "Fist, flat top", "Fist squared off at the top, more letter-like",
        Arm(fist_in=72, fist_out=26, wrist=10, cap_top_ratio=0.45, ball=28))

    # Row 3: italic and squarer
    add("S11", "Italic brush J", "S01 leaning 11 degrees",
        Arm(shear=0.2))
    add("S12", "Italic fist J", "S07 leaning 11 degrees",
        Arm(fist_in=70, fist_out=24, wrist=12, wrist_bend=44, ball=26, bicep=118, shear=0.2))
    add("S13", "Squarer hook", "Superelliptic hook, flatter bottom",
        Arm(exp=2.6, bicep=128, R=186))
    add("S14", "Squarer hook, italic ball", "Squarer hook with a ball shoulder, slight lean",
        Arm(exp=2.4, ball=34, shear=0.12, bicep=120))
    add("S15", "Shoulder up", "Hook curls past horizontal: the shoulder rises",
        Arm(theta_end=212, ball=24, bicep=116, bicep_pos=0.40, R=186))

    # Row 4: weight experiments
    add("S16", "Heavy", "Thick everywhere, pumped",
        Arm(w0=86, upper_w=14, bicep=138, tri=42, R=178, ball=16))
    add("S17", "Thin forearm, big upper arm", "Dramatic taper: slim forearm, massive bicep",
        Arm(w0=58, upper_w=34, bicep=150, tri=34, wrist=0))
    add("S18", "Wide", "Wider hook, calmer bicep",
        Arm(R=218, w0=72, bicep=112, tri=18, y_top=250))
    add("S19", "Crease", "Deeper fold between forearm and bicep",
        Arm(crease=18, bicep=132, bicep_pos=0.40, bicep_sig=0.15, ball=28))
    add("S20", "Soft", "Lower, wider bicep: barely a bump, mostly a letter",
        Arm(bicep=82, bicep_sig=0.26, tri=12, ball=20))

    # Row 5: layered arm (forearm in front)
    fore = Arm(fist_in=78, fist_out=22, wrist=10, bicep=0, tri=0, theta_end=52)
    back = Arm(bicep=118, ball=30, y_top=560)
    add("S21", "Layered, fist", "Forearm in front of the upper arm, cast shadow at the elbow",
        None, lambda size=None: layered(fore, back, size=size))
    fore2 = Arm(bicep=0, tri=0, theta_end=52)
    back2 = Arm(bicep=118, cap_end="cut", cut_trim=70, tri=26, theta_end=176, y_top=560)
    add("S22", "Layered, no fist", "Same layering, plain top, sleeve cut",
        None, lambda size=None: layered(fore2, back2, size=size))
    add("S23", "Layered, italic", "S21 leaning",
        None, lambda size=None: layered(Arm(fist_in=70, fist_out=24, wrist=12, wrist_bend=40, bicep=0, tri=0, theta_end=52, shear=0.2),
                                        Arm(bicep=118, ball=26, y_top=560, shear=0.2), size=size))
    add("S24", "Lowercase j", "Short stem with the fist as the dot",
        None, None)   # built below
    add("S25", "Low fist", "Fist sits lower, hook very open: almost a bicep curl",
        Arm(fist_in=84, fist_out=30, wrist=12, wrist_bend=30, theta_end=150, bicep=104, bicep_pos=0.34, R=205, ball=24, y_top=268))
    return V


def lowercase_j(size=None):
    body = Arm(y_top=345, bicep=116, ball=26)
    dot = body._ellipse_pts(body.p["x_stem"] - 10, 236, 76, 70, 0)
    d_dot = "M " + " L ".join(f"{x:.1f} {y:.1f}" for x, y in dot) + " Z"
    return cel([body.path_d(), d_dot], body.shines(), size=size)


def render_variant(v, size=None):
    code, title, note, arm, render = v
    if render:
        return render(size=size)
    if code == "S24":
        return lowercase_j(size=size)
    return cel([arm.path_d()], arm.shines(), size=size)


def main():
    V = variants()
    cards = []
    for v in V:
        code, title, note = v[0], v[1], v[2]
        cards.append(f'<figure><div class="wrap">{render_variant(v)}</div>'
                     f'<div class="row"><span class="mini">{render_variant(v, 64)}</span><span class="mini">{render_variant(v, 40)}</span>'
                     f'<figcaption><b>{code} {html.escape(title)}</b><br><span>{html.escape(note)}</span></figcaption></div></figure>')
    page = f'''<!DOCTYPE html><html><head><meta charset="utf-8"><title>Jimmy logo shape board</title>
<style>
body{{background:#15151a;color:#e8e8ee;font:15px/1.45 -apple-system,Inter,system-ui,sans-serif;margin:0;padding:28px 36px 60px;max-width:1480px}}
h1{{font-size:24px;margin:0 0 6px}} p.intro{{color:#b7b7c4;max-width:1000px;margin:0 0 18px}} code{{color:#ffb84d}}
.grid{{display:grid;grid-template-columns:repeat(5,1fr);gap:20px 18px}}
figure{{margin:0}} .wrap svg.tile{{width:100%;height:auto;border-radius:22%;display:block}}
.row{{display:flex;gap:10px;align-items:flex-start;margin-top:8px}} .mini svg{{border-radius:22%;display:block}}
figcaption{{font-size:12.5px;color:#d6d6de;line-height:1.3}} figcaption span{{color:#9a9aa8;font-size:11.5px}}
</style></head><body>
<h1>Jimmy logo: shape board (round 2)</h1>
<p class="intro">Every mark here is one continuous outline: a J spine swept with a width that swells into the bicep on the bowl side.
All rendered the same way (cel shade + shine, yellow <code>{Y}</code> on <code>{BG}</code>) so only the shape changes.
Next to each: the same mark at 64 and 40 px.</p>
<div class="grid">{"".join(cards)}</div></body></html>'''
    with open(OUT, "w") as f:
        f.write(page)
    print("wrote", OUT, len(page), "bytes,", len(V), "variants")


if __name__ == "__main__":
    main()
