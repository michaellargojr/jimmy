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
- **💡**: capture a bug or change idea in two taps. Saved in the app; copy the list for Claude from Settings.

## Data

Seeded once from the Notion workout log (Aug 3 to Oct 15, 2026). The app never talks to Notion. Settings → Export gives a single JSON with everything, Import restores it.

## Roadmap

1. Cable-height silhouette slider and bench-angle picker per version, with mini icons on the card; version change log; gym-specific notes.
2. Paste-an-Apple-Note importer (`15kg - warm up - 10+` format).
3. Claude connection: MCP server over the same JSON, so Claude can add routines, add exercises by dictation, and analyze history.
4. TikTok link per version and local video clips that play instantly.
5. Machine photo → Claude names the machine and creates the version.
6. Desktop app that syncs with the phone: planning, trends, review, and Claude living inside the app ("Jimmy" the assistant, which eventually replaces the light bulb on mobile too).
7. More themes (metallic, high white space).
