import { describe, it, expect } from 'vitest'
import { SNAPSHOT_VERSION, normalizeSnapshot, withItemIds } from './db'

describe('withItemIds', () => {
  it('fills missing ids and keeps existing ones', () => {
    const out = withItemIds([{ versionId: 'v1' }, { id: 'keep', versionId: 'v2', groupId: 'g' }])
    expect(out[0].id).toBeTruthy()
    expect(out[1]).toEqual({ id: 'keep', versionId: 'v2', groupId: 'g' })
  })
})

describe('normalizeSnapshot', () => {
  const base = { exercises: [], versions: [], workouts: [], routines: [] }
  it('rejects non-objects and missing required lists with readable messages', () => {
    expect(() => normalizeSnapshot(null)).toThrow(/JSON object/)
    expect(() => normalizeSnapshot('x')).toThrow(/JSON object/)
    expect(() => normalizeSnapshot({ ...base, workouts: undefined })).toThrow(/"workouts"/)
    expect(() => normalizeSnapshot({ ...base, versions: 'nope' })).toThrow(/not a list/)
  })
  it('rejects snapshots from a newer app', () => {
    expect(() => normalizeSnapshot({ ...base, version: SNAPSHOT_VERSION + 1 })).toThrow(/newer/)
  })
  it('upgrades a v1 export: routine items get ids, optional lists default to empty', () => {
    const s = normalizeSnapshot({ ...base, version: 1, routines: [{ id: 'r', name: 'Pull', items: [{ versionId: 'v1' }], groups: [] }] })
    expect(s.version).toBe(SNAPSHOT_VERSION)
    expect(s.routines[0].items[0].id).toBeTruthy()
    expect(s.gyms).toEqual([]); expect(s.ideas).toEqual([]); expect(s.settings).toBeUndefined()
    expect(typeof s.exportedAt).toBe('string')
  })
})
