// Paste-an-Apple-Note importer. Understands the loose format Michael types at the gym:
//
//   2026-10-20 Chest and triceps        <- optional date and title lines
//   Incline Chest Fly Machine
//   15kg - warm up - 10+
//   20kg - 8
//   22.5kg - 6 p2 (3rd notch)
//   Cable Lateral Raise
//   L 10kg - 12 / R 10kg - 11
//
// Any line that starts with a number (after optional W / L / R / EZ markers) is a set.
// Other lines name the next exercise. A first block with no sets is the workout title.
import type { Arms, Equipment, Exercise, MuscleGroup, SetEntry, Unit, Version } from './model'
import { newSet, today } from './model'
import { LIBRARY } from './seed/library'

export interface ParsedEntry { name: string; sets: SetEntry[]; note?: string }
export interface ParsedNote { date: string; title?: string; entries: ParsedEntry[]; warnings: string[] }

const MARKER = '(?:w|warm\\s?-?\\s?up|l|r|left|right|ez|bw|bodyweight)'
const SET_LINE = new RegExp(`^(?:${MARKER}\\b[\\s:.\\-]*)*(?:\\d|-\\s*[x×]\\s*\\d)`, 'i')
const MONTHS = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec']

export function isSetLine(line: string): boolean { return SET_LINE.test(line.trim()) }

function pad(n: number): string { return String(n).padStart(2, '0') }

/** ISO date from a header line, or undefined. Accepts 2026-10-20, Oct 20, October 20 2026, 20 Oct. */
export function parseDateLine(line: string): string | undefined {
  const iso = line.match(/(\d{4})-(\d{1,2})-(\d{1,2})/)
  if (iso) return `${iso[1]}-${pad(Number(iso[2]))}-${pad(Number(iso[3]))}`
  const low = line.toLowerCase()
  const m1 = low.match(/\b([a-z]{3})[a-z]*\.?\s+(\d{1,2})(?:st|nd|rd|th)?(?:,?\s+(\d{4}))?\b/)
  const m2 = low.match(/\b(\d{1,2})(?:st|nd|rd|th)?\s+([a-z]{3})[a-z]*\.?(?:,?\s+(\d{4}))?\b/)
  const m = m1 && MONTHS.includes(m1[1]) ? { mon: m1[1], day: m1[2], year: m1[3] } : m2 && MONTHS.includes(m2[2]) ? { mon: m2[2], day: m2[1], year: m2[3] } : undefined
  if (!m) return undefined
  const year = m.year ? Number(m.year) : Number(today().slice(0, 4))
  return `${year}-${pad(MONTHS.indexOf(m.mon) + 1)}-${pad(Number(m.day))}`
}

/** One set from one chunk like "15kg - warm up - 10+", "L 10 x 12", "- x 12", "bw 15 p2". */
export function parseSetChunk(chunk: string, unit: Unit): SetEntry | undefined {
  let s = chunk.trim()
  if (!s) return undefined
  let note: string | undefined
  const paren = s.match(/\(([^)]*)\)/)
  if (paren) { note = paren[1].trim() || undefined; s = s.replace(paren[0], ' ') }
  const hash = s.indexOf('#')
  if (hash >= 0) { note = s.slice(hash + 1).trim() || note; s = s.slice(0, hash) }
  const low = ' ' + s.toLowerCase().replace(/[×]/g, 'x') + ' '
  const kind: SetEntry['kind'] = /\b(warm\s?-?\s?up|w)\b/.test(low) ? 'warmup' : 'working'
  const side = /\b(l|left)\b/.test(low) ? 'L' : /\b(r|right)\b/.test(low) ? 'R' : undefined
  const bar = /\bez\b/.test(low) ? 'ez' as const : undefined
  const pm = low.match(/\bp(\d+)\b/) ?? low.match(/\b(\d+)\s*partials?\b/)
  const partials = pm ? Number(pm[1]) : undefined
  let u = unit
  if (/[\d\s](lbs?|pounds?)\b/.test(low)) u = 'lbs'; else if (/[\d\s](kgs?|kilos?)\b/.test(low)) u = 'kg'
  const bodyweight = /\b(bw|bodyweight)\b/.test(low)
  const cleaned = low.replace(/\bp\d+\b/g, ' ').replace(/\b\d+\s*partials?\b/g, ' ')
  const nums = [...cleaned.matchAll(/(\d+(?:[.,]\d+)?)\s*(kgs?|kilos?|lbs?|pounds?|\+)?/g)]
    .map(m => ({ v: Number(m[1].replace(',', '.')), unit: m[2] && m[2] !== '+' ? m[2] : undefined, plus: m[2] === '+' }))
  if (nums.length === 0) return undefined
  let weight: number | undefined, reps: number | undefined, plus = false
  if (nums.length >= 2) { weight = nums[0].v; reps = nums[1].v; plus = nums[1].plus }
  else if (nums[0].unit && !bodyweight) weight = nums[0].v
  else { reps = nums[0].v; plus = nums[0].plus }
  if (!plus && /\d\s*\+/.test(cleaned) && reps != null) plus = true
  return newSet(kind, u, { side, bar, partials, weight, reps, plus, note })
}

