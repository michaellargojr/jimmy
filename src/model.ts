/**
 * Domain model. Plain data, no classes, no methods: everything here is what gets
 * written to IndexedDB (src/db.ts) and exported as JSON (Settings -> Export).
 *
 * Vocabulary (see docs/ARCHITECTURE.md for the longer version):
 *  - Exercise  = a movement ("Lat Pulldown"). Only used for grouping/search.
 *  - Version   = the thing you actually log ("One-Arm Lat Pulldown"). History,
 *                rep range, default sets, equipment all hang off the Version.
 *  - Routine   = an ordered template of Versions (+ superset/triset groups).
 *  - Workout   = one session. Created from a Routine or ad hoc. Owns its items.
 *  - SetEntry  = one row in a workout item. `reps == null` means not logged yet.
 *
 * Rules for editing this file:
 *  - Adding an OPTIONAL field is free. Adding a REQUIRED field or renaming one
 *    needs a Dexie upgrade in src/db.ts AND a normalizer in normalizeSnapshot so
 *    old JSON exports still import. Bump SNAPSHOT_VERSION in src/db.ts.
 *  - Keep everything JSON-serialisable (no Date, Map, Set, class instances).
 */

export type Equipment = 'cable' | 'machine' | 'dumbbell' | 'barbell' | 'ezbar' | 'smith' | 'bodyweight'
export type Arms = 'two' | 'one'
export type Unit = 'kg' | 'lbs'
export type Side = 'L' | 'R'
export type Bar = 'ez' | 'straight'
export type GroupType = 'superset' | 'triset' | 'circuit'
export type MuscleGroup =
  | 'Back' | 'Abs' | 'Chest' | 'Shoulders' | 'Triceps' | 'Biceps' | 'Forearms' | 'Calves' | 'Legs' | 'Glutes'

export const MUSCLES: MuscleGroup[] = ['Back', 'Abs', 'Chest', 'Shoulders', 'Triceps', 'Biceps', 'Forearms', 'Calves', 'Legs', 'Glutes']
export const EQUIPMENT: Equipment[] = ['cable', 'machine', 'dumbbell', 'barbell', 'ezbar', 'smith', 'bodyweight']

export interface Gym { id: string; name: string }

export interface Exercise {
  id: string
  name: string
  muscleGroup: MuscleGroup
  aliases: string[]
}

export interface VersionChange { date: string; field: string; from: unknown; to: unknown }

export interface Version {
  id: string
  exerciseId: string
  name: string
  equipment: Equipment
  arms: Arms
  attachment?: string
  machine?: string
  cableHeight?: number // 0..1 relative to a standing silhouette (0 = floor, 1 = top of head)
  benchAngle?: number // degrees from flat
  repMin: number
  repMax: number
  defaultWarmup: boolean
  defaultSets: number
  notes?: string
  gymNotes: Record<string, string>
  media: { type: 'tiktok' | 'video'; url: string }[]
  changes: VersionChange[]
}

export interface SetEntry {
  id: string
  kind: 'warmup' | 'working'
  weight?: number
  unit: Unit
  reps?: number
  plus: boolean // "at least this many" (shown as 10+)
  partials?: number // number of partial reps after failure (shown as p2)
  side?: Side // one-arm versions log L and R rows
  bar?: Bar // barbell/ezbar versions remember which bar was used
  note?: string
}

export interface WorkoutItem {
  id: string
  versionId: string
  groupId?: string
  sets: SetEntry[]
  skipped?: boolean
  note?: string
}

export interface Group { id: string; type: GroupType }

export interface Workout {
  id: string
  name: string
  date: string // YYYY-MM-DD, local time
  gymId?: string
  routineId?: string
  startedAt?: number // epoch ms. Set => "in progress" until endedAt is set.
  endedAt?: number
  notes?: string
  items: WorkoutItem[]
  groups: Group[]
}

/**
 * One slot in a routine. `id` is stable for the life of the slot so drag-and-drop
 * lists can key on it (keying on versionId+index caused the row under your finger
 * to change identity after every reorder). Added in DB version 2; older data is
 * back-filled in src/db.ts.
 */
export interface RoutineItem { id: string; versionId: string; groupId?: string }

export interface Routine {
  id: string
  name: string
  items: RoutineItem[]
  groups: Group[]
}

export interface Settings {
  id: 'settings'
  unit: Unit
  theme: 'dark' | 'light' | 'paper'
  sound: boolean
  seeded?: boolean
}

export const DEFAULT_SETTINGS: Settings = { id: 'settings', unit: 'kg', theme: 'dark', sound: true }

/** Short random id. ~41 bits of randomness + 4 time chars; plenty for one device. */
export function uid(): string {
  return Math.random().toString(36).slice(2, 10) + Date.now().toString(36).slice(-4)
}

/** Local calendar date as YYYY-MM-DD. All workout dates use this, never UTC. */
export function today(): string {
  const d = new Date()
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
}

/** Whole days from a to b (both YYYY-MM-DD). Rounded so DST days still count as 1. */
export function daysBetween(a: string, b: string): number {
  const da = new Date(a + 'T00:00:00'), db = new Date(b + 'T00:00:00')
  return Math.round((db.getTime() - da.getTime()) / 86400000)
}

export function newSet(kind: SetEntry['kind'], unit: Unit, extra: Partial<SetEntry> = {}): SetEntry {
  return { id: uid(), kind, unit, plus: false, ...extra }
}

export function isBarbell(v: Version): boolean {
  return v.equipment === 'barbell' || v.equipment === 'ezbar'
}

const LB_PER_KG = 2.20462262

/** Normalise a weight to kg so sets logged in different units can be compared. */
export function toKg(weight: number, unit: Unit): number {
  return unit === 'lbs' ? weight / LB_PER_KG : weight
}

/** Compact one-line rendering of a set: "L EZ 30×8+ (2p)". kg is implied, lbs shown. */
export function fmtSet(s: SetEntry): string {
  const w = s.weight == null ? '–' : `${s.weight}${s.unit === 'lbs' ? 'lb' : ''}`
  const r = s.reps == null ? '–' : `${s.reps}${s.plus ? '+' : ''}`
  const p = s.partials ? ` (${s.partials}p)` : ''
  const side = s.side ? `${s.side} ` : ''
  const bar = s.bar === 'ez' ? 'EZ ' : ''
  return `${side}${bar}${w}×${r}${p}`
}
