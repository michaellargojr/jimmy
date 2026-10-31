import { describe, it, expect } from 'vitest'
import { buildSeed } from './index'
import { parseSetLine } from './parse'
import { EXERCISES, ROUTINES, WORKOUTS } from './notion'

describe('seed', () => {
  it('references only exercises it defines', () => {
    const names = new Set(EXERCISES.map(e => e.name))
    for (const w of WORKOUTS) for (const e of w.entries) expect(names.has(e.ex), `${w.date}: ${e.ex}`).toBe(true)
    for (const r of ROUTINES) for (const i of r.items) expect(names.has(i.ex), `${r.name}: ${i.ex}`).toBe(true)
  })
  it('builds with every item resolving to a version', () => {
    const s = buildSeed()
    const vids = new Set(s.versions.map(v => v.id))
    for (const w of s.workouts) for (const i of w.items) expect(vids.has(i.versionId)).toBe(true)
    for (const r of s.routines) for (const i of r.items) expect(vids.has(i.versionId)).toBe(true)
    expect(s.workouts.length).toBe(WORKOUTS.length)
  })
  it('parses the compact set grammar', () => {
    expect(parseSetLine('W 15x12')).toMatchObject({ kind: 'warmup', weight: 15, reps: 12 })
    expect(parseSetLine('L EZ 20x8+ p2 # note')).toMatchObject({ side: 'L', bar: 'ez', weight: 20, reps: 8, plus: true, partials: 2, note: 'note' })
    expect(parseSetLine('-x10').weight).toBeUndefined()
  })
})
