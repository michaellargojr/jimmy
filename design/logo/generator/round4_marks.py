#!/usr/bin/env python3
"""Round 4: a small set of carefully drawn J-muscle marks built like letters, not tubes.

Construction: a heavy geometric capital J (flat-topped stem, hook on a true circle whose stroke
thins toward the terminal) with the muscle carried by one deliberate deviation (a bicep peak in
the bowl with an elbow crease, a fist serif, or a ball terminal) and by the glossy shading.
"""
import math, html, os
import numpy as np
import round3_concepts as cp
from round3_concepts import circle, capsule, box, plane, smin, smax, field_path, contours, uid, Concept, shine, cel_layer, write_svgs

HERE = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.join(HERE, "..", "rounds", "round-4-marks")
OUT = os.path.join(OUT_DIR, "index.html")
BG, Y, Y_D, Y_DD, CREAM, Y_L = cp.BG, cp.Y, cp.Y_D, cp.Y_DD, cp.CREAM, "#FFD27A"


def smoothstep(t):
    t = max(0.0, min(1.0, t)); return t * t * (3 - 2 * t)


def hook(cx, cy, Ro, a0, a1, w0, w1, step=3.0):
    """Hook stroke whose OUTER edge lies on the circle of radius Ro and whose half-width eases
    from w0 (at a0) to w1 (at a1). Built from closely spaced circles: scallops under 1 px."""
    n = max(2, int((a1 - a0) / step))
    f = None
    for i in range(n + 1):
        t = i / n
        a = math.radians(a0 + (a1 - a0) * t)
        w = w0 + (w1 - w0) * smoothstep(t)
        d = circle(cx + (Ro - w) * math.cos(a), cy + (Ro - w) * math.sin(a), w)
        f = d if f is None else np.minimum(f, d)
    return f


# ---------------------------------------------------------------- the letter
# Stem x 600..790 (w 190), top y 150. Hook outer circle: centre (495, 575), radius 295 -> passes
# through (790, 575), bottom at 870, left extreme 200. Bicep peak rises in the bowl next to the stem.
C = (495, 575); RO = 295
STEM = dict(cx=695, cy=362, hx=95, hy=212, r=34)          # y 150..574


def stem(top_r=34, top=150, extra_w=0):
    hy = (574 - top) / 2
    return box(695, top + hy, 95 + extra_w, hy, top_r)


def bicep(peak=(472, 500, 102), base=(420, 590, 150), k=80):
    return smin(circle(*base), circle(*peak), k)


def letter(hump=True, a1=165, w0=95, w1=62, top_r=34, top=150, hump_kw=None, k_hump=40, k_stem=10):
    h = hook(*C, RO, 0, a1, w0, w1)
    if hump:
        h = smin(h, bicep(**(hump_kw or {})), k_hump)
    return smin(stem(top_r, top), h, k_stem)


def mark(cid, title, note):
    return Concept(cid, "", title, note)


