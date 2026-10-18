import { describe, it, expect } from 'vitest'
import { verdict, improved, matchLast } from './overload'
import { newSet } from './model'

const v = { repMin: 5, repMax: 8 }
const W = (reps?: number, weight = 30, kind: 'warmup' | 'working' = 'working', plus = false) =>
  newSet(kind, 'kg', { reps, weight, plus })

describe('verdict', () => {
  it('ignores warm-ups and returns none with no data', () => {
    expect(verdict([W(20, 10, 'warmup')], v)).toBe('none')
    expect(verdict([], v)).toBe('none')
  })
  it('flags down when first working set is under range', () => {
    expect(verdict([W(20, 10, 'warmup'), W(4), W(8)], v)).toBe('down')
  })
  it('flags up when set1 >= max+2 and set2 >= max-1', () => {
    expect(verdict([W(10), W(7)], v)).toBe('up')
    expect(verdict([W(10), W(8)], v)).toBe('up')
    expect(verdict([W(10), W(6)], v)).toBe('none')
    expect(verdict([W(9), W(8)], v)).toBe('none')
    expect(verdict([W(10)], v)).toBe('none')
  })
  it('does not flag in-range sets', () => {
    expect(verdict([W(7), W(6)], v)).toBe('none')
  })
})

describe('improved', () => {
  it('green on more weight or same weight more reps', () => {
    expect(improved(W(8, 30), W(8, 25))).toBe(true)
    expect(improved(W(9, 30), W(8, 30))).toBe(true)
    expect(improved(W(8, 30), W(8, 30))).toBe(false)
    expect(improved(W(8, 30), undefined)).toBe(false)
    expect(improved(W(undefined, 30), W(8, 30))).toBe(false)
  })
})

describe('matchLast', () => {
  it('pairs by kind and ordinal and side', () => {
    const now = [W(12, 10, 'warmup'), W(8), W(7)]
    const last = [W(11, 10, 'warmup'), W(10), W(8)]
    expect(matchLast(now[1], now, last)?.reps).toBe(10)
    expect(matchLast(now[2], now, last)?.reps).toBe(8)
    expect(matchLast(now[0], now, last)?.reps).toBe(11)
    const nowL = [newSet('working', 'kg', { side: 'L', reps: 5 }), newSet('working', 'kg', { side: 'R', reps: 4 })]
    const lastL = [newSet('working', 'kg', { side: 'R', reps: 7 }), newSet('working', 'kg', { side: 'L', reps: 6 })]
    expect(matchLast(nowL[0], nowL, lastL)?.reps).toBe(6)
  })
})
