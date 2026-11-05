/**
 * Persistence: one Dexie (IndexedDB) database, one table per model type, plus the
 * JSON snapshot format used by Export / Import.
 *
 * Schema history (never edit an old version block; add a new one):
 *  v1  initial tables.
 *  v2  routines.items[] gained a stable `id` (see RoutineItem in model.ts).
 *      No index changes, so no stores() call; the upgrade back-fills ids.
 *
 * How to add a migration: `this.version(N).stores({...changed tables only...})
 * .upgrade(tx => ...)`. Dexie inherits unchanged tables from the previous version.
 * Then teach normalizeSnapshot() the same change so old JSON exports import.
 */
import Dexie, { type Table } from 'dexie'
import type { Exercise, Gym, Routine, RoutineItem, Settings, Version, Workout } from './model'
import { uid } from './model'

export interface Idea { id: string; kind: 'bug' | 'feature'; text: string; createdAt: number; page?: string; done?: boolean }

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
    this.version(2).upgrade(tx =>
      tx.table('routines').toCollection().modify((r: Routine) => { r.items = withItemIds(r.items) }),
    )
  }
}

export const db = new JimmyDB()

/** Back-fill RoutineItem.id for data written before DB v2. Idempotent. */
export function withItemIds(items: Array<Partial<RoutineItem> & { versionId: string }>): RoutineItem[] {
  return items.map(it => ({ id: it.id ?? uid(), versionId: it.versionId, groupId: it.groupId }))
}

/** Bump when the snapshot shape changes; normalizeSnapshot must accept every older version. */
export const SNAPSHOT_VERSION = 2

export interface Snapshot {
  version: number
  exportedAt: string
  exercises: Exercise[]; versions: Version[]; workouts: Workout[]; routines: Routine[]; gyms: Gym[]; settings: Settings | undefined; ideas: Idea[]
}

export async function exportSnapshot(): Promise<Snapshot> {
  const [exercises, versions, workouts, routines, gyms, settings, ideas] = await Promise.all([
    db.exercises.toArray(), db.versions.toArray(), db.workouts.toArray(), db.routines.toArray(), db.gyms.toArray(), db.settings.get('settings'), db.ideas.toArray(),
  ])
  return { version: SNAPSHOT_VERSION, exportedAt: new Date().toISOString(), exercises, versions, workouts, routines, gyms, settings, ideas }
}

/**
 * Validate an untrusted parsed JSON value and upgrade it to the current snapshot
 * shape. Throws an Error with a human-readable message on anything unusable; the
 * Settings page shows that message.
 */
export function normalizeSnapshot(raw: unknown): Snapshot {
  if (!raw || typeof raw !== 'object') throw new Error('Not a JSON object')
  const s = raw as Record<string, unknown>
  const arr = <T,>(key: string, required: boolean): T[] => {
    const v = s[key]
    if (v == null) { if (required) throw new Error(`Missing "${key}"`); return [] }
    if (!Array.isArray(v)) throw new Error(`"${key}" is not a list`)
    return v as T[]
  }
  const version = typeof s.version === 'number' ? s.version : 1
  if (version > SNAPSHOT_VERSION) throw new Error(`This export is from a newer Jimmy (format ${version}); update the app first`)
  const routines = arr<Routine>('routines', true).map(r => ({ ...r, items: withItemIds(r.items ?? []), groups: r.groups ?? [] }))
  return {
    version: SNAPSHOT_VERSION,
    exportedAt: typeof s.exportedAt === 'string' ? s.exportedAt : new Date().toISOString(),
    exercises: arr<Exercise>('exercises', true),
    versions: arr<Version>('versions', true),
    workouts: arr<Workout>('workouts', true),
    routines,
    gyms: arr<Gym>('gyms', false),
    settings: s.settings && typeof s.settings === 'object' ? (s.settings as Settings) : undefined,
    ideas: arr<Idea>('ideas', false),
  }
}

/** Replace everything with the snapshot. Runs in one transaction: either all of it lands or none of it does. */
export async function importSnapshot(s: Snapshot): Promise<void> {
  await db.transaction('rw', [db.exercises, db.versions, db.workouts, db.routines, db.gyms, db.settings, db.ideas], async () => {
    await Promise.all([db.exercises.clear(), db.versions.clear(), db.workouts.clear(), db.routines.clear(), db.gyms.clear(), db.ideas.clear()])
    await db.exercises.bulkPut(s.exercises)
    await db.versions.bulkPut(s.versions)
    await db.workouts.bulkPut(s.workouts)
    await db.routines.bulkPut(s.routines)
    await db.gyms.bulkPut(s.gyms)
    await db.ideas.bulkPut(s.ideas)
    if (s.settings) await db.settings.put({ ...s.settings, id: 'settings', seeded: true })
  })
}
