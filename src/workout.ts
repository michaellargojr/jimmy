/**
 * Building and labelling workouts. Pure functions; tested in src/workout.test.ts.
 */
import type { Routine, SetEntry, Unit, Version, Workout, WorkoutItem } from './model'
import { isBarbell, newSet, today, uid } from './model'
import { lastBar } from './derive'
import { blocks } from './grouping'

/** Empty rows for a version: optional warm-up, then defaultSets working sets (L+R pairs for one-arm). Barbell versions inherit the last bar used. */
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

export function newItem(v: Version, unit: Unit, workouts: Workout[], groupId?: string): WorkoutItem {
  return { id: uid(), versionId: v.id, groupId, sets: defaultSets(v, unit, workouts) }
}

/** A fresh (not yet started) workout from a routine. Items whose version no longer exists are dropped. */
export function workoutFromRoutine(r: Routine, versions: Version[], unit: Unit, workouts: Workout[], gymId?: string): Workout {
  const vmap = new Map(versions.map(v => [v.id, v]))
  return {
    id: uid(), name: r.name, date: today(), routineId: r.id, gymId, groups: r.groups.map(g => ({ ...g })),
    items: r.items.filter(i => vmap.has(i.versionId)).map(i => newItem(vmap.get(i.versionId)!, unit, workouts, i.groupId)),
  }
}

/** Label for a set row: W, 1, 2, 1L, 1R, 2L ... L and R of the same ordinal share a number. */
export function setLabels(sets: SetEntry[]): string[] {
  let n = 0
  const seen: Record<string, number> = {}
  return sets.map(s => {
    if (s.kind === 'warmup') return 'W'
    if (s.side) {
      seen[s.side] = (seen[s.side] ?? 0) + 1
      return `${seen[s.side]}${s.side}`
    }
    n += 1
    return String(n)
  })
}

/** Consecutive items sharing a groupId form one pane on the Live page. */
export function panes(items: WorkoutItem[]): WorkoutItem[][] {
  return blocks(items)
}

/** Done = skipped, or at least one working set has reps. */
export function itemDone(it: WorkoutItem): boolean {
  return it.skipped === true || it.sets.some(s => s.kind === 'working' && s.reps != null)
}
