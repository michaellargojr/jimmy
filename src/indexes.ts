/**
 * Memoised read-side indexes over the store's arrays.
 *
 * Why this exists: the store keeps plain arrays (simple to persist and export).
 * Many components need "last time I did version X", "version by id", "newest
 * finished workout for routine Y". Before this file each component recomputed
 * those from scratch on every render, which meant copying and sorting the whole
 * workout list dozens of times per frame on the Live page (it re-rendered every
 * second for the timer). See docs/REVIEW-2026-11.md, finding P1.
 *
 * How it works: each index is computed once per *array identity* and cached in a
 * WeakMap. The store never mutates arrays in place (it always replaces them), so
 * identity equality means content equality. After the first call for a given
 * array, every call is a WeakMap lookup.
 *
 * Rules:
 *  - Pure. Never mutate inputs or the returned maps/arrays.
 *  - Call these anywhere, as often as you like; they are effectively free.
 *  - If you add a new "derived view" that walks all workouts, add it here, not in
 *    a component.
 */
import type { Exercise, Version, Workout, WorkoutItem } from './model'

/** One appearance of a version inside a workout. */
export interface Occurrence { workout: Workout; item: WorkoutItem }

export interface HistoryIndex {
  /** Every workout, newest first (date desc, then startedAt desc). */
  sorted: Workout[]
  /** Per version id: occurrences that have at least one weight or rep logged, newest first. */
  byVersion: Map<string, Occurrence[]>
  /** Per version id: every occurrence (logged or empty), newest first. */
  anyByVersion: Map<string, Occurrence[]>
  /** Per routine id: the newest workout that was started from it and finished. */
  lastFinishedByRoutine: Map<string, Workout>
  /** The workout that is started but not ended, if any (newest wins). */
  active?: Workout
}

export interface VersionIndex {
  byId: Map<string, Version>
  /** Per exercise id: all versions of that base movement (siblings). */
  byExercise: Map<string, Version[]>
}

export interface ExerciseIndex { byId: Map<string, Exercise> }

function hasData(item: WorkoutItem): boolean {
  return item.sets.some(s => s.reps != null || s.weight != null)
}

/** Newest first. Date is YYYY-MM-DD so string compare is chronological. */
export function newestFirst(a: Workout, b: Workout): number {
  return b.date.localeCompare(a.date) || ((b.startedAt ?? 0) - (a.startedAt ?? 0))
}

function push<K, V>(m: Map<K, V[]>, k: K, v: V) {
  const arr = m.get(k)
  if (arr) arr.push(v); else m.set(k, [v])
}

function buildHistory(workouts: Workout[]): HistoryIndex {
  const sorted = workouts.slice().sort(newestFirst)
  const byVersion = new Map<string, Occurrence[]>()
  const anyByVersion = new Map<string, Occurrence[]>()
  const lastFinishedByRoutine = new Map<string, Workout>()
  let active: Workout | undefined
  for (const w of sorted) {
    if (w.routineId && w.endedAt && !lastFinishedByRoutine.has(w.routineId)) lastFinishedByRoutine.set(w.routineId, w)
    if (!active && w.startedAt && !w.endedAt) active = w
    for (const item of w.items) {
      const occ = { workout: w, item }
      push(anyByVersion, item.versionId, occ)
      if (hasData(item)) push(byVersion, item.versionId, occ)
    }
  }
  return { sorted, byVersion, anyByVersion, lastFinishedByRoutine, active }
}

function buildVersions(versions: Version[]): VersionIndex {
  const byId = new Map<string, Version>()
  const byExercise = new Map<string, Version[]>()
  for (const v of versions) { byId.set(v.id, v); push(byExercise, v.exerciseId, v) }
  return { byId, byExercise }
}

function buildExercises(exercises: Exercise[]): ExerciseIndex {
  return { byId: new Map(exercises.map(e => [e.id, e])) }
}

const historyCache = new WeakMap<Workout[], HistoryIndex>()
const versionCache = new WeakMap<Version[], VersionIndex>()
const exerciseCache = new WeakMap<Exercise[], ExerciseIndex>()

function memo<K extends object, V>(cache: WeakMap<K, V>, key: K, build: (k: K) => V): V {
  let v = cache.get(key)
  if (!v) { v = build(key); cache.set(key, v) }
  return v
}

export function historyIndex(workouts: Workout[]): HistoryIndex { return memo(historyCache, workouts, buildHistory) }
export function versionIndex(versions: Version[]): VersionIndex { return memo(versionCache, versions, buildVersions) }
export function exerciseIndex(exercises: Exercise[]): ExerciseIndex { return memo(exerciseCache, exercises, buildExercises) }
