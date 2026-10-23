import { useRef } from 'react'
import type { Setup, Version } from '../model'
import { ATTACHMENTS, CABLE_MARKS, benchLabel, cableLabel, sameSetup, setupLabel } from '../model'
import { useStore } from '../store'
import { Sheet } from './Sheet'
import { BenchIcon } from './Icons'

const ANGLES = [0, 15, 30, 45, 60, 75, 90]

/** Every attachment name ever used, plus the built-in list, so the same names keep coming back. */
export function useAttachmentOptions(): string[] {
  const { versions, workouts } = useStore()
  const set = new Set<string>(ATTACHMENTS)
  for (const v of versions) if (v.attachment) set.add(v.attachment)
  for (const w of workouts) for (const i of w.items) if (i.attachment) set.add(i.attachment)
  return Array.from(set).sort((a, b) => a.localeCompare(b))
}

export function AttachmentSelect({ value, onChange, options }: { value?: string; onChange: (v: string | undefined) => void; options: string[] }) {
  const all = value && !options.includes(value) ? [value, ...options] : options
  return (
    <select className="search" value={value ?? ''} onChange={e => {
      const v = e.target.value
      if (v === '__new') { const name = prompt('Attachment name')?.trim(); if (name) onChange(name); return }
      onChange(v || undefined)
    }}>
      <option value="">no attachment</option>
      {all.map(a => <option key={a} value={a}>{a}</option>)}
      <option value="__new">other…</option>
    </select>
  )
}

/** Tap or drag on a standing figure to pick the cable height. */
export function SilhouettePicker({ value, onChange }: { value?: number; onChange: (h: number | undefined) => void }) {
  const ref = useRef<SVGSVGElement>(null)
  const H = 200, TOP = 6, BOTTOM = 196
  const toH = (clientY: number) => {
    const r = ref.current!.getBoundingClientRect()
    const y = ((clientY - r.top) / r.height) * H
    return Math.round(Math.max(0, Math.min(1, (BOTTOM - y) / (BOTTOM - TOP))) * 20) / 20
  }
  const pick = (e: React.PointerEvent<SVGSVGElement>) => { if (e.buttons === 0 && e.type === 'pointermove') return; onChange(toH(e.clientY)) }
  const y = value == null ? undefined : BOTTOM - value * (BOTTOM - TOP)
  return (
    <div className="row" style={{ gap: 14, alignItems: 'stretch' }}>
      <svg ref={ref} className="silhouette" viewBox="0 0 64 200" width="96" height="300" onPointerDown={pick} onPointerMove={pick} style={{ touchAction: 'none' }}>
        <g fill="currentColor" opacity=".35">
          <circle cx="32" cy="18" r="12" />
          <rect x="28" y="29" width="8" height="8" />
          <rect x="18" y="36" width="28" height="60" rx="8" />
          <rect x="7" y="38" width="9" height="62" rx="4.5" />
          <rect x="48" y="38" width="9" height="62" rx="4.5" />
          <rect x="19" y="94" width="12" height="96" rx="5" />
          <rect x="33" y="94" width="12" height="96" rx="5" />
          <rect x="17" y="188" width="15" height="8" rx="3" />
          <rect x="32" y="188" width="15" height="8" rx="3" />
        </g>
        {CABLE_MARKS.map(([h, label]) => { const my = BOTTOM - h * (BOTTOM - TOP); return <line key={label} x1="0" x2="64" y1={my} y2={my} stroke="currentColor" strokeWidth=".6" opacity=".25" /> })}
        {y != null && <>
          <line x1="-2" x2="66" y1={y} y2={y} stroke="var(--accent)" strokeWidth="3" strokeLinecap="round" />
          <circle cx="62" cy={y} r="4" fill="var(--accent)" />
        </>}
      </svg>
      <div className="stack" style={{ gap: 6, justifyContent: 'center' }}>
        {CABLE_MARKS.slice().reverse().map(([h, label]) => (
          <button key={label} className={'chip' + (value != null && cableLabel(value) === label ? ' on' : '')} onClick={() => onChange(h)}>{label}</button>
        ))}
        <div className="small faint" style={{ marginTop: 6 }}>{value == null ? 'tap the figure' : `${Math.round(value * 100)}%`}</div>
        {value != null && <button className="chip" onClick={() => onChange(undefined)}>clear</button>}
      </div>
    </div>
  )
}

/** Per-session setup for one exercise: cable height, bench angle, attachment. */
export function SetupSheet({ open, onClose, version, setup, last, onChange }: {
  open: boolean; onClose: () => void; version: Version; setup: Setup; last?: Setup; onChange: (patch: Setup) => void
}) {
  const options = useAttachmentOptions()
  const showCable = version.equipment === 'cable' || setup.cableHeight != null
  const lastLabel = last ? setupLabel(last) : ''
  return (
    <Sheet open={open} onClose={onClose} title={`Setup · ${version.name}`}>
      <div className="stack">
        {lastLabel && (
          <div className="row small">
            <span className="muted grow">last time: {lastLabel}</span>
            {!sameSetup(setup, last!) && <button className="chip" onClick={() => onChange({ cableHeight: last!.cableHeight, benchAngle: last!.benchAngle, attachment: last!.attachment })}>use last</button>}
          </div>
        )}
        {showCable && (
          <div className="stack" style={{ gap: 4 }}>
            <span className="small muted">Cable height</span>
            <SilhouettePicker value={setup.cableHeight} onChange={h => onChange({ ...setup, cableHeight: h })} />
          </div>
        )}
        <div className="stack" style={{ gap: 4 }}>
          <span className="small muted">Bench</span>
          <div className="row" style={{ gap: 6, flexWrap: 'wrap' }}>
            <span style={{ color: 'var(--fg2)' }}><BenchIcon angle={setup.benchAngle ?? 0} size={30} /></span>
            <button className={'chip' + (setup.benchAngle == null ? ' on' : '')} onClick={() => onChange({ ...setup, benchAngle: undefined })}>none</button>
            {ANGLES.map(a => <button key={a} className={'chip' + (setup.benchAngle === a ? ' on' : '')} onClick={() => onChange({ ...setup, benchAngle: a })}>{benchLabel(a)}</button>)}
          </div>
        </div>
        <div className="stack" style={{ gap: 4 }}>
          <span className="small muted">Attachment</span>
          <AttachmentSelect value={setup.attachment} options={options} onChange={a => onChange({ ...setup, attachment: a })} />
        </div>
        <div className="small faint">Saved with today's session and carried into next time.</div>
        <button className="btn primary block" onClick={onClose}>Done</button>
      </div>
    </Sheet>
  )
}
