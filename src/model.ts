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
  plus: boolean
  partials?: number
  side?: Side
  bar?: Bar
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
  date: string // YYYY-MM-DD
  gymId?: string
  routineId?: string
  startedAt?: number
  endedAt?: number
  notes?: string
  items: WorkoutItem[]
  groups: Group[]
}

export interface Routine {
  id: string
  name: string
  items: { versionId: string; groupId?: string }[]
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

export function uid(): string {
  return Math.random().toString(36).slice(2, 10) + Date.now().toString(36).slice(-4)
}

export function today(): string {
  const d = new Date()
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
}

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

export function fmtSet(s: SetEntry): string {
  const w = s.weight == null ? '–' : `${s.weight}${s.unit === 'lbs' ? 'lb' : ''}`
  const r = s.reps == null ? '–' : `${s.reps}${s.plus ? '+' : ''}`
  const p = s.partials ? ` (${s.partials}p)` : ''
  const side = s.side ? `${s.side} ` : ''
  const bar = s.bar === 'ez' ? 'EZ ' : ''
  return `${side}${bar}${w}×${r}${p}`
}
