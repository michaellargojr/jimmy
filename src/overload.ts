/**
 * Progressive-overload signals. Pure; tested in src/overload.test.ts.
 *
 * Rules (from the README, keep them in sync):
 *  - "down": first working set is under repMin.
 *  - "up":   set 1 >= repMax + 2 AND set 2 >= repMax - 1. On a 5-8 range: 10 then 7+.
 *  - green check per set: beats the same-ordinal set last time (more weight, or same weight more reps).
 *
 * Open question for the owner (not changed here): for one-arm versions the "first
 * two working sets" are 1L and 1R, not 1L and 2L. If that is wrong, filter by side
 * in verdict() before indexing.
 */
import type { SetEntry, Version } from './model'
import { toKg } from './model'

export const UP_FIRST_OFFSET = 2 // set 1 must reach repMax + 2
export const UP_SECOND_OFFSET = -1 // set 2 must reach repMax - 1

export type Verdict = 'up' | 'down' | 'none'

export function workingSets(sets: SetEntry[]): SetEntry[] {
  return sets.filter(s => s.kind === 'working')
}

/** Verdict for a finished (or in-progress) exercise. Warm-ups are ignored. */
export function verdict(sets: SetEntry[], v: Pick<Version, 'repMin' | 'repMax'>): Verdict {
  const w = workingSets(sets).filter(s => s.reps != null)
  if (w.length === 0) return 'none'
  const s1 = w[0]
  if (s1.reps! < v.repMin) return 'down'
  if (w.length >= 2) {
    const s2 = w[1]
    if (s1.reps! >= v.repMax + UP_FIRST_OFFSET && s2.reps! >= v.repMax + UP_SECOND_OFFSET) return 'up'
  }
  return 'none'
}

const KG_EPS = 0.01

/** Did this set beat the same-ordinal set last time? Weights are compared in kg so a unit switch does not fake a win. */
export function improved(now: SetEntry, last: SetEntry | undefined): boolean {
  if (!last || now.reps == null || now.weight == null) return false
  if (last.weight == null || last.reps == null) return false
  const nw = toKg(now.weight, now.unit), lw = toKg(last.weight, last.unit)
  if (nw > lw + KG_EPS) return true
  if (Math.abs(nw - lw) <= KG_EPS && now.reps > last.reps) return true
  return false
}

/** Pair today's set with last time's set by kind + ordinal (+ side when present). */
export function matchLast(now: SetEntry, nowAll: SetEntry[], lastAll: SetEntry[]): SetEntry | undefined {
  const same = (s: SetEntry) => s.kind === now.kind && (!now.side || s.side === now.side)
  let idx = -1
  for (const s of nowAll) { if (same(s)) { idx++; if (s.id === now.id) break } }
  if (idx < 0) return undefined
  let seen = -1
  for (const s of lastAll) { if (same(s)) { seen++; if (seen === idx) return s } }
  return undefined
}
