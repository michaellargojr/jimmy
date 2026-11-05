/**
 * One exercise inside a live workout: header (name, verdict dot, ⋯ menu), last
 * time, set rows, +/− set buttons, and the weight/reps wheel sheet.
 *
 * Editing model: tapping a field opens the wheel sheet. Every wheel commit writes
 * straight through to the workout (onChange -> putWorkout). A snapshot of the set
 * is kept in `editOrig` so tapping the backdrop restores it ("tap outside to
 * cancel"); "Done" / "reps →" / "next set →" keep the edits.
 */
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
import { useHold } from './useHold'
import { VersionSheet } from './VersionSheet'

// Wheel contents never change, so build them once per module, not per render.
const KG_VALUES = range(0, 250, 2.5)
const LBS_VALUES = range(0, 500, 5)
const REP_VALUES = range(0, 40, 1)
const KG_NUDGES = [-1.25, -0.5, 0.5, 1.25]
const LBS_NUDGES = [-2.5, 2.5]
const MAX_PARTIALS = 5

type Field = 'weight' | 'reps'

export function ExerciseCard({ workout, item, version, onChange, onRemove, onSwap, compact }: {
  workout: Workout; item: WorkoutItem; version: Version
  onChange: (item: WorkoutItem) => void; onRemove: () => void; onSwap?: () => void; compact?: boolean
}) {
  const workouts = useStore(s => s.workouts)
  const versions = useStore(s => s.versions)
  const settings = useStore(s => s.settings)
  const last = lastSession(version.id, workouts, versions, workout.id)
  const other = otherVersionLast(version, workouts, versions, workout.id)
  const lastSets = last?.item.sets
  const v = verdict(item.sets, version)
  const played = useRef(false)
  useEffect(() => {
    if (v === 'up' && !played.current) { played.current = true; if (settings.sound) ding() }
    if (v !== 'up') played.current = false
  }, [v, settings.sound])

  const [edit, setEdit] = useState<{ setId: string; field: Field } | null>(null)
  const editOrig = useRef<SetEntry | null>(null) // snapshot so tapping outside cancels
  const openEdit = (setId: string, field: Field) => {
    if (!editOrig.current || editOrig.current.id !== setId) editOrig.current = item.sets.find(s => s.id === setId) ?? null
    setEdit({ setId, field })
  }
  const closeEdit = () => { editOrig.current = null; setEdit(null) }
  const cancelEdit = () => {
    const orig = editOrig.current
    if (orig) onChange({ ...item, sets: item.sets.map(s => (s.id === orig.id ? orig : s)) })
    closeEdit()
  }
  const [menu, setMenu] = useState(false)
  const [editVersion, setEditVersion] = useState(false)
  const hold = useHold(() => setMenu(true))
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
    let idx = -1
    for (let i = item.sets.length - 1; i >= 0; i--) if (item.sets[i].kind === 'working') { idx = i; break }
    if (idx < 0) return
    const sets = item.sets.slice(); sets.splice(idx, 1)
    onChange({ ...item, sets })
  }
  const hasWarmup = item.sets.some(s => s.kind === 'warmup')
  const toggleWarmup = () => {
    if (hasWarmup) onChange({ ...item, sets: item.sets.filter(s => s.kind !== 'warmup') })
    else onChange({ ...item, sets: [newSet('warmup', item.sets[0]?.unit ?? settings.unit, { bar: item.sets[0]?.bar }), ...item.sets] })
  }

  const editing = edit ? item.sets.find(s => s.id === edit.setId) : undefined

  return (
    <div className={'exercise' + (v === 'up' ? ' up' : '')}>
      <div className="row" onContextMenu={e => { e.preventDefault(); setMenu(true) }} {...hold}>
        <div className="grow">
          <h2 className="exname" onClick={() => setEditVersion(true)}>{version.name} {v === 'down' && <span className="dot red" title="under range" />}</h2>
          <div className="small faint">{version.equipment}{version.arms === 'one' ? ' · one arm' : ''} · {version.repMin}-{version.repMax} reps{version.machine ? ` · ${version.machine}` : ''}{version.cableHeight != null ? ` · cable ${Math.round(version.cableHeight * 100)}%` : ''}{version.benchAngle != null ? ` · bench ${version.benchAngle}°` : ''}</div>
        </div>
        <button className="iconbtn" onClick={() => setMenu(true)} aria-label="exercise menu">⋯</button>
      </div>
      {!compact && <LastTime last={last} other={other} />}
      <div className="stack" style={{ gap: 0, marginTop: 6 }}>
        {item.sets.map((s, i) => {
          const lm = lastSets ? matchLast(s, item.sets, lastSets) : undefined
          return (
            <SetRow key={s.id} set={s} label={labels[i]} version={version}
              last={lm} improved={improved(s, lm)}
              onEdit={field => openEdit(s.id, field)}
              onPatch={p => patchSet(s.id, p)} />
          )
        })}
      </div>
      <div className="setbtns">
        <button className="btn sm" onClick={addSet}>+ set</button>
        <button className="btn sm" onClick={removeSet}>− set</button>
        <button className="btn sm" onClick={toggleWarmup}>{hasWarmup ? 'no warm-up' : '+ warm-up'}</button>
        {item.note && <span className="small faint" style={{ alignSelf: 'center' }}>{item.note}</span>}
      </div>

      <Sheet open={!!editing} onClose={cancelEdit}>
        {editing && edit && (() => {
          const lastMatch = lastSets ? matchLast(editing, item.sets, lastSets) : undefined
          const idx = item.sets.indexOf(editing)
          const nxt = item.sets[idx + 1]
          return (
          <>
            <div className="row" style={{ marginBottom: 2 }}>
              <h3 className="grow" style={{ margin: 0 }}>Set {labels[idx]} · {edit.field}</h3>
              {edit.field === 'weight' && (
                <button className="chip" onClick={() => patchSet(editing.id, { unit: editing.unit === 'kg' ? 'lbs' : 'kg' })}>{editing.unit}</button>
              )}
            </div>
            <div className="sub">{version.name}{lastSets ? ` · last: ${lastSets.filter(x => x.reps != null || x.weight != null).map(x => `${x.weight ?? '–'}×${x.reps ?? '–'}${x.plus ? '+' : ''}`).join(' · ')}` : ''}</div>
            {edit.field === 'weight' ? (
              <>
                <Wheel key={editing.unit} values={editing.unit === 'lbs' ? LBS_VALUES : KG_VALUES} value={editing.weight} hint={lastMatch?.weight ?? lastSets?.find(x => x.kind === 'working' && x.weight != null)?.weight} onChange={w => patchSet(editing.id, { weight: w })} />
                <div className="row" style={{ justifyContent: 'center', marginTop: 8 }}>
                  {(editing.unit === 'lbs' ? LBS_NUDGES : KG_NUDGES).map(d => (
                    <button key={d} className="btn sm" onClick={() => patchSet(editing.id, { weight: Math.max(0, Math.round(((editing.weight ?? 0) + d) * 100) / 100) })}>{d > 0 ? '+' : ''}{d}</button>
                  ))}
                  <span className="grow" style={{ textAlign: 'right', fontWeight: 700, fontSize: 20 }}>{editing.weight ?? '–'} {editing.unit}</span>
                </div>
              </>
            ) : (
              <>
                <Wheel values={REP_VALUES} value={editing.reps} hint={lastMatch?.reps ?? version.repMax} onChange={r => patchSet(editing.id, { reps: r })} />
                <div className="row" style={{ justifyContent: 'center', marginTop: 8 }}>
                  <button className={'chip' + (editing.plus ? ' on' : '')} onClick={() => patchSet(editing.id, { plus: !editing.plus })}>+ at least</button>
                  <button className="chip" onClick={() => patchSet(editing.id, { partials: ((editing.partials ?? 0) + 1) % (MAX_PARTIALS + 1) || undefined })}>partials {editing.partials ?? 0}</button>
                </div>
              </>
            )}
            <input className="note" style={{ marginTop: 10 }} value={editing.note ?? ''} onChange={e => patchSet(editing.id, { note: e.target.value || undefined })} placeholder="Note for this set (grip, notch, how it felt)" />
            <div className="row" style={{ marginTop: 10 }}>
              {edit.field === 'weight' && <button className="btn grow" onClick={() => { editOrig.current = null; openEdit(editing.id, 'reps') }}>reps →</button>}
              {edit.field === 'reps' && nxt && <button className="btn grow" onClick={() => { editOrig.current = null; openEdit(nxt.id, 'weight') }}>next set →</button>}
              <button className="btn primary grow" onClick={closeEdit}>Done</button>
            </div>
            <div className="small faint" style={{ textAlign: 'center', marginTop: 8 }}>tap outside to cancel</div>
          </>
          )
        })()}
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
