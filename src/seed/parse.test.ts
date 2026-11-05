import { describe, it, expect } from 'vitest'
import { parseSetLine } from './parse'

describe('parseSetLine', () => {
  it('parses weight x reps', () => {
    const s = parseSetLine('30x8')
    expect(s).toMatchObject({ kind: 'working', weight: 30, reps: 8, plus: false, unit: 'kg' })
    expect(s.side).toBeUndefined(); expect(s.bar).toBeUndefined(); expect(s.partials).toBeUndefined()
  })
  it('parses warm-up, side, bar, plus, partials and note', () => {
    expect(parseSetLine('W 15x12+')).toMatchObject({ kind: 'warmup', weight: 15, reps: 12, plus: true })
    expect(parseSetLine('L 25x5 p2')).toMatchObject({ side: 'L', weight: 25, reps: 5, partials: 2 })
    expect(parseSetLine('EZ 20x10 # felt heavy')).toMatchObject({ bar: 'ez', weight: 20, reps: 10, note: 'felt heavy' })
  })
  it('treats - as not recorded', () => {
    expect(parseSetLine('-x8').weight).toBeUndefined()
    expect(parseSetLine('30x-').reps).toBeUndefined()
    expect(parseSetLine('30x-').weight).toBe(30)
  })
  it('respects the unit argument', () => {
    expect(parseSetLine('135x5', 'lbs').unit).toBe('lbs')
  })
})
