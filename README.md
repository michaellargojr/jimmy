# Jimmy

A gym logger built for one person's workflow: minimal taps, no typing except search, last time always visible next to today's entry, and clear go-up / go-down signals.

Mobile-first PWA (iPhone). Data lives on the device (IndexedDB) and can be exported as JSON at any time.

## Run

```
pnpm install
pnpm dev        # local dev server
pnpm test       # overload rules
pnpm build      # dist/ ready to host anywhere (relative paths)
```

## Install on iPhone

Open the hosted URL in Safari, tap Share, then **Add to Home Screen**. Standalone web apps keep their storage; a plain Safari tab may evict it after a week of non-use. Export JSON after workouts until sync exists.

## Hosting

`.github/workflows/pages.yml` deploys `dist/` to GitHub Pages on every push to the default branch once Settings → Pages → Source is set to **GitHub Actions**.

## How it works

- **Routine** = ordered list of exercise versions plus groups (superset, triset, circuit). Home shows each routine, when it was last done, and what was added on the fly last time.
- **Version** is what carries history (Cable Shrug vs Dumbbell Shrug). Rep range, default sets, warm-up, equipment, one/two hands are per version. Small cable-height or bench-angle tweaks do not create a new version.
- **Live** is a vertical pager: one full-screen card per exercise or per group. Last time is faded above today's blank rows. Weight and reps use wheel pickers. `+` means "at least". `p2` means two partials. One-arm versions get L/R rows. Barbell versions get an EZ/BAR chip prefilled from last time.
- **Signals**: subtle red dot when set 1 is under the rep range. Green glow and a short sound when set 1 ≥ max+2 and set 2 ≥ max−1 (on 5-8: 10 then 7+). Green check per set when it beats the same set last time. Nothing else.
- **Overview** (⠿): drag to reorder, tap "Group…", pick 2+ rows, make a superset/triset/circuit, or split one.
- **Add on the fly**: `+` anywhere, type two letters, tap. Library of ~120 movements plus your own versions.
- **Setup per session**: the chip under each exercise name on the live card records how it was set up today: cable height picked on a tappable silhouette (floor, knee, hip, waist, chest, shoulder, overhead), bench angle, and attachment from a dropdown (rope, V-bar, straight bar… plus any name you add once). Last time's setup shows in the faded "last time" block and is carried into the next session automatically, so the trend is visible per exercise (Exercises → tap one → "Setup trend").
- **Version details**: usual setup (starting point for a new session), machine, a video link (TikTok or anything), and a note per gym (seat, pin, which machine). Every edit is logged in the version's change history.
- **💡**: capture a bug or change idea in two taps. Saved in the app. From Settings either **Send to GitHub** (each idea becomes an issue labelled bug or feature, which Claude reads straight from the repo) or **copy for Claude** and paste into chat. Marking an idea done closes its issue on the next send.
- **Apple Notes import**: Settings → *Import a workout from Apple Notes*. Paste lines like `Incline Chest Fly Machine` then `15kg - warm up - 10+`, `20kg - 8`, `22.5kg - 6 p2 (3rd notch)`. Also understands `L 10kg - 12 / R 10kg - 11`, `EZ 30 x 8`, `45lb x 10`, `bw 15`, a date line (`2026-10-20` or `Oct 20`), and a title line. Unknown exercises are created with a guessed muscle and equipment.
- **Themes**: dark, light, paper, steel (metallic), airy (white space).

## Data

Seeded once from the Notion workout log (Aug 3 to Oct 15, 2026). The app never talks to Notion. Settings → Export gives a single JSON with everything, Import restores it.

The only thing that ever leaves the phone is the optional GitHub sync of 💡 ideas. It needs a fine-grained personal access token scoped to this one repository with Issues read and write; the token is stored in the app's database on the phone and sent only to api.github.com.

## Roadmap

Done in v0.2: cable-height slider, bench-angle picker and icons, version change log, gym-specific notes, Apple Notes importer, TikTok/video link per version, metallic and white-space themes, ideas → GitHub issues.

1. Claude connection: MCP server over the same JSON, so Claude can add routines, add exercises by dictation, and analyze history.
2. Local video clips that play instantly (the link per version is in; offline clips are not).
3. Machine photo → Claude names the machine and creates the version.
4. Desktop app that syncs with the phone: planning, trends, review, and Claude living inside the app ("Jimmy" the assistant, which eventually replaces the light bulb on mobile too).
