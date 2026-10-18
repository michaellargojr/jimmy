import { create } from 'zustand'
import { db, type Idea } from './db'
import { DEFAULT_SETTINGS, type Exercise, type Gym, type Routine, type Settings, type Version, type Workout } from './model'
import { buildSeed } from './seed'

interface State {
  loaded: boolean
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
}

function upsert<T extends { id: string }>(list: T[], item: T): T[] {
  const i = list.findIndex(x => x.id === item.id)
  if (i < 0) return [...list, item]
  const next = list.slice(); next[i] = item; return next
}

export const useStore = create<State>((set, get) => ({
  loaded: false,
  exercises: [], versions: [], workouts: [], routines: [], gyms: [], ideas: [],
  settings: DEFAULT_SETTINGS,

  load: async () => {
    let settings = await db.settings.get('settings')
    if (!settings || !settings.seeded) {
      const count = await db.workouts.count()
      if (count === 0) {
        const s = buildSeed()
        await db.transaction('rw', [db.exercises, db.versions, db.workouts, db.routines, db.gyms, db.settings], async () => {
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
  },

  reload: async () => {
    const [exercises, versions, workouts, routines, gyms, ideas, settings] = await Promise.all([
      db.exercises.toArray(), db.versions.toArray(), db.workouts.toArray(), db.routines.toArray(), db.gyms.toArray(), db.ideas.toArray(), db.settings.get('settings'),
    ])
    set({ exercises, versions, workouts, routines, gyms, ideas, settings: settings ?? DEFAULT_SETTINGS, loaded: true })
    document.documentElement.dataset.theme = (settings ?? DEFAULT_SETTINGS).theme
  },

  putWorkout: w => { set(s => ({ workouts: upsert(s.workouts, w) })); void db.workouts.put(w) },
  deleteWorkout: id => { set(s => ({ workouts: s.workouts.filter(w => w.id !== id) })); void db.workouts.delete(id) },
  putRoutine: r => { set(s => ({ routines: upsert(s.routines, r) })); void db.routines.put(r) },
  deleteRoutine: id => { set(s => ({ routines: s.routines.filter(r => r.id !== id) })); void db.routines.delete(id) },
  putVersion: v => { set(s => ({ versions: upsert(s.versions, v) })); void db.versions.put(v) },
  putExercise: e => { set(s => ({ exercises: upsert(s.exercises, e) })); void db.exercises.put(e) },
  putGym: g => { set(s => ({ gyms: upsert(s.gyms, g) })); void db.gyms.put(g) },
  putIdea: i => { set(s => ({ ideas: upsert(s.ideas, i) })); void db.ideas.put(i) },
  deleteIdea: id => { set(s => ({ ideas: s.ideas.filter(i => i.id !== id) })); void db.ideas.delete(id) },
  setSettings: patch => {
    const settings = { ...get().settings, ...patch }
    set({ settings }); void db.settings.put(settings)
    document.documentElement.dataset.theme = settings.theme
  },
}))