def build():
    M = []

    m = mark("M1", "Bold J, bicep in the bowl", "Heavy geometric J, hook thins to a round terminal; the only deviation is the bicep peak and the elbow crease beside the stem")
    m.layer(field_path(letter())).hi(446, 450, 44, 20, -35).hi(642, 214, 12, 40, 0); M.append(m)

    m = mark("M2", "Fist J", "M1 with a top serif that curls toward the shoulder: the fist. Peak rises to sit under it")
    f = smin(letter(hump_kw=dict(peak=(470, 476, 104))), box(640, 196, 128, 56, 46), 12)
    m.layer(field_path(f)).hi(446, 428, 44, 20, -35).hi(596, 184, 30, 12, -8); M.append(m)

    m = mark("M3", "Cooper J", "Display-face J: the hook thins into a neck and ends in one big ball terminal, the round muscle. No crease, pure letter")
    neck = hook(*C, RO, 0, 200, 95, 46)
    ball = circle(495 + 177 * math.cos(math.radians(205)), 575 + 177 * math.sin(math.radians(205)), 118)
    f = smin(stem(), smin(neck, ball, 30), 10)
    m.layer(field_path(f)).hi(302, 450, 40, 20, -35).hi(642, 214, 12, 40, 0); M.append(m)

    m = mark("M4", "Sculpted J", "A plain heavy J; the muscle is only in the shading: cylinder highlight on the forearm, round highlight on the hook, dark elbow crease")
    f = letter(hump=False, w1=70)
    d = field_path(f); i = uid()
    m.layer(d)
    m.after = (f'<clipPath id="{i}"><path d="{d}"/></clipPath><g clip-path="url(#{i})">'
               f'<path d="M 604 500 Q 614 612 672 664" stroke="{Y_DD}" stroke-width="18" stroke-linecap="round" fill="none" opacity="0.85"/>'
               f'<ellipse cx="330" cy="618" rx="50" ry="26" transform="rotate(-42 330 618)" fill="{CREAM}"/>'
               f'<ellipse cx="648" cy="300" rx="13" ry="92" fill="{CREAM}" opacity="0.9"/></g>')
    M.append(m)

    m = mark("M5", "Two-piece J", "Forearm as a separate pill in front of the hook-and-bicep piece, with a cast shadow at the elbow. Great Courses logic, glossy")
    back = smin(hook(*C, RO, 0, 165, 95, 62), bicep(), 40)
    front = smin(stem(), circle(695, 574, 95), 4)
    db, df = field_path(back), field_path(front); ib = uid()
    m.layer(db)
    m.after = (f'<clipPath id="{ib}"><path d="{db}"/></clipPath><g clip-path="url(#{ib})"><path d="{df}" fill="none" stroke="{Y_D}" stroke-width="34"/></g>'
               + cel_layer(df) + shine(446, 450, 44, 20, -35) + shine(642, 214, 12, 40, 0))
    M.append(m)

    m = mark("M6", "Fist J, sleeve cut", "M2 but the hook ends in a slanted flat cut, like a sleeve at the shoulder")
    h = hook(*C, RO, 0, 178, 95, 66)
    a = math.radians(158); rc = RO - 68
    px, py = 495 + rc * math.cos(a), 575 + rc * math.sin(a)
    h = smax(h, plane(px, py, -math.sin(a), math.cos(a)), 6)
    h = smin(h, bicep(peak=(470, 476, 104)), 40)
    f = smin(smin(stem(), h, 10), box(640, 196, 128, 56, 46), 12)
    m.layer(field_path(f)).hi(446, 428, 44, 20, -35).hi(596, 184, 30, 12, -8); M.append(m)

    m = mark("M7", "Italic bold J", "M1 leaning 10 degrees")
    m.layer(field_path(letter())).hi(446, 450, 44, 20, -35).hi(642, 214, 12, 40, 0); m.transform = "matrix(1 0 -0.18 1 100 0)"; M.append(m)

    m = mark("M8", "Bold J, round top", "M1 with a rounded stem top and a slightly higher, rounder peak")
    m.layer(field_path(letter(top_r=95, hump_kw=dict(peak=(468, 484, 108), base=(416, 596, 150))))).hi(442, 436, 44, 20, -35).hi(650, 222, 14, 36, 0); M.append(m)

    m = mark("M9", "Bold J, low peak", "M1 with a calmer bicep: lower peak, wider crease, more letter than arm")
    m.layer(field_path(letter(hump_kw=dict(peak=(466, 540, 98), base=(418, 610, 148)), k_hump=50))).hi(440, 494, 44, 20, -35).hi(642, 214, 12, 40, 0); M.append(m)

    return M


def gradient_glow_layer(d, shines):
    """The 'gradient + rim + glow' style from the round-1 board, for a single path."""
    i = uid()
    return (f'<defs><linearGradient id="{i}g" gradientUnits="userSpaceOnUse" x1="300" y1="150" x2="500" y2="870">'
            f'<stop offset="0" stop-color="#FFD98A"/><stop offset="0.55" stop-color="{Y}"/><stop offset="1" stop-color="#F28A14"/></linearGradient>'
            f'<clipPath id="{i}c"><path d="{d}"/></clipPath>'
            f'<filter id="{i}f" x="-40%" y="-40%" width="180%" height="180%"><feGaussianBlur stdDeviation="36"/></filter></defs>'
            f'<g filter="url(#{i}f)" opacity="0.4"><path d="{d}" fill="{Y}"/></g><path d="{d}" fill="{CREAM}"/>'
            f'<g clip-path="url(#{i}c)"><path d="{d}" fill="url(#{i}g)" transform="translate(0 9)"/></g>' + shines)


def soft_gradient_layer(d):
    i = uid()
    return (f'<defs><linearGradient id="{i}g" gradientUnits="userSpaceOnUse" x1="0" y1="150" x2="0" y2="870">'
            f'<stop offset="0" stop-color="#FFD170"/><stop offset="1" stop-color="#FF9A24"/></linearGradient></defs>'
            f'<path d="{d}" fill="url(#{i}g)"/>')


