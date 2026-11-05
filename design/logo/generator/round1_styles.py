#!/usr/bin/env python3
"""Style board generator for the Jimmy J-muscle logo exploration.

Emits an HTML page of inline SVG tiles (1024x1024 viewBox each) so the user can
compare constructions (how the J and the arm share a silhouette) and rendering
styles side by side, plus home-screen-size previews and yellow options.
"""
import os, html

OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "rounds", "round-1-styles")
OUT = os.path.join(OUT_DIR, "index.html")

BG = "#0A0A0D"
Y = "#FFB84D"        # current brand "yellow" (orange-amber) from Theme.swift
Y_L = "#FFD27A"      # light tint
Y_D = "#E58F1C"      # shade
Y_DD = "#8A4F06"     # deep shade (offset shadow)
CREAM = "#FFF6E0"    # shine
INK = "#1B0F00"      # cartoon line

# ---------------------------------------------------------------- geometry
# Shared J skeleton: stem on the right, hook sweeping left at the bottom.
XR, W = 775, 150          # stem right edge, stroke width
XL = XR - W               # 625
XS = XR - W / 2           # 700 stem centre
R = 185                   # hook centreline radius
HY = 610                  # hook centre y; outer bottom = 610+185+75 = 870
HX = XS - R               # 515 hook centre x
HL = XS - 2 * R           # 330 terminal centreline x
ELBOW_Y = 650             # where the forearm piece ends (rounded) inside the hook


def hook(extra=""):
    """The hook as a filled half-ring (not a stroked arc), so clip paths and erosion see its true area."""
    ro, ri = R + W / 2, R - W / 2
    return (f'<path d="M {XS + W/2} {HY} A {ro} {ro} 0 0 1 {HL - W/2} {HY} L {HL + W/2} {HY} '
            f'A {ri} {ri} 0 0 0 {XS - W/2} {HY} Z" {extra}/>')


def rect(x, y, w, h, rx=0, extra=""):
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" {extra}/>'


def rrect(x, y, w, h, rtl, rtr, rbr, rbl):
    """Rounded rect with a radius per corner (top-left, top-right, bottom-right, bottom-left)."""
    return (f'<path d="M {x+rtl} {y} H {x+w-rtr} A {rtr} {rtr} 0 0 1 {x+w} {y+rtr} V {y+h-rbr} '
            f'A {rbr} {rbr} 0 0 1 {x+w-rbr} {y+h} H {x+rbl} A {rbl} {rbl} 0 0 1 {x} {y+h-rbl} '
            f'V {y+rtl} A {rtl} {rtl} 0 0 1 {x+rtl} {y} Z"/>')


def circle(cx, cy, r, extra=""):
    return f'<circle cx="{cx}" cy="{cy}" r="{r}" {extra}/>'


def ellipse(cx, cy, rx, ry, extra=""):
    return f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" {extra}/>'


def path(d, extra=""):
    return f'<path d="{d}" {extra}/>'


# the bicep: a hump, gentle on the shoulder side, steep on the elbow side; its base hides in the hook
HUMP = path("M 340 780 L 340 650 C 372 560, 418 428, 498 428 C 574 428, 598 520, 598 650 L 598 780 Z")
BALL = circle(336, 642, 84)


class Concept:
    """fore = fist + forearm, upper = hook + shoulder + bicep.
    lines = cartoon detail strokes (first one clipped to line_clip), shine = highlight blobs.
    bite = a BG shape drawn between fore and upper (the split construction's elbow gap)."""
    def __init__(self, name, fore, upper, lines=(), line_clip=None, shine=(), bite=None):
        self.name, self.fore, self.upper = name, fore, upper
        self.lines, self.line_clip, self.shine, self.bite = list(lines), line_clip, list(shine), bite

    def all_shapes(self):
        return self.upper + self.fore


