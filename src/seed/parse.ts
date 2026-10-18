import type { Bar, SetEntry, Side, Unit } from '../model'
import { newSet } from '../model'

/** Parse one compact set line: "[W] [L|R] [EZ] <weight|-> x <reps|->[+] [pN] [# note]" */
export function parseSetLine(line: string, unit: Unit = 'kg'): SetEntry {
  let note: string | undefined
  const hash = line.indexOf('#')
  if (hash >= 0) { note = line.slice(hash + 1).trim(); line = line.slice(0, hash) }
  const toks = line.trim().split(/\s+/)
  let kind: SetEntry['kind'] = 'working'
  let side: Side | undefined
  let bar: Bar | undefined
  let partials: number | undefined
  let weight: number | undefined
  let reps: number | undefined
  let plus = false
  for (const t of toks) {
    if (t === 'W') kind = 'warmup'
    else if (t === 'L' || t === 'R') side = t
    else if (t === 'EZ') bar = 'ez'
    else if (/^p\d+$/.test(t)) partials = Number(t.slice(1))
    else if (t.includes('x')) {
      const [w, r] = t.split('x')
      if (w !== '-' && w !== '') weight = Number(w)
      if (r && r !== '-') { plus = r.endsWith('+'); reps = Number(r.replace('+', '')) }
    }
  }
  return newSet(kind, unit, { side, bar, partials, weight, reps, plus, note })
}
