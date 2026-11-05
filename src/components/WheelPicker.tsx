/**
 * iOS-style scroll wheel built on CSS scroll-snap. Each option is H px tall; the
 * selected option is the one whose top sits under the centre guide line.
 *
 * Commit rules:
 *  - A value is committed (onChange) 90 ms after the last scroll event, i.e. once
 *    the wheel has settled, and only if it differs from the last committed value.
 *    Without that de-dupe a slow drag committed the same number repeatedly, each
 *    commit writing the workout to IndexedDB and re-rendering the Live page.
 *  - The first 250 ms after mount are a "settle" window: positioning the wheel on
 *    the current value fires scroll events that must not commit anything.
 *  - Tapping an option commits immediately and scrolls to it.
 */
import { useEffect, useRef, useState } from 'react'

const H = 44 // must match .wheel .opt height in theme.css
const SETTLE_MS = 250
const COMMIT_DEBOUNCE_MS = 90

export function Wheel({ values, value, hint, onChange, format }: { values: number[]; value: number | undefined; hint?: number; onChange: (v: number) => void; format?: (v: number) => string }) {
  const ref = useRef<HTMLDivElement>(null)
  const nearest = (v: number | undefined) => {
    if (v == null) return 0
    let bi = 0, bd = Infinity
    values.forEach((x, i) => { const d = Math.abs(x - v); if (d < bd) { bd = d; bi = i } })
    return bi
  }
  const clampIdx = (i: number) => Math.max(0, Math.min(values.length - 1, i))
  const [idx, setIdx] = useState(() => nearest(value ?? hint))
  const settleUntil = useRef(0)
  const committed = useRef<number | undefined>(value)
  useEffect(() => { committed.current = value }, [value])
  useEffect(() => {
    const el = ref.current; if (!el) return
    settleUntil.current = Date.now() + SETTLE_MS
    el.scrollTop = nearest(value ?? hint) * H
    // Mount-only: later value changes come from this wheel itself and must not re-scroll it.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])
  const timer = useRef<number | undefined>(undefined)
  useEffect(() => () => window.clearTimeout(timer.current), [])
  const commit = (i: number) => {
    const v = values[i]
    if (v === committed.current) return
    committed.current = v
    onChange(v)
  }
  const onScroll = () => {
    const el = ref.current; if (!el) return
    const i = clampIdx(Math.round(el.scrollTop / H))
    setIdx(i)
    if (Date.now() < settleUntil.current) return
    window.clearTimeout(timer.current)
    timer.current = window.setTimeout(() => commit(i), COMMIT_DEBOUNCE_MS)
  }
  return (
    <div className="wheelwrap">
      <div className="wheel" ref={ref} onScroll={onScroll}>
        <div className="pad" />
        {values.map((v, i) => (
          <div key={v} className={'opt' + (i === idx ? ' sel' : '')} onClick={() => { settleUntil.current = 0; window.clearTimeout(timer.current); commit(i); ref.current?.scrollTo({ top: i * H, behavior: 'smooth' }) }}>
            {format ? format(v) : v}
          </div>
        ))}
        <div className="pad" />
      </div>
    </div>
  )
}

/** Inclusive numeric range, rounded to 2 dp so 2.5 steps stay exact. */
export function range(from: number, to: number, step: number): number[] {
  const out: number[] = []
  for (let v = from; v <= to + 1e-9; v += step) out.push(Math.round(v * 100) / 100)
  return out
}
