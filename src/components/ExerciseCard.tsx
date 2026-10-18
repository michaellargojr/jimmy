import { useEffect, useRef, useState } from 'react'
import type { SetEntry, Version, Workout, WorkoutItem } from '../model'
import { newSet } from '../model'
import { useStore } from '../store'
import { lastSession, otherVersionLast } from '../derive'
import { improved, matchLast, verdict } from '../overload'
import { setLabels } from '../workout'
import { SetRow } from './SetRow'
import { LastTime } from './LastTime'
import { Sheet } from './Sheet'
import { Wheel, range } from './WheelPicker'
import { ding } from './Sound'
import { swallowNextClick } from './SwipeRow'
import { VersionSheet } from './VersionSheet'

export function ExerciseCard({ workout, item, version, onChange, onRemove, onSwap, compact }: {
  workout: Workout; item: WorkoutItem; version: Version
  onChange: (item: WorkoutItem) => void; onRemove: () => void; onSwap?: () => void; compact?: boolean
}) {
  const { workouts, versions, settings } = useStore()
  const last = lastSession(version.id, workouts, versions, workout.id)
  const other = otherVersionLast(version, workouts, versions, workout.id)
  const v = verdict(item.sets, version)
  const played = useRef(false)
  useEffect(() => {
    if (v === 'up' && !played.current) { played.current = true; if (settings.sound) ding() }
    if (v !== 'up') played.current = false
  }, [v, settings.sound])

  const [edit, setEdit] = useState<{ setId: string; field: 'weight' | 'reps' } | null>(null)
  const [menu, setMenu] = useState(false)
  const [editVersion, setEditVersion] = useState(false)
  const holdRef = useRef<number | undefined>(undefined)
  const holdOrigin = useRef<{ x: number; y: number } | null>(null)
  const labels = setLabels(item.sets)

  const patchSet = (id: string, patch: Partial<SetEntry>) =>
    onChange({ ...item, sets: item.sets.map(s => (s.id === id ? { ...s, ...patch } : s)) })

  const addSet = () => {
    const lastWorking = [...item.sets].reverse().find(s => s.kind === 'working') ?? item.sets[item.sets.length - 1]
    const base = { unit: lastWorking?.unit ?? settings.unit, bar: lastWorking?.bar }
    const add: SetEntry[] = version.arms === 'one'
      ? [newSet('working', base.unit, { ...base, side: 'L' }), newSet('working', base.unit, { ...base, side: 'R' })]
      : [newSet('working', base.unit, base)]
    onChange({ ...item, sets: [...item.sets, ...add] })
  }
  const removeSet = () => {
    const idx = [...item.sets].map((s, i) => ({ s, i })).reverse().find(x => x.s.kind === 'working')?.i
    if (idx == null) return
    const sets = item.sets.slice(); sets.splice(idx, 1)
    onChange({ ...item, sets })
  }
  const toggleWarmup = () => {
    const has = item.sets.some(s => s.kind === 'warmup')
    if (has) onChange({ ...item, sets: item.sets.filter(s => s.kind !== 'warmup') })
    else onChange({ ...item, sets: [newSet('warmup', item.sets[0]?.unit ?? settings.unit, { bar: item.sets[0]?.bar }), ...item.sets] })
  }

  const editing = edit ? item.sets.find(s => s.id === edit.setId) : undefined
  const weightVals = (unit: string) => (unit === 'lbs' ? range(0, 500, 5) : range(0, 250, 2.5))

  return (
    <div className={'exercise' + (v === 'up' ? ' up' : '')}>
      <div className="row" onContextMenu={e => { e.preventDefault(); setMenu(true) }}
        onTouchStart={e => { const t = e.touches[0]; holdOrigin.current = { x: t.clientX, y: t.clientY }; window.clearTimeout(holdRef.current); holdRef.current = window.setTimeout(() => { swallowNextClick(); setMenu(true) }, 1500) }}
        onTouchEnd={() => window.clearTimeout(holdRef.current)} onTouchCancel={() => window.clearTimeout(holdRef.current)}
        onTouchMove={e => { const t = e.touches[0]; if (holdOrigin.current && Math.hypot(t.clientX - holdOrigin.current.x, t.clientY - holdOrigin.current.y) > 4) window.clearTimeout(holdRef.current) }}>
        <div className="grow">
          <h2 className="exname" onClick={() => setEditVersion(true)}>{version.name} {v === 'down' && <span className="dot red" title="under range" />}</h2>
          <div className="small faint">{version.equipment}{version.arms === 'one' ? ' · one arm' : ''} · {version.repMin}-{version.repMax} reps{version.machine ? ` · ${version.machine}` : ''}{version.cableHeight != null ? ` · cable ${Math.round(version.cableHeight * 100)}%` : ''}{version.benchAngle != null ? ` · bench ${version.benchAngle}°` : ''}</div>
        </div>
        <button className="iconbtn" onClick={() => setMenu(true)}>⋯</button>
      </div>
      {!compact && <LastTime last={last} other={other} />}
      <div className="stack" style={{ gap: 0, marginTop: 6 }}>
        {item.sets.map((s, i) => (
          <SetRow key={s.id} set={s} label={labels[i]} version={version}
            last={last ? matchLast(s, item.sets, last.item.sets) : undefined}
            improved={last ? improved(s, matchLast(s, item.sets, last.item.sets)) : false}
            onEdit={field => setEdit({ setId: s.id, field })}
            onPatch={p => patchSet(s.id, p)} />
        ))}
      </div>
      <div className="setbtns">
        <button className="btn sm" onClick={addSet}>+ set</button>
        <button className="btn sm" onClick={removeSet}>− set</button>
        <button className="btn sm" onClick={toggleWarmup}>{item.sets.some(s => s.kind === 'warmup') ? 'no warm-up' : '+ warm-up'}</button>
        {item.note && <span className="small faint" style={{ alignSelf: 'center' }}>{item.note}</span>}
      </div>

      <Sheet open={!!editing} onClose={() => setEdit(null)}>
        {editing && edit && (
          <>
            <div className="row" style={{ marginBottom: 8 }}>
              <h3 className="grow" style={{ margin: 0 }}>{version.name} · {labels[item.sets.indexOf(editing)]} · {edit.field}</h3>
              {edit.field === 'weight' && (
                <button className="chip" onClick={() => patchSet(editing.id, { unit: editing.unit === 'kg' ? 'lbs' : 'kg' })}>{editing.unit}</button>
              )}
            </div>
            {last && <div className="small faint" style={{ marginBottom: 6 }}>last: {last.item.sets.filter(x => x.reps != null || x.weight != null).map(x => `${x.weight ?? '–'}×${x.reps ?? '–'}${x.plus ? '+' : ''}`).join(' · ')}</div>}
            {edit.field === 'weight' ? (
              <>
                <Wheel key={editing.unit} values={weightVals(editing.unit)} value={editing.weight} onChange={w => patchSet(editing.id, { weight: w })} />
                <div className="row" style={{ justifyContent: 'center', marginTop: 8 }}>
                  {(editing.unit === 'lbs' ? [-2.5, 2.5] : [-1.25, -0.5, 0.5, 1.25]).map(d => (
                    <button key={d} className="btn sm" onClick={() => patchSet(editing.id, { weight: Math.max(0, Math.round(((editing.weight ?? 0) + d) * 100) / 100) })}>{d > 0 ? '+' : ''}{d}</button>
                  ))}
                  <span className="grow" style={{ textAlign: 'right', fontWeight: 700, fontSize: 20 }}>{editing.weight ?? '–'} {editing.unit}</span>
                </div>
              </>
            ) : (
              <>
                <Wheel values={range(0, 40, 1)} value={editing.reps} onChange={r => patchSet(editing.id, { reps: r })} />
                <div className="row" style={{ justifyContent: 'center', marginTop: 8 }}>
                  <button className={'chip' + (editing.plus ? ' on' : '')} onClick={() => patchSet(editing.id, { plus: !editing.plus })}>+ at least</button>
                  <button className="chip" onClick={() => patchSet(editing.id, { partials: ((editing.partials ?? 0) + 1) % 6 || undefined })}>partials {editing.partials ?? 0}</button>
                </div>
              </>
            )}
            <div className="row" style={{ marginTop: 12 }}>
              {edit.field === 'weight' && <button className="btn grow" onClick={() => setEdit({ setId: editing.id, field: 'reps' })}>reps →</button>}
              {edit.field === 'reps' && (() => {
                const i = item.sets.indexOf(editing); const nxt = item.sets[i + 1]
                return nxt ? <button className="btn grow" onClick={() => setEdit({ setId: nxt.id, field: 'weight' })}>next set →</button> : null
              })()}
              <button className="btn primary grow" onClick={() => setEdit(null)}>Done</button>
            </div>
          </>
        )}
      </Sheet>

      {editVersion && <VersionSheet open onClose={() => setEditVersion(false)} version={version} onSaved={() => setEditVersion(false)} />}
      <Sheet open={menu} onClose={() => setMenu(false)} title={version.name}>
        <div className="stack">
          <label className="small muted">Note for this exercise today</label>
          <textarea className="ta" style={{ minHeight: 70 }} value={item.note ?? ''} onChange={e => onChange({ ...item, note: e.target.value })} placeholder="e.g. 3rd notch, underhand grip, felt it in the left shoulder" />
          <button className="btn" onClick={() => { onChange({ ...item, skipped: !item.skipped }); setMenu(false) }}>{item.skipped ? 'Unskip' : 'Skip today'}</button>
          {onSwap && <button className="btn" onClick={() => { setMenu(false); onSwap() }}>Swap for another exercise</button>}
          <button className="btn danger" onClick={() => { setMenu(false); onRemove() }}>Remove from workout</button>
        </div>
      </Sheet>
    </div>
  )
}