/** Split a line into set chunks: "20kg - 8, 22.5kg - 6" or "L 10 x 12 / R 10 x 11". */
export function parseSetLine(line: string, unit: Unit): SetEntry[] {
  const chunks = line.split(/\s*;\s*|\s*\|\s*|\s+\/\s+|,(?!\d)/).map(c => c.trim()).filter(Boolean)
  const sets = chunks.map(c => parseSetChunk(c, unit)).filter((s): s is SetEntry => !!s)
  if (sets.length > 1 && sets.every(s => s.reps == null && s.weight != null) ) return [parseSetChunk(line, unit)!]
  return sets.length ? sets : []
}

export function parseNote(text: string, unit: Unit = 'kg'): ParsedNote {
  const lines = text.split(/\r?\n/).map(l => l.replace(/^[\s•\-*–]+(?=[A-Za-z])/, '').trim()).filter(Boolean)
  const warnings: string[] = []
  let date: string | undefined, title: string | undefined
  const blocks: ParsedEntry[] = []
  let cur: ParsedEntry | undefined
  for (const raw of lines) {
    if (!date && blocks.length === 0 && !cur) {
      const d = parseDateLine(raw)
      if (d) { date = d; const rest = raw.replace(/\d{4}-\d{1,2}-\d{1,2}|[A-Za-z]{3,9}\.?\s+\d{1,2}(?:st|nd|rd|th)?(?:,?\s+\d{4})?|\d{1,2}(?:st|nd|rd|th)?\s+[A-Za-z]{3,9}\.?(?:,?\s+\d{4})?/, '').replace(/^[\s:\-–·]+|[\s:\-–·]+$/g, '').trim(); if (rest && !isSetLine(rest)) title = rest; continue }
    }
    if (isSetLine(raw)) {
      if (!cur) { warnings.push(`Sets before any exercise name: "${raw}"`); continue }
      const sets = parseSetLine(raw, unit)
      if (sets.length === 0) warnings.push(`Could not read "${raw}"`)
      cur.sets.push(...sets)
      continue
    }
    const noteLine = raw.match(/^(?:note|notes)\s*:\s*(.*)$/i)
    if (noteLine && cur) { cur.note = [cur.note, noteLine[1]].filter(Boolean).join(' · '); continue }
    if (cur && cur.sets.length === 0 && blocks.length === 1 && !title) { title = cur.name; blocks.pop(); cur = undefined }
    cur = { name: raw.replace(/\s*[:：]\s*$/, ''), sets: [] }
    blocks.push(cur)
  }
  const entries = blocks.filter(b => { if (b.sets.length === 0) warnings.push(`No sets under "${b.name}"`); return b.sets.length > 0 })
  return { date: date ?? today(), title, entries, warnings }
}

// ---- matching to the library ------------------------------------------------

export function norm(s: string): string { return s.toLowerCase().replace(/[^a-z0-9 ]+/g, ' ').replace(/\s+/g, ' ').trim() }

