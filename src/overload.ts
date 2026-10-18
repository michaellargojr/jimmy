import type { SetEntry, Version } from './model'

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

/** Did this set beat the same-index set last time? Same unit assumed. */
export function improved(now: SetEntry, last: SetEntry | undefined): boolean {
  if (!last || now.reps == null || now.weight == null) return false
  if (last.weight == null || last.reps == null) return false
  if (now.weight > last.weight) return true
  if (now.weight === last.weight && now.reps > last.reps) return true
  return false
}

/** Pair today's sets with last time's sets by kind + ordinal (+ side when present). */
export function matchLast(now: SetEntry, nowAll: SetEntry[], lastAll: SetEntry[]): SetEntry | undefined {
  const sameKindNow = nowAll.filter(s => s.kind === now.kind && (!now.side || s.side === now.side))
  const idx = sameKindNow.findIndex(s => s.id === now.id)
  const sameKindLast = lastAll.filter(s => s.kind === now.kind && (!now.side || s.side === now.side))
  return sameKindLast[idx]
}
