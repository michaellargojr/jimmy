import { describe, it, expect } from 'vitest'
import { carriedSetup, newItem } from './workout'
import { setupLabel, sameSetup, type Version, type Workout } from './model'

const v: Version = { id: 'v1', exerciseId: 'e1', name: 'Rope Pushdown', equipment: 'cable', arms: 'two', repMin: 8, repMax: 12, defaultWarmup: true, defaultSets: 2, gymNotes: {}, media: [], changes: [], attachment: 'rope', cableHeight: 1 }
const w = (date: string, item: Partial<Workout['items'][number]>): Workout => ({ id: 'w' + date, name: 'x', date, items: [{ id: 'i' + date, versionId: 'v1', sets: [{ id: 's', kind: 'working', unit: 'kg', plus: false, reps: 10, weight: 20 }], ...item }], groups: [] })

describe('setup carries forward', () => {
  it('uses the version defaults when nothing was recorded', () => {
    expect(carriedSetup(v, [])).toEqual({ cableHeight: 1, attachment: 'rope' })
  })
  it('prefers what was used last session, even over the version defaults', () => {
    const ws = [w('2026-10-01', { attachment: 'V-bar', cableHeight: 0.85 }), w('2026-10-10', { attachment: 'straight bar', cableHeight: 0.72, benchAngle: 30 })]
    expect(carriedSetup(v, ws)).toEqual({ cableHeight: 0.72, benchAngle: 30, attachment: 'straight bar' })
    const it = newItem(v, 'kg', ws)
    expect(it.attachment).toBe('straight bar'); expect(it.sets.length).toBe(3)
  })
  it('labels and compares setups', () => {
    expect(setupLabel({ attachment: 'rope', cableHeight: 0.72, benchAngle: 0 })).toBe('rope · chest · flat')
    expect(setupLabel({})).toBe('')
    expect(sameSetup({ attachment: 'rope' }, { attachment: 'rope' })).toBe(true)
    expect(sameSetup({ attachment: 'rope' }, { attachment: 'rope', benchAngle: 30 })).toBe(false)
  })
})
