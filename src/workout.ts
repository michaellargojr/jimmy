import type { Routine, SetEntry, Setup, Unit, Version, Workout, WorkoutItem } from './model'
import { isBarbell, newSet, today, uid } from './model'
import { lastBar, lastItemOf } from './derive'

export function defaultSets(v: Version, unit: Unit, workouts: Workout[]): SetEntry[] {
  const bar = isBarbell(v) ? (lastBar(v.id, workouts) ?? (v.equipment === 'ezbar' ? 'ez' : 'straight')) : undefined
  const sets: SetEntry[] = []
  if (v.defaultWarmup) sets.push(newSet('warmup', unit, { bar }))
  for (let i = 0; i < v.defaultSets; i++) {
    if (v.arms === 'one') { sets.push(newSet('working', unit, { bar, side: 'L' })); sets.push(newSet('working', unit, { bar, side: 'R' })) }
    else sets.push(newSet('working', unit, { bar }))
  }
  return sets
}

/** Setup for a new item: what was used last time, else the version's usual setup. */
export function carriedSetup(v: Version, workouts: Workout[]): Setup {
  const last = lastItemOf(v.id, workouts)
  const fromLast = last && (last.attachment || last.cableHeight != null || last.benchAngle != null)
  const s: Setup = fromLast
    ? { cableHeight: last.cableHeight, benchAngle: last.benchAngle, attachment: last.attachment }
    : { cableHeight: v.cableHeight, benchAngle: v.benchAngle, attachment: v.attachment }
  const out: Setup = {}
  if (s.cableHeight != null) out.cableHeight = s.cableHeight
  if (s.benchAngle != null) out.benchAngle = s.benchAngle
  if (s.attachment) out.attachment = s.attachment
  return out
}

export function newItem(v: Version, unit: Unit, workouts: Workout[], groupId?: string): WorkoutItem {
  return { id: uid(), versionId: v.id, groupId, sets: defaultSets(v, unit, workouts), ...carriedSetup(v, workouts) }
}

export function workoutFromRoutine(r: Routine, versions: Version[], unit: Unit, workouts: Workout[], gymId?: string): Workout {
  const vmap = new Map(versions.map(v => [v.id, v]))
  return {
    id: uid(), name: r.name, date: today(), routineId: r.id, gymId, groups: r.groups.map(g => ({ ...g })),
    items: r.items.filter(i => vmap.has(i.versionId)).map(i => {
      const it = newItem(vmap.get(i.versionId)!, unit, workouts, i.groupId)
      const alts = (i.alts ?? []).filter(a => vmap.has(a) && a !== i.versionId)
      return alts.length ? { ...it, alts } : it
    }),
  }
}

/** Label for a set row: W, 1, 2, 1L, 2R ... */
export function setLabels(sets: SetEntry[]): string[] {
  let n = 0
  const seen: Record<string, number> = {}
  return sets.map(s => {
    if (s.kind === 'warmup') return 'W'
    if (s.side) {
      // number by pairs: L and R of the same ordinal share a number
      const key = s.side
      seen[key] = (seen[key] ?? 0) + 1
      return `${seen[key]}${s.side}`
    }
    n += 1
    return String(n)
  })
}

/** Consecutive items sharing a groupId form one pane. */
export function panes(items: WorkoutItem[]): WorkoutItem[][] {
  const out: WorkoutItem[][] = []
  for (const it of items) {
    const last = out[out.length - 1]
    if (it.groupId && last && last[0].groupId === it.groupId) last.push(it)
    else out.push([it])
  }
  return out
}

export function itemDone(it: WorkoutItem): boolean {
  return it.skipped === true || it.sets.some(s => s.kind === 'working' && s.reps != null)
}
