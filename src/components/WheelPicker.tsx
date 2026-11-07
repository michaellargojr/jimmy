import { useEffect, useRef, useState } from 'react'

/**
 * Scroll wheel. `value` is the committed number (blank = undefined); `hint` is where the wheel
 * rests when blank. `onChange` fires when the wheel settles after a scroll, `onPreview` whenever
 * the highlighted number changes (so a Done button can accept what is shown), `onPick` on a tap.
 */
export function Wheel({ values, value, hint, onChange, onPreview, onPick, format }: {
  values: number[]; value: number | undefined; hint?: number
  onChange: (v: number) => void; onPreview?: (v: number) => void; onPick?: (v: number) => void; format?: (v: number) => string
}) {
  const ref = useRef<HTMLDivElement>(null)
  const H = 44
  const nearest = (v: number | undefined) => {
    if (v == null) return 0
    let bi = 0, bd = Infinity
    values.forEach((x, i) => { const d = Math.abs(x - v); if (d < bd) { bd = d; bi = i } })
    return bi
  }
  const [idx, setIdx] = useState(() => nearest(value ?? hint))
  // While the wheel is being positioned by code, scroll events must not commit or preview a value.
  // A flag cleared two frames after the move (not a time window) so a quick flick right after
  // opening is never swallowed.
  const settling = useRef(false)
  const endSettle = () => requestAnimationFrame(() => requestAnimationFrame(() => { settling.current = false }))
  const preview = useRef(onPreview); preview.current = onPreview
  useEffect(() => {
    const el = ref.current; if (!el) return
    const i = nearest(value ?? hint)
    preview.current?.(values[i])
    // iOS WebKit re-snaps a freshly mounted snap container back to 0 after the first programmatic
    // scroll, which left the wheel on 0 instead of last time's number. Position it with snapping
    // off, verify over a few frames, then turn snapping back on.
    settling.current = true
    el.style.scrollSnapType = 'none'
    el.scrollTop = i * H
    let tries = 0
    const verify = () => {
      const w = ref.current; if (!w) return
      if (Math.round(w.scrollTop / H) !== i && tries++ < 6) { w.scrollTop = i * H; requestAnimationFrame(verify); return }
      w.style.scrollSnapType = ''
      endSettle()
    }
    const raf = requestAnimationFrame(() => requestAnimationFrame(verify))
    return () => cancelAnimationFrame(raf)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])
  // Follow the value when something other than the wheel changes it (the ±0.5 / ±1.25 buttons).
  useEffect(() => {
    const el = ref.current; if (!el || value == null) return
    const i = nearest(value)
    if (i === idx) return
    settling.current = true
    setIdx(i); el.scrollTop = i * H; preview.current?.(values[i])
    endSettle()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [value])
  const timer = useRef<number | undefined>(undefined)
  const onScroll = () => {
    const el = ref.current; if (!el) return
    const i = Math.max(0, Math.min(values.length - 1, Math.round(el.scrollTop / H)))
    setIdx(i)
    if (settling.current) return // programmatic: the highlight follows, the shown value does not
    preview.current?.(values[i])
    window.clearTimeout(timer.current)
    timer.current = window.setTimeout(() => { onChange(values[i]) }, 90)
  }
  return (
    <div className="wheelwrap">
      <div className="wheel" ref={ref} onScroll={onScroll}>
        <div className="pad" />
        {values.map((v, i) => (
          <div key={v} className={'opt' + (i === idx ? ' sel' : '')} onClick={() => {
            settling.current = true; window.setTimeout(() => { settling.current = false }, 450); window.clearTimeout(timer.current)
            setIdx(i); preview.current?.(values[i])
            ref.current!.scrollTo({ top: i * H, behavior: 'smooth' })
            if (onPick) onPick(values[i]); else onChange(values[i])
          }}>
            {format ? format(v) : v}
          </div>
        ))}
        <div className="pad" />
      </div>
    </div>
  )
}

export function range(from: number, to: number, step: number): number[] {
  const out: number[] = []
  for (let v = from; v <= to + 1e-9; v += step) out.push(Math.round(v * 100) / 100)
  return out
}
