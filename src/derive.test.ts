import { describe, it, expect } from 'vitest'
import { activeWorkout, elapsed, lastBar, lastSession, otherVersionLast, routineLast } from './derive'
import { historyIndex, versionIndex } from './indexes'
import { newSet, today, type Version, type Workout, type WorkoutItem } from './model'

const ver = (id: string, exerciseId: string, name: string): Version => ({
  id, exerciseId, name, equipment: 'cable', arms: 'two', repMin: 5, repMax: 8, defaultWarmup: true, defaultSets: 2, gymNotes: {}, media: [], changes: [],
})
const versions = [ver('v1', 'e1', 'Cable Shrug'), ver('v2', 'e1', 'Dumbbell Shrug'), ver('v3', 'e2', 'Pec Deck')]

const item = (id: string, versionId: string, sets: WorkoutItem['sets']): WorkoutItem => ({ id, versionId, sets })
const logged = (reps: number, weight = 30) => newSet('working', 'kg', { reps, weight })
const empty = () => newSet('working', 'kg')

const workouts: Workout[] = [
  { id: 'w1', name: 'A', date: '2026-10-01', routineId: 'r1', startedAt: 1, endedAt: 2, groups: [], items: [item('i1', 'v1', [logged(8), logged(7)])] },
  { id: 'w2', name: 'B', date: '2026-10-05', routineId: 'r1', startedAt: 1, endedAt: 2, groups: [], items: [item('i2', 'v2', [logged(10, 20), logged(9, 20)]), item('i3', 'v1', [newSet('working', 'kg', { bar: 'ez' })])] },
  { id: 'w3', name: 'C', date: '2026-10-09', routineId: 'r1', startedAt: 1, groups: [], items: [item('i4', 'v1', [empty(), empty()])] }, // in progress, nothing logged
]

describe('historyIndex', () => {
  it('is memoised per array identity', () => {
    expect(historyIndex(workouts)).toBe(historyIndex(workouts))
    expect(historyIndex(workouts.slice())).not.toBe(historyIndex(workouts))
  })
  it('sorts newest first and tracks the active workout', () => {
    const h = historyIndex(workouts)
    expect(h.sorted.map(w => w.id)).toEqual(['w3', 'w2', 'w1'])
    expect(h.active?.id).toBe('w3')
    expect(activeWorkout(workouts)?.id).toBe('w3')
  })
  it('only counts items with data in byVersion', () => {
    const h = historyIndex(workouts)
    expect(h.byVersion.get('v1')?.map(o => o.workout.id)).toEqual(['w1'])
    expect(h.anyByVersion.get('v1')?.map(o => o.workout.id)).toEqual(['w3', 'w2', 'w1'])
  })
  it('does not mutate the input', () => {
    const copy = workouts.map(w => w.id)
    historyIndex(workouts)
    expect(workouts.map(w => w.id)).toEqual(copy)
  })
})

describe('versionIndex', () => {
  it('groups siblings by exercise', () => {
    const vi = versionIndex(versions)
    expect(vi.byId.get('v3')?.name).toBe('Pec Deck')
    expect(vi.byExercise.get('e1')?.map(v => v.id)).toEqual(['v1', 'v2'])
  })
})

describe('lastSession', () => {
  it('returns the newest logged session and skips the excluded workout', () => {
    const ls = lastSession('v1', workouts, versions)
    expect(ls?.workout.id).toBe('w1')
    expect(ls?.verdict).toBe('none')
    expect(ls?.daysAgo).toBe(Math.round((new Date(today() + 'T00:00:00').getTime() - new Date('2026-10-01T00:00:00').getTime()) / 86400000))
    expect(lastSession('v1', workouts, versions, 'w1')).toBeUndefined()
  })
  it('returns undefined for unknown versions', () => {
    expect(lastSession('nope', workouts, versions)).toBeUndefined()
  })
})

describe('otherVersionLast', () => {
  it('finds the newest sibling session', () => {
    const o = otherVersionLast(versions[0], workouts, versions)
    expect(o?.version.id).toBe('v2')
    expect(o?.workout.id).toBe('w2')
    expect(otherVersionLast(versions[2], workouts, versions)).toBeUndefined()
  })
})

describe('lastBar / routineLast', () => {
  it('finds the last recorded bar even on an unlogged set', () => {
    expect(lastBar('v1', workouts)).toBe('ez')
    expect(lastBar('v3', workouts)).toBeUndefined()
  })
  it('routineLast ignores unfinished workouts', () => {
    expect(routineLast({ id: 'r1', name: '', items: [], groups: [] }, workouts)?.id).toBe('w2')
  })
})

describe('elapsed', () => {
  it('formats m:ss and h:mm:ss, never negative', () => {
    expect(elapsed(65_000)).toBe('1:05')
    expect(elapsed(3_723_000)).toBe('1:02:03')
    expect(elapsed(-5)).toBe('0:00')
  })
})
