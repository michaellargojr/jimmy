import type { SetEntry, Version } from './model'

export const UP_FIRST_OFFSET = 2 // set 1 must reach repMax + 2
export const UP_SECOND_OFFSET = -1 // set 2 must reach repMax - 1

export type Verdict = 'up' | 'down' | 'none'

export function workingSets(sets: SetEntry[]): SetEntry[] {
  return sets.filter(s => s.kind === 'working')
}

/**
 * Verdict for a finished (or in-progress) exercise. Warm-ups are ignored.
 * One-arm versions are judged per side: L1/L2 and R1/R2 are each a pair,
 * never L1/R1. Down if any side's first set is under range; up only when
 * every side that has data hits the up rule.
 */
export function verdict(sets: SetEntry[], v: Pick<Version, 'repMin' | 'repMax'>): Verdict {
  const w = workingSets(sets).filter(s => s.reps != null)
  if (w.length === 0) return 'none'
  const sides = Array.from(new Set(w.map(s => s.side ?? '')))
  const perSide = sides.map(side => w.filter(s => (s.side ?? '') === side))
  if (perSide.some(g => g[0].reps! < v.repMin)) return 'down'
  const up = perSide.every(g => g.length >= 2 && g[0].reps! >= v.repMax + UP_FIRST_OFFSET && g[1].reps! >= v.repMax + UP_SECOND_OFFSET)
  return up ? 'up' : 'none'
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
  if (sameKindLast[idx]) return sameKindLast[idx]
  // last time's warm-up was a single unsided row; show it under both WL and WR
  if (now.kind === 'warmup' && now.side) return lastAll.filter(s => s.kind === 'warmup' && !s.side)[idx]
  return undefined
}
