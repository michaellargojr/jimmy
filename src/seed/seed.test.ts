/**
 * Integrity test for the hand-written seed. A typo in notion.ts used to crash the
 * app on first launch; now it fails here.
 */
import { describe, it, expect } from 'vitest'
import { buildSeed } from './index'
import { MUSCLES } from '../model'

describe('buildSeed', () => {
  const seed = buildSeed()
  const versionIds = new Set(seed.versions.map(v => v.id))
  const exerciseIds = new Set(seed.exercises.map(e => e.id))

  it('produces data', () => {
    expect(seed.workouts.length).toBeGreaterThanOrEqual(10)
    expect(seed.routines.length).toBeGreaterThan(0)
    expect(seed.versions.length).toBeGreaterThan(20)
  })
  it('every version points at an exercise with a known muscle group', () => {
    for (const v of seed.versions) {
      expect(exerciseIds.has(v.exerciseId)).toBe(true)
    }
    for (const e of seed.exercises) expect(MUSCLES).toContain(e.muscleGroup)
  })
  it('every workout and routine item resolves to a version and has a stable id', () => {
    for (const w of seed.workouts) for (const i of w.items) expect(versionIds.has(i.versionId)).toBe(true)
    for (const r of seed.routines) for (const i of r.items) { expect(versionIds.has(i.versionId)).toBe(true); expect(i.id).toBeTruthy() }
  })
  it('group references are consistent', () => {
    for (const w of [...seed.workouts, ...seed.routines]) {
      const gids = new Set(w.groups.map(g => g.id))
      for (const i of w.items) if (i.groupId) expect(gids.has(i.groupId)).toBe(true)
    }
  })
  it('dates are YYYY-MM-DD and finished', () => {
    for (const w of seed.workouts) {
      expect(w.date).toMatch(/^\d{4}-\d{2}-\d{2}$/)
      expect(w.endedAt).toBeGreaterThan(w.startedAt ?? 0)
    }
  })
  it('ids are unique', () => {
    const all = [...seed.exercises, ...seed.versions, ...seed.workouts, ...seed.routines, ...seed.gyms].map(x => x.id)
    expect(new Set(all).size).toBe(all.length)
  })
})
