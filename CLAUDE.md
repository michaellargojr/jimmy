# Jimmy: notes for AI coding assistants

Read this before touching the code. It is short on purpose; the longer story is in
`docs/ARCHITECTURE.md` and the audit that shaped the current code is in
`docs/REVIEW-2026-11.md`.

## What this is

A personal gym logger for one iPhone, installed as a PWA from GitHub Pages.
React 18 + TypeScript + Vite. State is a zustand store mirrored to IndexedDB via
Dexie. No backend, no accounts, no analytics. About 3k lines including drafts.

## Commands

```bash
pnpm install
pnpm dev            # http://localhost:5173, service worker is NOT registered in dev
pnpm check          # typecheck + lint + tests. Run this before every commit.
pnpm build          # typecheck, then vite build into dist/
pnpm test:watch
```

CI (`.github/workflows/pages.yml`) runs lint, tests and build, then deploys `dist/`.

## Where things live

| Path | What |
|---|---|
| `src/model.ts` | Domain types + tiny pure helpers (`uid`, `today`, `fmtSet`). Everything persisted is defined here. |
| `src/db.ts` | Dexie schema with version history, JSON export/import, `normalizeSnapshot`. |
| `src/store.ts` | The zustand store. Read its header: write policy, error surfacing, "replace arrays, never mutate". |
| `src/indexes.ts` | Memoised lookups (history by version, version by id). Use these instead of `find`/`sort` in components. |
| `src/derive.ts` | Questions about history: last session, last bar, last routine run. O(1) via indexes. |
| `src/grouping.ts` | Pure superset/triset list arithmetic shared by planner and live workout. |
| `src/workout.ts` | Build a workout from a routine, default sets, labels, panes. |
| `src/overload.ts` | Up / down / improved rules. Keep in sync with README "Signals". |
| `src/pages/*` | One file per route. `Home` and `Live` load eagerly, the rest are lazy (`src/lazy.ts`). |
| `src/components/*` | Shared UI. `useHold.ts` and `SwipeRow.tsx` hold the gesture logic. |
| `src/seed/*` | One-time Notion import. Dynamically imported, never in the main bundle. |
| `src/features/*` | Drafts behind flags (`flags.ts`). See `src/features/README.md`. |
| `src/pwa.ts`, `public/sw.js`, `vite.config.ts` | Offline cache + user-controlled updates. |
| `*.test.ts` next to the code | Vitest. Pure modules are fully covered; UI is smoke-tested by hand or Playwright. |

## Rules that keep the app glitch-free

1. **Replace, never mutate** store arrays (`upsert`, `filter`, spread). `src/indexes.ts`
   caches by array identity; a mutation would serve stale derived data.
2. **Derive through `indexes.ts` / `derive.ts`.** Never sort or scan `workouts` inside a
   component or a loop. If you need a new "all workouts" view, add it to the index.
3. **Read the store with selectors**: `useStore(s => s.workouts)`. Destructuring the whole
   store re-renders the component on every write (and Live writes on every set edit).
4. **Timers live in leaf components.** `<Timer>` owns its interval. Never `setInterval` ->
   `setState` in a page; it re-renders every card every tick.
5. **Declare components at module level.** A component defined inside another component is a
   new type each render and gets remounted (lost focus, flicker). `VersionSheet.Stepper` was
   that bug.
6. **Every DB write goes through `persist()`** in the store so failures surface in the UI.
   No bare `void db.x.put()`.
7. **Schema changes need three things**: a new `this.version(N)` block in `db.ts` (never edit
   old ones), `normalizeSnapshot` handling the old JSON shape, `SNAPSHOT_VERSION` bumped.
8. **Gesture constants are shared.** `HOLD_MS`, `HOLD_TOLERANCE` in `useHold.ts`;
   `DRAG_DELAY_MS` in `Plan.tsx` must stay well below `HOLD_MS`. Swipe intent thresholds in
   `SwipeRow.tsx`. Change one, test all three gestures on a real phone.
9. **Drafts stay behind `FEATURES.<flag>`** and behind `React.lazy`. The main app imports at
   most one tiny entry file per feature.
10. **No new runtime dependency without a bundle note** in the PR/commit. The app is 314 KB
    of JS today (103 KB gz); dexie and react-dom are most of it.
11. **Dates** are local `YYYY-MM-DD` strings (`today()`), never `Date.toISOString()` which is
    UTC and flips the day in the evening in Davao (UTC+8).
12. **Text style**: no em dashes anywhere (UI, docs, commits). Use "-" or "·".

## How to add things

- **A page**: create `src/pages/X.tsx`, export a named component, add
  `const X = lazyPage(() => import('./pages/X').then(m => ({ default: m.X })))` and a `<Route>`
  in `App.tsx`. Use `className="page"` and the `topbar` pattern from an existing page.
- **A field on a model**: optional field -> just add it in `model.ts`. Required field ->
  rule 7 above, plus update `buildSeed` and the tests in `db.test.ts` / `seed.test.ts`.
- **A derived view** (e.g. "volume per week"): add to `indexes.ts` (build it inside
  `buildHistory`), expose a small function in `derive.ts`, test in `derive.test.ts`.
- **A sheet / dialog**: use `<Sheet open onClose title>`. It portals to `body`, locks body
  scroll, closes on Escape, ignores backdrop taps for 400 ms after opening.
- **A gesture**: look at `useHold` and `SwipeRow` first; do not add a third timing system.

## Things that look wrong but are deliberate

- `Plan.tsx` dispatches a synthetic Escape keydown to cancel a dnd-kit drag when the
  still-hold fires. dnd-kit has no public cancel API; this is the documented workaround.
- `Sheet` ignores backdrop clicks for 400 ms: iOS fires a click on lift after a long press,
  which would close the sheet the hold just opened. `swallowNextClick()` exists for the
  same reason.
- `WheelPicker` has a 250 ms "settle" window after mount so programmatic positioning does
  not commit a value. Without it every opened wheel wrote the hint into the set.
- Store writes are not debounced on purpose (iOS can kill a background PWA any time).
- `index.html` has `user-scalable=no`: iOS ignores it for accessibility zoom but it stops
  double-tap zoom on buttons.
- `historyIndex` recomputes on every workout write. That is a sort of ~10-500 workouts and
  a linear pass over their items; it is far cheaper than what it replaced and keeps the API
  simple. Revisit only if a profile shows it.
- Gym names are displayed with the `Ultradynamic Fitness - ` prefix stripped (owner's two
  gyms share it). Cosmetic.

## Deploy and updates

Push to `main`/`master`/`claude/**` runs the Pages workflow. A new build changes the
service worker's cache name; the installed app shows "A new version is ready" on Home and
installs it on tap (`src/pwa.ts`). Do not reintroduce `self.skipWaiting()` in `install`;
see the header of `public/sw.js` for why.
