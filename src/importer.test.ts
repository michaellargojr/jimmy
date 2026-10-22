import { describe, it, expect } from 'vitest'
import { isSetLine, parseDateLine, parseNote, parseSetChunk, parseSetLine, planImport } from './importer'
import type { Exercise, Version } from './model'

describe('parseSetChunk', () => {
  it('reads the README example', () => {
    const s = parseSetChunk('15kg - warm up - 10+', 'kg')!
    expect(s.kind).toBe('warmup'); expect(s.weight).toBe(15); expect(s.reps).toBe(10); expect(s.plus).toBe(true); expect(s.unit).toBe('kg')
  })
  it('reads working sets, partials, sides, bars, notes and units', () => {
    expect(parseSetChunk('20kg - 8', 'kg')).toMatchObject({ kind: 'working', weight: 20, reps: 8, plus: false })
    expect(parseSetChunk('22.5 x 6 p2 (3rd notch)', 'kg')).toMatchObject({ weight: 22.5, reps: 6, partials: 2, note: '3rd notch' })
    expect(parseSetChunk('22,5kg 6 2 partials', 'kg')).toMatchObject({ weight: 22.5, reps: 6, partials: 2 })
    expect(parseSetChunk('L 10kg - 12', 'kg')).toMatchObject({ side: 'L', weight: 10, reps: 12 })
    expect(parseSetChunk('EZ 30 x 8', 'kg')).toMatchObject({ bar: 'ez', weight: 30, reps: 8 })
    expect(parseSetChunk('45lb x 10', 'kg')).toMatchObject({ unit: 'lbs', weight: 45, reps: 10 })
    expect(parseSetChunk('- x 12', 'kg')).toMatchObject({ reps: 12 }); expect(parseSetChunk('- x 12', 'kg')!.weight).toBeUndefined()
    expect(parseSetChunk('bw 15', 'kg')).toMatchObject({ reps: 15 })
    expect(parseSetChunk('50kg', 'kg')).toMatchObject({ weight: 50 })
  })
  it('splits several sets on one line', () => {
    expect(parseSetLine('20kg - 8, 22.5kg - 6', 'kg').map(s => s.reps)).toEqual([8, 6])
    expect(parseSetLine('L 10 x 12 / R 10 x 11', 'kg').map(s => s.side)).toEqual(['L', 'R'])
  })
  it('tells set lines from names', () => {
    expect(isSetLine('15kg - warm up - 10+')).toBe(true); expect(isSetLine('L 10 x 12')).toBe(true); expect(isSetLine('W 12 x 15')).toBe(true)
    expect(isSetLine('Cable Shrug')).toBe(false); expect(isSetLine('Low to high cable fly')).toBe(false); expect(isSetLine('- x 12')).toBe(true)
  })
})

describe('parseDateLine', () => {
  it('accepts iso and month names', () => {
    expect(parseDateLine('2026-10-20 chest')).toBe('2026-10-20')
    expect(parseDateLine('Oct 20, 2026')).toBe('2026-10-20')
    expect(parseDateLine('20 October 2026')).toBe('2026-10-20')
    expect(parseDateLine('Cable Shrug')).toBeUndefined()
  })
})

describe('parseNote', () => {
  const note = `2026-10-20 Chest and triceps
Incline Chest Fly Machine
15kg - warm up - 10+
20kg - 8
22.5kg - 6 p2
Cable Lateral Raise
L 10kg - 12 / R 10kg - 11
note: 3rd notch
Rope Pushdown
`
  it('reads date, title, exercises and sets', () => {
    const p = parseNote(note)
    expect(p.date).toBe('2026-10-20'); expect(p.title).toBe('Chest and triceps')
    expect(p.entries.map(e => e.name)).toEqual(['Incline Chest Fly Machine', 'Cable Lateral Raise'])
    expect(p.entries[0].sets).toHaveLength(3); expect(p.entries[0].sets[0].kind).toBe('warmup')
    expect(p.entries[1].sets.map(s => s.side)).toEqual(['L', 'R']); expect(p.entries[1].note).toBe('3rd notch')
    expect(p.warnings.some(w => w.includes('Rope Pushdown'))).toBe(true)
  })
  it('treats a leading name-only block as the title', () => {
    const p = parseNote('Legs\nLeg Press\n100 x 10')
    expect(p.title).toBe('Legs'); expect(p.entries[0].name).toBe('Leg Press')
  })
})

describe('planImport', () => {
  const ex: Exercise[] = [{ id: 'e1', name: 'Shrug', muscleGroup: 'Back', aliases: [] }, { id: 'e2', name: 'Lat Pulldown', muscleGroup: 'Back', aliases: ['lats'] }]
  const base = { equipment: 'cable' as const, arms: 'two' as const, repMin: 5, repMax: 8, defaultWarmup: true, defaultSets: 2, gymNotes: {}, media: [], changes: [] }
  const vs: Version[] = [{ id: 'v1', exerciseId: 'e1', name: 'Cable Shrug', ...base }, { id: 'v2', exerciseId: 'e2', name: 'Lat Pulldown (Two-Arm)', ...base }]
  it('matches versions loosely and creates the rest with a guess', () => {
    const p = planImport(parseNote('cable shrugs\n50 x 12\nlat pulldown\n60 x 8\nSingle arm bayesian curl\nL 10 x 12 / R 10 x 12'), vs, ex)
    expect(p.items[0].version?.id).toBe('v1')
    expect(p.items[1].version?.id).toBe('v2')
    expect(p.items[2].version).toBeUndefined()
    expect(p.items[2].create).toMatchObject({ muscle: 'Biceps', equipment: 'cable', arms: 'one' })
  })
})
