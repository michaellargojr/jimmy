/**
 * Read-only questions about history: "when did I last do this?", "which bar did I
 * use?", "when did I last run this routine?". All of them are O(1) lookups on the
 * memoised indexes in src/indexes.ts, so it is fine to call them per row in a list.
 *
 * Signatures take the raw store arrays (workouts, versions) rather than the index
 * objects so call sites stay short and the caching is invisible to them.
 */
import type { Routine, SetEntry, Version, Workout, WorkoutItem } from './model'
import { daysBetween, today } from './model'
import { verdict, type Verdict } from './overload'
import { historyIndex, versionIndex } from './indexes'

export interface LastSession { workout: Workout; item: WorkoutItem; daysAgo: number; verdict: Verdict }

/** Most recent logged session of this version, skipping `excludeWorkoutId` (usually the workout being edited). */
export function lastSession(versionId: string, workouts: Workout[], versions: Version[], excludeWorkoutId?: string): LastSession | undefined {
  const v = versionIndex(versions).byId.get(versionId)
  if (!v) return undefined
  for (const occ of historyIndex(workouts).byVersion.get(versionId) ?? []) {
    if (occ.workout.id === excludeWorkoutId) continue
    return { workout: occ.workout, item: occ.item, daysAgo: daysBetween(occ.workout.date, today()), verdict: verdict(occ.item.sets, v) }
  }
  return undefined
}

/** Most recent session of any *other* version of the same base exercise (e.g. Dumbbell Shrug when you're doing Cable Shrug). */
export function otherVersionLast(version: Version, workouts: Workout[], versions: Version[], excludeWorkoutId?: string): (LastSession & { version: Version }) | undefined {
  const siblings = versionIndex(versions).byExercise.get(version.exerciseId) ?? []
  let best: (LastSession & { version: Version }) | undefined
  for (const s of siblings) {
    if (s.id === version.id) continue
    const ls = lastSession(s.id, workouts, versions, excludeWorkoutId)
    if (ls && (!best || ls.workout.date > best.workout.date)) best = { ...ls, version: s }
  }
  return best
}

/** The bar (EZ / straight) used the last time any set of this version recorded one. */
export function lastBar(versionId: string, workouts: Workout[]): SetEntry['bar'] | undefined {
  for (const { item } of historyIndex(workouts).anyByVersion.get(versionId) ?? []) {
    for (let i = item.sets.length - 1; i >= 0; i--) {
      const bar = item.sets[i].bar
      if (bar) return bar
    }
  }
  return undefined
}

/** Newest finished workout started from this routine. */
export function routineLast(routine: Routine, workouts: Workout[]): Workout | undefined {
  return historyIndex(workouts).lastFinishedByRoutine.get(routine.id)
}

/** The workout that is in progress (started, not ended), if any. */
export function activeWorkout(workouts: Workout[]): Workout | undefined {
  return historyIndex(workouts).active
}

/** 0:00 / 1:02:03 style duration. */
export function elapsed(ms: number): string {
  const s = Math.floor(Math.max(0, ms) / 1000)
  const h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60), sec = s % 60
  return h > 0 ? `${h}:${String(m).padStart(2, '0')}:${String(sec).padStart(2, '0')}` : `${m}:${String(sec).padStart(2, '0')}`
}
