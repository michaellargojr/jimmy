# News (DRAFT, flag `news`, off by default)

## Purpose

A reading corner inside Jimmy: bodybuilding news, a **top 10 of Mr. Olympia
candidates**, and a profile per athlete with their favourite exercises and videos
of how they train. Tapping a favourite exercise should eventually drop it into a
routine or the live workout.

This folder is a complete, compiling first draft of the UI and data shape so the
feature can be finished later without re-deciding the basics. **Nothing here is
reachable in the shipped app** until `FEATURES.news` is true.

## What is real and what is placeholder

| Piece | Status |
|---|---|
| Types (`types.ts`) | Real. This is the contract a data source must produce. |
| Loader (`api.ts`, `useNews.ts`) | Real. Fetches a JSON bundle, caches it in localStorage for 6 h, falls back to the bundled sample when offline or when no URL is configured. |
| Pages and components | Real UI, styled with the app theme. |
| `data/sample.ts` | **Placeholder.** Ten made-up athletes named "Sample Athlete 1..10", generic exercises, no videos. Do not mistake any of it for facts about real people. |
| Video playback | Real for YouTube (tap-to-load iframe, privacy-friendly `youtube-nocookie`). TikTok links open in the TikTok app/site because TikTok's embed needs their script. |

## Data source plan

The UI reads one JSON document shaped like `NewsBundle`. Options, in order of
effort:

1. **Hand-maintained JSON in this repo** (`public/news/bundle.json`). Zero
   infrastructure; update by committing. Good enough to start.
2. **A scheduled job** (GitHub Action, or a Claude scheduled task) that writes the
   JSON from a few sources (official Olympia site, a couple of news feeds, the
   athletes' public YouTube channels) and commits it. Keep `sources[]` on each
   record so a reader can check the claim.
3. A small API later if the app ever gets a backend.

Set the URL with `VITE_NEWS_URL` at build time (see `api.ts`). Unset means
"use the bundled sample".

## Wiring points in the main app

- `src/App.tsx`: `{FEATURES.news && newsRoutes()}` inside `<Routes>`. Already in place.
- Home needs an entry point when the feature ships: a `Link` to `/news` in the
  topbar next to the library icon.
- `AthletePage` has a "find in library" action per favourite exercise that opens
  `/library?q=<name>`. `Library.tsx` would need to read that query parameter
  (one line: `useSearchParams`).

## Open questions for the owner

- Which divisions matter: Open only, or also Classic Physique / 212?
- Should rankings be an official list (results of the last Olympia) or a
  "candidates" list that is editorial? The types support both via `Ranking.title`.
- How much offline: cache images too, or text only?
