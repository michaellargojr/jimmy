import Dexie, { type Table } from 'dexie'
import type { Exercise, Gym, Routine, Settings, Version, Workout } from './model'

export interface Idea {
  id: string; kind: 'bug' | 'feature'; text: string; createdAt: number; page?: string; done?: boolean
  /** Set once the idea has been filed as a GitHub issue. */
  issue?: number; issueUrl?: string; closedAt?: number
}

export class JimmyDB extends Dexie {
  exercises!: Table<Exercise, string>
  versions!: Table<Version, string>
  workouts!: Table<Workout, string>
  routines!: Table<Routine, string>
  gyms!: Table<Gym, string>
  settings!: Table<Settings, string>
  ideas!: Table<Idea, string>
  constructor() {
    super('jimmy')
    this.version(1).stores({
      exercises: 'id, name',
      versions: 'id, exerciseId, name',
      workouts: 'id, date',
      routines: 'id',
      gyms: 'id',
      settings: 'id',
      ideas: 'id, createdAt',
    })
  }
}

export const db = new JimmyDB()

export interface Snapshot {
  version: 1
  exportedAt: string
  exercises: Exercise[]; versions: Version[]; workouts: Workout[]; routines: Routine[]; gyms: Gym[]; settings: Settings | undefined; ideas: Idea[]
}

export async function exportSnapshot(): Promise<Snapshot> {
  const [exercises, versions, workouts, routines, gyms, settings, ideas] = await Promise.all([
    db.exercises.toArray(), db.versions.toArray(), db.workouts.toArray(), db.routines.toArray(), db.gyms.toArray(), db.settings.get('settings'), db.ideas.toArray(),
  ])
  return { version: 1, exportedAt: new Date().toISOString(), exercises, versions, workouts, routines, gyms, settings, ideas }
}

export async function importSnapshot(s: Snapshot): Promise<void> {
  await db.transaction('rw', [db.exercises, db.versions, db.workouts, db.routines, db.gyms, db.settings, db.ideas], async () => {
    await Promise.all([db.exercises.clear(), db.versions.clear(), db.workouts.clear(), db.routines.clear(), db.gyms.clear(), db.ideas.clear()])
    await db.exercises.bulkPut(s.exercises)
    await db.versions.bulkPut(s.versions)
    await db.workouts.bulkPut(s.workouts)
    await db.routines.bulkPut(s.routines)
    await db.gyms.bulkPut(s.gyms)
    await db.ideas.bulkPut(s.ideas ?? [])
    if (s.settings) await db.settings.put({ ...s.settings, seeded: true })
  })
}