def concept_flex():
    fy, fh = 178, 138
    fist = rrect(520, fy, 280, fh, 68, 50, 50, 68)          # fist curls toward the shoulder: the J's top serif
    forearm = [rect(XL, fy + 60, W, ELBOW_Y - fy - 60), circle(XS, ELBOW_Y, W / 2)]
    fore = forearm + [fist]
    upper = [hook(), BALL, HUMP]
    lines = [
        path("M 352 596 Q 474 704 600 628"),                                   # bicep crease
        path(f"M 596 {fy+34} Q 556 {fy+69} 596 {fy+104}"),                     # thumb across the fist
        path(f"M {XL+12} {fy+fh+44} q 63 26 126 0"),                          # wrist
    ]
    shine = [ellipse(452, 500, 54, 24, 'transform="rotate(-38 452 500)"')]
    return Concept("flex", fore, upper, lines=lines, line_clip=[hook(), BALL, HUMP], shine=shine)


def concept_split(gap=26):
    """Two pieces: forearm with a socket, upper arm with a knob at the elbow."""
    c = concept_flex()
    fy = 178
    c.fore = [rect(XL, fy + 60, W, HY - fy - 60), c.fore[-1]]            # forearm ends flat at the elbow
    c.upper = [hook(), circle(XS, HY, W / 2), BALL, HUMP]               # knob at the hook's right end
    c.bite = circle(XS, HY, W / 2 + gap)
    c.name = "split"
    return c


def concept_curl():
    """Stem = upper arm bowing out to the left (the bicep), hook = forearm curling up, terminal = fist."""
    top = 262
    upper = [path(f"M {XL} {top} A 75 75 0 0 1 {XR} {top} V {HY+2} H {XL} Z"),
             path(f"M 660 280 C 540 300, 486 380, 492 452 C 498 526, 560 586, 640 {HY+2} Z")]
    fist = circle(HL + 2, HY - 26, 100)
    fore = [hook(), fist]
    lines = [path("M 648 300 Q 560 450 646 598"),                              # bicep's inner edge
             path(f"M {HL-50} {HY-78} q -10 50 0 100 M {HL-14} {HY-96} q -6 36 0 72")]   # knuckles
    shine = [ellipse(556, 372, 44, 20, 'transform="rotate(-70 556 372)"')]
    return Concept("curl", fore, upper, lines=lines, line_clip=upper, shine=shine)


def concept_current_fixed():
    """Today's construction (no fist, no shoulder ball) with corrected proportions."""
    fore = [rect(XL, 175, W, HY - 175 + 2), rect(XL, 175, W, 100, 44)]
    dome = ellipse(468, 600, 134, 172)
    upper = [hook(), circle(HL, HY, W / 2), dome]
    lines = [path("M 352 606 Q 468 700 594 630")]
    shine = [ellipse(420, 495, 56, 26, 'transform="rotate(-30 420 495)"')]
    return Concept("current+", fore, upper, lines=lines, line_clip=[hook(), circle(HL, HY, W / 2), dome], shine=shine)


# ---------------------------------------------------------------- styles
_uid = [0]


def uid():
    _uid[0] += 1
    return f"i{_uid[0]}"


def svg(inner, size=None):
    s = f' width="{size}" height="{size}"' if size else ''
    return (f'<svg viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg"{s} class="tile">'
            f'<rect width="1024" height="1024" fill="{BG}"/>{inner}</svg>')


def g(shapes, fill, extra=""):
    return f'<g fill="{fill}" stroke="{fill}" {extra}>' + "".join(shapes) + '</g>'


def body(c, upper_col, fore_col):
    if c.bite:   # split: forearm under, bite, then the upper arm on top
        return g(c.fore, fore_col) + g([c.bite], BG) + g(c.upper, upper_col)
    return g(c.upper, upper_col) + g(c.fore, fore_col)


def detail_lines(c, width=20):
    i = uid()
    clip = f'<defs><clipPath id="{i}">' + "".join(c.line_clip or c.all_shapes()) + '</clipPath></defs>'
    stroke = f'fill="none" stroke="{INK}" stroke-width="{width}" stroke-linecap="round"'
    crease = f'<g clip-path="url(#{i})" {stroke}>' + c.lines[0] + '</g>'
    rest = f'<g {stroke}>' + "".join(c.lines[1:]) + '</g>'
    return clip + crease + rest


def shine(c, opacity=1):
    return g(c.shine, CREAM, f'stroke="none" opacity="{opacity}"')


def style_flat(c, col=Y):
    return svg(body(c, col, col))


