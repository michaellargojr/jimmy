# Jimmy architecture

## 1. Shape of the app

```
index.html ─ main.tsx ─ <ErrorBoundary> ─ <HashRouter> ─ App.tsx
                                                          ├─ Home (eager)
                                                          ├─ Live (eager)        ← the hot path
                                                          ├─ Plan, OverviewPage  (lazy, pull in dnd-kit)
                                                          ├─ Library, Settings   (lazy)
                                                          └─ features/* routes   (lazy, flag-gated)

store.ts (zustand)  ⇄  db.ts (Dexie / IndexedDB)
      │
      └─ indexes.ts (memoised views) ─ derive.ts (questions) ─ components
```

- **Routing** is hash-based so GitHub Pages needs no rewrite rules and the app works from
  `file://` or any static host.
- **State** is one zustand store holding plain arrays of every record type plus a little UI
  state (`updateReady`, `persistError`). On startup `load()` reads everything from Dexie into
  memory; after that, components read memory and every mutation writes through to Dexie.
- **No network calls** in the shipped app except the service worker fetching its own assets.

## 2. Data model

```
Exercise ──< Version ──< WorkoutItem ──< SetEntry
   │            │             │
   │            │             └── Workout ──< Group
   │            └── RoutineItem ──< Routine ──< Group
   └── muscleGroup
```

| Type | Identity | Notes |
|---|---|---|
| `Exercise` | `id` | A movement. Only for grouping (muscle) and search (aliases). |
| `Version` | `id` | What you log. Rep range, default sets, equipment, arms. History hangs here. |
| `Routine` | `id` | Template: ordered `RoutineItem[]` (`id`, `versionId`, `groupId?`) + `Group[]`. |
| `Workout` | `id` | One session. `date` (local YYYY-MM-DD), `startedAt`/`endedAt` epoch ms. In progress = started and not ended. |
| `WorkoutItem` | `id` | One exercise inside a workout, with its `SetEntry[]`. |
| `SetEntry` | `id` | `reps == null` means not logged. `plus` = "at least", `partials`, `side` (L/R), `bar` (EZ/straight). |
| `Group` | `id` | `superset` / `triset` / `circuit`. Membership is `groupId` on items. |
| `Settings` | `'settings'` | Singleton row: unit, theme, sound, seeded flag. |
| `Idea` | `id` | Bug / feature notes captured from the 💡 button. |

Grouping invariants (enforced by `src/grouping.ts`): members of a group are consecutive;
an item that no longer touches a member of its group leaves it; groups with no members
are dropped.

## 3. Storage

- **Dexie** database `jimmy`. Schema versions are declared in order in `db.ts` and never
  edited after shipping. v2 added `RoutineItem.id` with an upgrade that back-fills ids.
- **Export/Import** is one JSON `Snapshot` with every table. `normalizeSnapshot()` validates
  untrusted input and upgrades old shapes; `importSnapshot()` replaces everything inside one
  transaction so a failed import leaves the old data intact.
- **Seeding**: on first launch (`settings.seeded` false and zero workouts) `store.load()`
  dynamically imports `src/seed` and writes the Notion history. `load()` is guarded by a
  shared promise so React StrictMode's double effect run cannot seed twice.
- **Failure modes** are surfaced, not swallowed: `loadError` (storage unavailable) renders a
  dedicated screen; `persistError` (a background write failed) renders a sticky banner with
  an Export button. The `ErrorBoundary` catches render exceptions and offers export/reload.

## 4. Core flows

**Start a workout**: Plan -> `workoutFromRoutine()` copies routine items into a new
`Workout` with empty `SetEntry` rows from `defaultSets()` (warm-up if the version wants one,
N working sets, L/R pairs for one-arm versions, bar remembered from history). `startedAt` is
set, the workout is `putWorkout`-ed and the app navigates to `/workout/:id`.

**Edit a set**: tap a field -> `ExerciseCard` opens the wheel `Sheet`, snapshotting the set
in `editOrig`. Each settled wheel value -> `patchSet` -> `onChange(item)` -> `putWorkout`
(memory + Dexie). Backdrop tap restores the snapshot; Done keeps it. `verdict()` runs on each
render; on the first transition to `up` the card glows and `ding()` plays.

