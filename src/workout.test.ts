import { describe, it, expect } from 'vitest'
import { defaultSets, itemDone, newItem, panes, setLabels, workoutFromRoutine } from './workout'
import { newSet, type Routine, type Version, type Workout } from './model'

const ver = (over: Partial<Version> = {}): Version => ({
  id: 'v1', exerciseId: 'e1', name: 'Curl', equipment: 'cable', arms: 'two', repMin: 5, repMax: 8, defaultWarmup: true, defaultSets: 2, gymNotes: {}, media: [], changes: [], ...over,
})

describe('setLabels', () => {
  it('numbers working sets and labels warm-ups W', () => {
    const sets = [newSet('warmup', 'kg'), newSet('working', 'kg'), newSet('working', 'kg')]
    expect(setLabels(sets)).toEqual(['W', '1', '2'])
  })
  it('pairs L and R under the same ordinal', () => {
    const sets = [newSet('working', 'kg', { side: 'L' }), newSet('working', 'kg', { side: 'R' }), newSet('working', 'kg', { side: 'L' }), newSet('working', 'kg', { side: 'R' })]
    expect(setLabels(sets)).toEqual(['1L', '1R', '2L', '2R'])
  })
})

describe('defaultSets', () => {
  it('builds warm-up + N working sets', () => {
    const sets = defaultSets(ver(), 'kg', [])
    expect(sets.map(s => s.kind)).toEqual(['warmup', 'working', 'working'])
    expect(sets.every(s => s.unit === 'kg' && s.bar === undefined)).toBe(true)
  })
  it('doubles rows for one-arm versions and skips warm-up when off', () => {
    const sets = defaultSets(ver({ arms: 'one', defaultWarmup: false, defaultSets: 2 }), 'lbs', [])
    expect(sets.map(s => s.side)).toEqual(['L', 'R', 'L', 'R'])
    expect(sets[0].unit).toBe('lbs')
  })
  it('defaults the bar from equipment, then from history', () => {
    expect(defaultSets(ver({ equipment: 'ezbar' }), 'kg', [])[0].bar).toBe('ez')
    expect(defaultSets(ver({ equipment: 'barbell' }), 'kg', [])[0].bar).toBe('straight')
    const history: Workout[] = [{ id: 'w', name: '', date: '2026-01-01', groups: [], items: [{ id: 'i', versionId: 'v1', sets: [newSet('working', 'kg', { bar: 'ez', reps: 8 })] }] }]
    expect(defaultSets(ver({ equipment: 'barbell' }), 'kg', history)[0].bar).toBe('ez')
  })
})

describe('workoutFromRoutine', () => {
  it('copies groups, keeps order, drops items whose version is gone', () => {
    const versions = [ver({ id: 'v1' }), ver({ id: 'v2', name: 'Row' })]
    const r: Routine = { id: 'r', name: 'Pull', groups: [{ id: 'g', type: 'superset' }], items: [{ id: 'a', versionId: 'v2', groupId: 'g' }, { id: 'b', versionId: 'gone' }, { id: 'c', versionId: 'v1', groupId: 'g' }] }
    const w = workoutFromRoutine(r, versions, 'kg', [], 'gym1')
    expect(w.items.map(i => i.versionId)).toEqual(['v2', 'v1'])
    expect(w.items.map(i => i.groupId)).toEqual(['g', 'g'])
    expect(w.groups).toEqual(r.groups)
    expect(w.groups).not.toBe(r.groups)
    expect(w.routineId).toBe('r'); expect(w.gymId).toBe('gym1'); expect(w.startedAt).toBeUndefined()
  })
})

describe('panes / itemDone', () => {
  it('panes follow group adjacency', () => {
    const a = newItem(ver(), 'kg', [], 'g'), b = newItem(ver(), 'kg', [], 'g'), c = newItem(ver(), 'kg', [])
    expect(panes([a, b, c]).map(p => p.length)).toEqual([2, 1])
  })
  it('itemDone: skipped or any working rep logged (warm-ups do not count)', () => {
    const it0 = newItem(ver(), 'kg', [])
    expect(itemDone(it0)).toBe(false)
    expect(itemDone({ ...it0, skipped: true })).toBe(true)
    expect(itemDone({ ...it0, sets: [newSet('warmup', 'kg', { reps: 12 })] })).toBe(false)
    expect(itemDone({ ...it0, sets: [newSet('working', 'kg', { reps: 8 })] })).toBe(true)
  })
})