def style_twotone(c, a=Y, b=Y_L):
    return svg(body(c, b, a))


def style_cartoon(c):
    return svg(body(c, Y, Y) + detail_lines(c) + shine(c))


def style_cel(c, shade=Y_D, off=22):
    i = uid()
    clip = f'<defs><clipPath id="{i}">' + "".join(c.all_shapes()) + '</clipPath></defs>'
    base = body(c, shade, shade)
    lit = f'<g clip-path="url(#{i})" transform="translate(-{off} -{off})">' + body(c, Y, Y) + '</g>'
    bite = g([c.bite], BG) if c.bite else ""
    return svg(clip + base + lit + bite + shine(c))


def style_gradient(c, top="#FFD170", bottom="#FF9A24"):
    i = uid()
    defs = (f'<defs><linearGradient id="{i}g" gradientUnits="userSpaceOnUse" x1="0" y1="170" x2="0" y2="870">'
            f'<stop offset="0" stop-color="{top}"/><stop offset="1" stop-color="{bottom}"/></linearGradient></defs>')
    return svg(defs + body(c, f'url(#{i}g)', f'url(#{i}g)'))


def style_glow(c):
    i = uid()
    defs = (f'<defs><linearGradient id="{i}g" gradientUnits="userSpaceOnUse" x1="300" y1="170" x2="500" y2="870">'
            f'<stop offset="0" stop-color="#FFD98A"/><stop offset="0.55" stop-color="{Y}"/><stop offset="1" stop-color="#F28A14"/></linearGradient>'
            f'<clipPath id="{i}c">' + "".join(c.all_shapes()) + '</clipPath>'
            f'<filter id="{i}f" x="-40%" y="-40%" width="180%" height="180%"><feGaussianBlur stdDeviation="36"/></filter></defs>')
    glow = f'<g filter="url(#{i}f)" opacity="0.4">' + g(c.all_shapes(), Y) + '</g>'
    rim = g(c.all_shapes(), CREAM)
    fill = (f'<g clip-path="url(#{i}c)"><g transform="translate(0 9)">' + body(c, f'url(#{i}g)', f'url(#{i}g)') + '</g></g>')
    return svg(defs + glow + rim + fill + shine(c, 0.9))


def style_offset(c, off=30):
    shadow = f'<g transform="translate({off} {off})">' + body(c, Y_DD, Y_DD) + '</g>'
    return svg(shadow + body(c, Y, Y))


def style_outline(c, t=24):
    """Yellow outline only: paint the union, then erode a copy painted in BG and lay it on top."""
    i = uid()
    defs = f'<defs><filter id="{i}e"><feMorphology operator="erode" radius="{t}"/></filter></defs>'
    inner = f'<g filter="url(#{i}e)">' + body(c, BG, BG) + '</g>'
    return svg(defs + body(c, Y, Y) + inner)


# ---------------------------------------------------------------- page
def tile(svg_markup, label, sub=""):
    return (f'<figure><div class="wrap">{svg_markup}</div>'
            f'<figcaption><b>{html.escape(label)}</b>{"<br><span>" + html.escape(sub) + "</span>" if sub else ""}</figcaption></figure>')


def small_row(c, label):
    return (f'<div class="small"><span class="lbl">{html.escape(label)}</span>'
            + "".join(svg(body(c, Y, Y), s) for s in (180, 120, 60, 40)) + '</div>')


