# Jimmy logo exploration

The brief: one mark on black, in the app's yellow (`#FFB84D` on `#0A0A0D`), that reads as a
capital **J** to some people and as a **flexing muscle** to others. Hardcore-cartoon character,
simple enough to be a flat vector app icon.

Style decided early (round 1): **cel shade + shine** as the primary look, with **soft gradient**
and **gradient + rim + glow** as the other two keepers. The shape is what the rounds explore.

## Rounds

Each round is a folder under `rounds/` with `index.html` (the contact sheet, every mark also at
home-screen sizes), `sheet.png` (a 2x screenshot of it) and, from round 3 on, `svg/` with one
standalone 1024 px SVG per mark.

| Round | What it asked | Outcome |
|---|---|---|
| `round-1-styles` | Four constructions and eight rendering styles on a quick shape | Styles chosen; shapes rejected |
| `round-3-concepts` | Thirty different concepts (bubble, cartoon arm, negative space, geometric, angular, props, brush) | All rejected: tubes with lumps read as gummy worms |
| `round-4-marks` | Nine marks drawn as heavy geometric letters, the muscle as one deliberate deviation | Awaiting picks |

(Round 2 was an internal pass that was never shown.)

## Generator

`generator/` holds the Python that draws every mark and the page around it.

- `round3_concepts.py` also serves as the library: signed-distance primitives (`circle`,
  `capsule`, `arc`, `box`, `plane`) sampled on a 3 px grid with numpy, smooth union and
  subtraction (`smin`/`smax` with a per-join fillet `k`: small is crisp, large is gooey),
  marching squares (`contours`), Chaikin smoothing, closed-loop simplification and one SVG path
  per shape; `Concept` objects carry layers (each cel-shaded: shade fill plus an offset lit copy
  clipped to the shape), shine ellipses, overlays and an optional italic shear.
- `round4_marks.py` draws the letter-based marks: a flat-topped stem, a hook whose outer edge sits
  on a true circle while its stroke thins toward the terminal, and the bicep as a soft union of two
  circles kept a crease's width away from the stem.
- `brush.py` is an older spine-and-width generator used by two round-3 concepts.
- `round1_styles.py` is the first style board.
- `render.cjs` screenshots a sheet with the pre-installed Playwright Chromium; `make.sh` rebuilds
  everything.

```bash
cd design/logo/generator && ./make.sh
```

## Where the logo is used

- iOS app icon sets: `ios/Jimmy/Assets.xcassets/AppIcon*.appiconset/icon-1024{,-dark,-tinted}.png`
  (orange primary, Mint / Ice / Red / Crimson alternates that follow the Settings colour).
- The tab bar's Workout tile draws the same mark as a SwiftUI path: `JLogo` in
  `ios/Jimmy/Views/TabBar.swift`.
- Web app icons: `public/icons/icon-192.png` and `icon-512.png` (still the old placeholder).

None of these are touched until a mark wins.