**Finish**: End sheet -> `putWorkout({ ...w, endedAt, notes })` -> Home. Home orders routines
by `lastFinishedByRoutine` and lists the eight most recent finished workouts.

**Resume**: Home redirects into an in-progress workout unless the user left it with the ‹
button (`sessionStorage['jimmy.left']`). Live restores the pane you were on from
`localStorage['jimmy.pane.<id>']`.

## 5. Derived data and performance model

The store keeps arrays because they are trivial to persist and export. Everything that
would be a join or a sort lives in `src/indexes.ts`:

- `historyIndex(workouts)`: workouts newest-first, occurrences per version (with/without
  data), newest finished workout per routine, the active workout.
- `versionIndex(versions)`: by id, siblings by exercise.
- `exerciseIndex(exercises)`: by id.

Each is cached in a `WeakMap` keyed by the array object. The store replaces arrays on
every write, so identity equality means content equality and no manual invalidation is
needed. Cost: one O(n log n) sort + linear pass per write of the workouts array; every read
afterwards is a map lookup. Before this existed, `lastSession()` sorted all workouts on
every call and was called per set row per render per second on the Live page.

Other hot-path rules: timers in leaf components (`<Timer>`), scroll handlers that only touch
storage after a debounce, store selectors instead of whole-store subscriptions, wheel values
built once at module level, lazy routes for anything that pulls in dnd-kit.

## 6. Gestures (touch)

| Where | Gesture | Mechanism | Tunables |
|---|---|---|---|
| Plan rows | tap | `SwipeRow.onClick` when not open | |
| Plan rows | swipe left to delete | `SwipeRow`: decide axis after 10 px, x must beat y by 1.5x | `INTENT_PX`, `INTENT_RATIO`, `OPEN_W` |
| Plan rows, Overview | hold 180 ms then move = drag | dnd-kit `TouchSensor` | `DRAG_DELAY_MS` (Plan), 120 ms (Overview) |
| Plan rows, ExerciseCard header | hold 1.5 s still = options | `useHold` | `HOLD_MS`, `HOLD_TOLERANCE` |
| Sheets | tap outside = close/cancel | `Sheet` backdrop, ignored for 400 ms after open | `IGNORE_BACKDROP_MS` |
| Wheel | scroll, settle, tap | CSS scroll-snap + 90 ms debounce + 250 ms mount settle | `COMMIT_DEBOUNCE_MS`, `SETTLE_MS`, `H` |

iOS specifics handled: synthesized click after a long press (`swallowNextClick`), audio
context must be unlocked in a gesture (`installAudioUnlock`), `100dvh` for the pager,
`env(safe-area-inset-*)` paddings.

## 7. Offline and updates

`public/sw.js` is stamped at build time by the `swStamp` Vite plugin with a version hash
and the list of emitted assets. Install precaches the shell + all chunks, so lazy routes work
offline from the first launch. Navigations are network-first (new deploys are noticed),
assets cache-first. A new worker waits; `src/pwa.ts` flips `updateReady`, Home shows a
banner, tapping it posts `SKIP_WAITING`, the worker activates, `controllerchange` reloads.
`src/lazy.ts` reloads once if a chunk fails to load (stale page after a deploy).

## 8. Testing

- `pnpm test`: Vitest over the pure modules (`grouping`, `indexes`/`derive`, `workout`,
  `overload`, `db` normalisation, seed parser, **seed integrity**). The seed test is the one
  that stops a typo in `notion.ts` from blanking the app on first launch.
- UI: no component tests yet. A Playwright smoke script was used during the November 2026
  review (load, seed, Plan, Live, wheel edit, reload persistence, lazy pages, flags). Adding
  it under `e2e/` with `@playwright/test` is the natural next step.

## 9. Drafts

`src/features/` holds code that compiles but is not reachable until its flag is on.
Each folder has a README with purpose, status, placeholder markers and wiring points.
Current: `news` (Mr. Olympia top 10, athlete profiles, videos) and `pose3d` (start/end
exercise animation on the card).
