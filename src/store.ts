/**
 * Single zustand store = in-memory mirror of IndexedDB plus a little UI state.
 *
 * Write policy (important, read before changing):
 *  - Every put/delete updates memory synchronously, then writes to Dexie
 *    fire-and-forget. The UI never waits on IndexedDB.
 *  - Writes are NOT debounced. Each set edit is a small put; Dexie serialises them
 *    per table, so order is preserved. We chose data safety over fewer writes:
 *    iOS can kill a background PWA at any moment.
 *  - If a write rejects (quota, private mode, corrupted DB) we surface it as
 *    `persistError`; App shows a banner with an Export button. Never swallow it.
 *  - Arrays are always replaced, never mutated, so src/indexes.ts can cache by
 *    identity. Use `upsert`, `filter`, spread. Never `push`/`splice` on state.
 *
 * Reading: prefer selectors (`useStore(s => s.workouts)`) over destructuring the
 * whole store, so a component only re-renders for the slices it uses.
 */
import { create } from 'zustand'
import { db, type Idea } from './db'
import { DEFAULT_SETTINGS, type Exercise, type Gym, type Routine, type Settings, type Version, type Workout } from './model'

interface State {
  loaded: boolean
  /** Set when the initial load threw (IndexedDB unavailable, upgrade failed). */
  loadError?: string
  /** Set when any background write to IndexedDB rejected. */
  persistError?: string
  /** A new service-worker build is installed and waiting; see src/pwa.ts. */
  updateReady: boolean

  exercises: Exercise[]
  versions: Version[]
  workouts: Workout[]
  routines: Routine[]
  gyms: Gym[]
  ideas: Idea[]
  settings: Settings

  load: () => Promise<void>
  reload: () => Promise<void>
  putWorkout: (w: Workout) => void
  deleteWorkout: (id: string) => void
  putRoutine: (r: Routine) => void
  deleteRoutine: (id: string) => void
  putVersion: (v: Version) => void
  putExercise: (e: Exercise) => void
  putGym: (g: Gym) => void
  putIdea: (i: Idea) => void
  deleteIdea: (id: string) => void
  setSettings: (patch: Partial<Settings>) => void
  setUpdateReady: (ready: boolean) => void
  clearPersistError: () => void
}

function upsert<T extends { id: string }>(list: T[], item: T): T[] {
  const i = list.findIndex(x => x.id === item.id)
  if (i < 0) return [...list, item]
  const next = list.slice(); next[i] = item; return next
}

function applyTheme(theme: Settings['theme']) {
  document.documentElement.dataset.theme = theme
}

function errorText(e: unknown): string {
  return e instanceof Error ? `${e.name}: ${e.message}` : String(e)
}

/** Shared promise so concurrent load() calls (React StrictMode runs effects twice in dev) seed only once. */
let loading: Promise<void> | undefined

export const useStore = create<State>((set, get) => {
  /** Fire-and-forget write with error surfacing. Every DB mutation goes through here. */
  const persist = (p: Promise<unknown>) => { p.catch(e => set({ persistError: errorText(e) })) }

  const doLoad = async () => {
    try {
      let settings = await db.settings.get('settings')
      if (!settings || !settings.seeded) {
        const count = await db.workouts.count()
        if (count === 0) {
          // Seed data is only needed on a fresh install, so it stays out of the main bundle.
          const { buildSeed } = await import('./seed')
          const s = buildSeed()
          await db.transaction('rw', [db.exercises, db.versions, db.workouts, db.routines, db.gyms], async () => {
            await db.exercises.bulkPut(s.exercises)
            await db.versions.bulkPut(s.versions)
            await db.workouts.bulkPut(s.workouts)
            await db.routines.bulkPut(s.routines)
            await db.gyms.bulkPut(s.gyms)
          })
        }
        settings = { ...(settings ?? DEFAULT_SETTINGS), seeded: true }
        await db.settings.put(settings)
      }
      await get().reload()
    } catch (e) {
      set({ loadError: errorText(e), loaded: true })
    }
  }

  return {
    loaded: false,
    updateReady: false,
    exercises: [], versions: [], workouts: [], routines: [], gyms: [], ideas: [],
    settings: DEFAULT_SETTINGS,

    load: () => (loading ??= doLoad()),

    reload: async () => {
      const [exercises, versions, workouts, routines, gyms, ideas, settings] = await Promise.all([
        db.exercises.toArray(), db.versions.toArray(), db.workouts.toArray(), db.routines.toArray(), db.gyms.toArray(), db.ideas.toArray(), db.settings.get('settings'),
      ])
      const s = settings ?? DEFAULT_SETTINGS
      set({ exercises, versions, workouts, routines, gyms, ideas, settings: s, loaded: true, loadError: undefined })
      applyTheme(s.theme)
    },

    putWorkout: w => { set(s => ({ workouts: upsert(s.workouts, w) })); persist(db.workouts.put(w)) },
    deleteWorkout: id => { set(s => ({ workouts: s.workouts.filter(w => w.id !== id) })); persist(db.workouts.delete(id)) },
    putRoutine: r => { set(s => ({ routines: upsert(s.routines, r) })); persist(db.routines.put(r)) },
    deleteRoutine: id => { set(s => ({ routines: s.routines.filter(r => r.id !== id) })); persist(db.routines.delete(id)) },
    putVersion: v => { set(s => ({ versions: upsert(s.versions, v) })); persist(db.versions.put(v)) },
    putExercise: e => { set(s => ({ exercises: upsert(s.exercises, e) })); persist(db.exercises.put(e)) },
    putGym: g => { set(s => ({ gyms: upsert(s.gyms, g) })); persist(db.gyms.put(g)) },
    putIdea: i => { set(s => ({ ideas: upsert(s.ideas, i) })); persist(db.ideas.put(i)) },
    deleteIdea: id => { set(s => ({ ideas: s.ideas.filter(i => i.id !== id) })); persist(db.ideas.delete(id)) },
    setSettings: patch => {
      const settings = { ...get().settings, ...patch }
      set({ settings }); persist(db.settings.put(settings))
      applyTheme(settings.theme)
    },
    setUpdateReady: ready => set({ updateReady: ready }),
    clearPersistError: () => set({ persistError: undefined }),
  }
})