def main():
    M = build()
    symbols = "".join(m.symbol() for m in M)
    # style alternates for M1 and M2
    alt = ""
    for m in M[:2]:
        d = m.layers[0][0]
        alt += (f'<symbol id="{m.cid}-grad" viewBox="0 0 1024 1024"><rect width="1024" height="1024" fill="{BG}"/>{soft_gradient_layer(d)}</symbol>'
                f'<symbol id="{m.cid}-glow" viewBox="0 0 1024 1024"><rect width="1024" height="1024" fill="{BG}"/>{gradient_glow_layer(d, "".join(m.shines))}</symbol>')

    def use(cid, s=""):
        return f'<svg viewBox="0 0 1024 1024" class="tile"{s}><use href="#{cid}"/></svg>'

    cards = []
    for m in M:
        cards.append(f'<figure><div class="wrap">{use(m.cid)}</div>'
                     f'<div class="row"><span class="mini">{use(m.cid, " width=96 height=96")}</span><span class="mini">{use(m.cid, " width=64 height=64")}</span><span class="mini">{use(m.cid, " width=40 height=40")}</span>'
                     f'<figcaption><b>{m.cid} {html.escape(m.title)}</b><br><span>{html.escape(m.note)}</span></figcaption></div></figure>')
    alts = "".join(f'<figure><div class="wrap">{use(cid)}</div><figcaption><b>{label}</b></figcaption></figure>'
                   for cid, label in (("M1-grad", "M1 soft gradient"), ("M1-glow", "M1 gradient + rim + glow"),
                                      ("M2-grad", "M2 soft gradient"), ("M2-glow", "M2 gradient + rim + glow")))
    page = f'''<!DOCTYPE html><html><head><meta charset="utf-8"><title>Jimmy logo marks</title>
<style>
body{{background:#15151a;color:#e8e8ee;font:15px/1.45 -apple-system,Inter,system-ui,sans-serif;margin:0;padding:28px 36px 60px;max-width:1480px}}
h1{{font-size:24px;margin:0 0 6px}} h2{{font-size:17px;margin:30px 0 10px;color:#ffd27a}} p.intro{{color:#b7b7c4;max-width:1000px;margin:0 0 6px}} code{{color:#ffb84d}}
.grid{{display:grid;grid-template-columns:repeat(3,1fr);gap:26px 24px}} .grid4{{display:grid;grid-template-columns:repeat(4,1fr);gap:20px}}
figure{{margin:0}} .wrap svg.tile{{width:100%;height:auto;border-radius:22%;display:block}}
.row{{display:flex;gap:10px;align-items:flex-start;margin-top:10px}} .mini svg{{border-radius:22%;display:block}}
figcaption{{font-size:13px;color:#d6d6de;line-height:1.35}} figcaption span{{color:#9a9aa8;font-size:12px}}
.sym{{position:absolute;width:0;height:0;overflow:hidden}}
</style></head><body>
<svg class="sym" xmlns="http://www.w3.org/2000/svg"><defs>{symbols}{alt}</defs></svg>
<h1>Jimmy logo: round 4, drawn as letters</h1>
<p class="intro">A heavy geometric capital J (flat top, hook on a true circle, stroke thinning toward the terminal). The muscle comes from one deliberate deviation
and from the glossy shading, not from lumps. Cel shade + shine, yellow <code>{Y}</code> on black <code>{BG}</code>; each also at 96, 64 and 40 px.</p>
<div class="grid">{"".join(cards)}</div>
<h2>The two leads in the other styles you liked</h2>
<div class="grid4">{alts}</div>
</body></html>'''
    os.makedirs(OUT_DIR, exist_ok=True)
    with open(OUT, "w") as f:
        f.write(page)
    write_svgs(M, OUT_DIR)
    # the two leads in the other styles, as standalone files too
    svg_dir = os.path.join(OUT_DIR, "svg")
    for m in M[:2]:
        d = m.layers[0][0]
        for suffix, inner in (("grad", soft_gradient_layer(d)), ("glow", gradient_glow_layer(d, "".join(m.shines)))):
            with open(os.path.join(svg_dir, f"{m.cid}-{suffix}.svg"), "w") as f:
                f.write(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">'
                        f'<rect width="1024" height="1024" fill="{BG}"/>{inner}</svg>\n')
    print("wrote", OUT, len(page), "bytes,", len(M), "marks")


if __name__ == "__main__":
    main()
