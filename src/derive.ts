import type { Routine, SetEntry, Version, Workout, WorkoutItem } from './model'
import { daysBetween, today } from './model'
import { verdict, type Verdict } from './overload'

export interface LastSession { workout: Workout; item: WorkoutItem; daysAgo: number; verdict: Verdict }

function hasData(item: WorkoutItem): boolean {
  return item.sets.some(s => s.reps != null || s.weight != null)
}

function sortDesc(ws: Workout[]): Workout[] {
  return ws.slice().sort((a, b) => (b.date.localeCompare(a.date)) || ((b.startedAt ?? 0) - (a.startedAt ?? 0)))
}

/** Most recent session of this version (excluding the given workout). */
export function lastSession(versionId: string, workouts: Workout[], versions: Version[], excludeWorkoutId?: string, before?: string): LastSession | undefined {
  const v = versions.find(x => x.id === versionId)
  if (!v) return undefined
  for (const w of sortDesc(workouts)) {
    if (w.id === excludeWorkoutId) continue
    if (before && w.date > before) continue
    const item = w.items.find(i => i.versionId === versionId && hasData(i))
    if (item) return { workout: w, item, daysAgo: daysBetween(w.date, today()), verdict: verdict(item.sets, v) }
  }
  return undefined
}

/** Most recent session of any *other* version of the same base exercise. */
export function otherVersionLast(version: Version, workouts: Workout[], versions: Version[], excludeWorkoutId?: string): (LastSession & { version: Version }) | undefined {
  const siblings = versions.filter(v => v.exerciseId === version.exerciseId && v.id !== version.id)
  let best: (LastSession & { version: Version }) | undefined
  for (const s of siblings) {
    const ls = lastSession(s.id, workouts, versions, excludeWorkoutId)
    if (ls && (!best || ls.workout.date > best.workout.date)) best = { ...ls, version: s }
  }
  return best
}

export function lastBar(versionId: string, workouts: Workout[]): SetEntry['bar'] | undefined {
  for (const w of sortDesc(workouts)) {
    const item = w.items.find(i => i.versionId === versionId)
    const s = item?.sets.slice().reverse().find(x => x.bar)
    if (s) return s.bar
  }
  return undefined
}

export function routineLast(routine: Routine, workouts: Workout[]): Workout | undefined {
  return sortDesc(workouts).find(w => w.routineId === routine.id && w.endedAt)
}

export function elapsed(ms: number): string {
  const s = Math.floor(ms / 1000)
  const h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60), sec = s % 60
  return h > 0 ? `${h}:${String(m).padStart(2, '0')}:${String(sec).padStart(2, '0')}` : `${m}:${String(sec).padStart(2, '0')}`
}

export function workingReps(sets: SetEntry[]): number {
  return sets.filter(s => s.kind === 'working' && s.reps != null).length
}