function score(q: string, cand: string): number {
  const a = norm(q), b = norm(cand)
  if (!a || !b) return 0
  if (a === b) return 3
  if (a.includes(b) || b.includes(a)) return 2 + Math.min(a.length, b.length) / Math.max(a.length, b.length)
  const ta = new Set(a.split(' ')), tb = new Set(b.split(' '))
  let inter = 0; for (const t of ta) if (tb.has(t)) inter++
  const j = inter / (ta.size + tb.size - inter)
  return j >= 0.5 ? 1 + j : 0
}

export interface ImportItem {
  entry: ParsedEntry
  version?: Version
  create?: { name: string; muscle: MuscleGroup; equipment: Equipment; arms: Arms }
}
export interface ImportPlan { date: string; title?: string; items: ImportItem[]; warnings: string[] }

const MUSCLE_HINTS: [RegExp, MuscleGroup][] = [
  [/curl/, 'Biceps'], [/wrist|forearm|grip|farmer/, 'Forearms'], [/pushdown|tricep|skull|kickback|extension/, 'Triceps'],
  [/calf|calves/, 'Calves'], [/glute|hip thrust|kickback/, 'Glutes'], [/squat|leg|lunge|hack|rdl|romanian|deadlift/, 'Legs'],
  [/crunch|\bab\b|abs|plank|leg raise|woodchop/, 'Abs'], [/lateral|front raise|delt|shoulder|overhead|press behind/, 'Shoulders'],
  [/bench|fly|flye|pec|chest|dip|push.?up/, 'Chest'], [/row|pulldown|pull.?up|chin|lat|shrug|face pull|pullover/, 'Back'],
]

export function guessMuscle(name: string): MuscleGroup | undefined {
  const n = norm(name)
  for (const [re, m] of MUSCLE_HINTS) if (re.test(n)) return m
  return undefined
}
export function guessEquipment(name: string): Equipment {
  const n = norm(name)
  if (/\bez\b/.test(n)) return 'ezbar'
  if (/smith/.test(n)) return 'smith'
  if (/cable|rope|pulldown|pushdown/.test(n)) return 'cable'
  if (/dumbbell|\bdb\b|hammer/.test(n)) return 'dumbbell'
  if (/barbell|\bbb\b|deadlift|bench press/.test(n)) return 'barbell'
  if (/pull up|chin up|push up|dip\b|plank|hanging|bodyweight/.test(n)) return 'bodyweight'
  return 'machine'
}

export function planImport(parsed: ParsedNote, versions: Version[], exercises: Exercise[]): ImportPlan {
  const exById = new Map(exercises.map(e => [e.id, e]))
  const items: ImportItem[] = parsed.entries.map(entry => {
    let best: { v: Version; s: number } | undefined
    for (const v of versions) {
      const ex = exById.get(v.exerciseId)
      const names = [v.name, ...(ex ? [ex.name, ...ex.aliases] : [])]
      const s = Math.max(...names.map(n => score(entry.name, n)))
      if (s > 0 && (!best || s > best.s || (s === best.s && v.name.length < best.v.name.length))) best = { v, s }
    }
    if (best && best.s >= 1.5) return { entry, version: best.v }
    const anySide = entry.sets.some(s => s.side)
    const arms: Arms = anySide || /single|one.?arm|unilateral|one.?hand/.test(norm(entry.name)) ? 'one' : 'two'
    let lib: { name: string; muscle: string; equipment: string; s: number } | undefined
    for (const l of LIBRARY) { const s = score(entry.name, l.name); if (s > 0 && (!lib || s > lib.s)) lib = { ...l, s } }
    if (lib && lib.s >= 1.5) return { entry, create: { name: entry.name, muscle: lib.muscle as MuscleGroup, equipment: lib.equipment as Equipment, arms } }
    return { entry, create: { name: entry.name, muscle: guessMuscle(entry.name) ?? 'Back', equipment: guessEquipment(entry.name), arms } }
  })
  return { date: parsed.date, title: parsed.title, items, warnings: parsed.warnings }
}