def main():
    flex, curl, split, cur = concept_flex(), concept_curl(), concept_split(), concept_current_fixed()
    parts = []
    parts.append('<h1>Jimmy logo: style board, round 1 of the new exploration</h1>'
                 f'<p class="intro">Everything is yellow <code>{Y}</code> on black <code>{BG}</code>, the colours the iOS app uses today. '
                 'Section A asks <i>which construction</i> (how the J and the arm share one silhouette). '
                 'Section B asks <i>which rendering style</i>, shown on construction A1 so only the style changes. '
                 'These are quick sketches to choose a direction, not finished marks.</p>')

    parts.append('<h2>A. Construction: how the J and the muscle share one shape</h2><div class="grid">')
    parts.append(tile(style_flat(flex), "A1  Flex, fist up",
                      "Stem = forearm, top serif = fist curling toward the shoulder, hook = upper arm, ball terminal = shoulder, bicep rises into the bowl"))
    parts.append(tile(style_flat(curl), "A2  Bicep curl",
                      "Stem = upper arm bowing out as the bicep, hook = forearm curling up, ball terminal = fist"))
    parts.append(tile(style_flat(split), "A3  Split arm (two pieces)",
                      "A1 as two shapes with a gap at the elbow joint, Great Courses style; the gap is what says 'arm'"))
    parts.append(tile(style_flat(cur), "A4  Today's shape, re-proportioned",
                      "Same idea as the current icon: taller, narrower, smaller dome, open bowl"))
    parts.append('</div>')

    parts.append('<h2>B. Rendering style (all on A1)</h2><div class="grid">')
    parts.append(tile(style_flat(flex), "B1  Flat, one colour", "Klarna: pure silhouette, no detail"))
    parts.append(tile(style_twotone(flex), "B2  Two-tone", "Great Courses / OneNote: forearm and upper arm in two yellows, seam at the elbow"))
    parts.append(tile(style_cartoon(flex), "B3  Cartoon lines + shine", "Adult Swim: flat fill, thick dark interior lines, one highlight"))
    parts.append(tile(style_cel(flex), "B4  Cel shade + shine", "Premium cartoon: flat fill, hard shadow side, one highlight"))
    parts.append(tile(style_gradient(flex), "B5  Soft gradient", "Google Voice ceiling: one gentle gradient, nothing else"))
    parts.append(tile(style_glow(flex), "B6  Gradient + rim + glow", "Firefox Focus ceiling: the most detail allowed"))
    parts.append(tile(style_offset(flex), "B7  Hard offset shadow", "Retro sticker: flat fill with a dark copy behind"))
    parts.append(tile(style_outline(flex), "B8  Outline only", "Neon / line art: the silhouette as a thick yellow line"))
    parts.append('</div>')

    parts.append('<h2>C. Home-screen sizes (flat)</h2><p class="intro">Same marks at 180, 120, 60 and 40 px. The 60 px one is roughly an iPhone home-screen icon.</p>')
    parts.append(small_row(flex, "A1 flex"))
    parts.append(small_row(curl, "A2 curl"))
    parts.append(small_row(split, "A3 split"))
    parts.append(small_row(cur, "A4 today+"))

    parts.append('<h2>D. Which yellow</h2><p class="intro">Left is the current app colour. The others move toward a truer yellow.</p><div class="grid">')
    for col, name in [(Y, "FFB84D  current (orange-amber)"), ("#FFC53D", "FFC53D  warmer gold"),
                      ("#FFD23F", "FFD23F  true yellow"), ("#FFE14D", "FFE14D  bright lemon")]:
        parts.append(tile(style_flat(flex, col), name, ""))
    parts.append('</div>')

    page = f'''<!DOCTYPE html><html><head><meta charset="utf-8"><title>Jimmy logo style board</title>
<style>
body{{background:#15151a;color:#e8e8ee;font:15px/1.45 -apple-system,Inter,system-ui,sans-serif;margin:0;padding:28px 36px 60px;max-width:1480px}}
h1{{font-size:24px;margin:0 0 6px}} h2{{font-size:18px;margin:34px 0 10px;color:#ffd27a}}
p.intro{{color:#b7b7c4;max-width:980px;margin:0 0 14px}} code{{color:#ffb84d}}
.grid{{display:grid;grid-template-columns:repeat(4,1fr);gap:22px}}
figure{{margin:0}} .wrap svg.tile{{width:100%;height:auto;border-radius:22%;display:block}}
figcaption{{margin-top:8px;font-size:13px;color:#d6d6de}} figcaption span{{color:#9a9aa8;font-size:12px}}
.small{{display:flex;align-items:center;gap:26px;margin:10px 0}} .small .lbl{{width:90px;color:#9a9aa8;font-size:12px}}
.small svg{{border-radius:22%}}
</style></head><body>{"".join(parts)}</body></html>'''
    os.makedirs(OUT_DIR, exist_ok=True)
    with open(OUT, "w") as f:
        f.write(page)
    print("wrote", OUT, len(page), "bytes")


if __name__ == "__main__":
    main()
