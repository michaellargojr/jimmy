import { useEffect, useRef, useState } from 'react'

export function Wheel({ values, value, hint, onChange, format }: { values: number[]; value: number | undefined; hint?: number; onChange: (v: number) => void; format?: (v: number) => string }) {
  const ref = useRef<HTMLDivElement>(null)
  const H = 44
  const nearest = (v: number | undefined) => {
    if (v == null) return 0
    let bi = 0, bd = Infinity
    values.forEach((x, i) => { const d = Math.abs(x - v); if (d < bd) { bd = d; bi = i } })
    return bi
  }
  const [idx, setIdx] = useState(() => nearest(value ?? hint))
  const settleUntil = useRef(0)
  useEffect(() => {
    const el = ref.current; if (!el) return
    settleUntil.current = Date.now() + 250 // programmatic positioning must not commit a value
    el.scrollTop = nearest(value ?? hint) * H
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])
  const timer = useRef<number | undefined>(undefined)
  const onScroll = () => {
    const el = ref.current; if (!el) return
    if (Date.now() < settleUntil.current) { setIdx(Math.round(el.scrollTop / H)); return }
    const i = Math.max(0, Math.min(values.length - 1, Math.round(el.scrollTop / H)))
    setIdx(i)
    window.clearTimeout(timer.current)
    timer.current = window.setTimeout(() => { onChange(values[i]) }, 90)
  }
  return (
    <div className="wheelwrap">
      <div className="wheel" ref={ref} onScroll={onScroll}>
        <div className="pad" />
        {values.map((v, i) => (
          <div key={v} className={'opt' + (i === idx ? ' sel' : '')} onClick={() => { settleUntil.current = 0; onChange(values[i]); ref.current!.scrollTo({ top: i * H, behavior: 'smooth' }) }}>
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
