import { useEffect, useRef, useState } from 'react'
import type { SetEntry, Version, Workout, WorkoutItem } from '../model'
import { newSet, setupLabel } from '../model'
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
import { VersionSheet, shortGym } from './VersionSheet'
import { BenchIcon, CableIcon, PlayIcon } from './Icons'
import { SetupSheet } from './SetupSheet'

export function ExerciseCard({ workout, item, version, onChange, onRemove, onSwap, onSwapTo, compact }: {
  workout: Workout; item: WorkoutItem; version: Version
  onChange: (item: WorkoutItem) => void; onRemove: () => void; onSwap?: () => void; onSwapTo?: (versionId: string) => void; compact?: boolean
}) {
  const { workouts, versions, gyms, settings } = useStore()
  const last = lastSession(version.id, workouts, versions, workout.id)
  const other = otherVersionLast(version, workouts, versions, workout.id)
  const v = verdict(item.sets, version)
  const played = useRef(false)
  useEffect(() => {
    if (v === 'up' && !played.current) { played.current = true; if (settings.sound) ding() }
    if (v !== 'up') played.current = false
  }, [v, settings.sound])

  const [edit, setEdit] = useState<{ setId: string; field: 'weight' | 'reps' } | null>(null)
  const editOrig = useRef<SetEntry | null>(null) // snapshot so tapping outside cancels
  const shown = useRef<{ weight?: number; reps?: number; partials?: number }>({}) // what the wheels currently display
  const openEdit = (setId: string, field: 'weight' | 'reps') => {
    if (!editOrig.current || editOrig.current.id !== setId) editOrig.current = item.sets.find(s => s.id === setId) ?? null
    shown.current = {}
    setEdit({ setId, field })
  }
  const closeEdit = () => { editOrig.current = null; setEdit(null) }
  const cancelEdit = () => {
    const orig = editOrig.current
    if (orig) onChange({ ...item, sets: item.sets.map(s => (s.id === orig.id ? orig : s)) })
    closeEdit()
  }
  const [menu, setMenu] = useState(false)
  const [setupOpen, setSetupOpen] = useState(false)
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
  /** Drop the last working set; for one-arm versions drop the whole L/R pair. */
  const removeSet = () => {
    const working = item.sets.map((s, i) => ({ s, i })).filter(x => x.s.kind === 'working')
    if (working.length === 0) return
    const last = working[working.length - 1], prev = working[working.length - 2]
    const drop = new Set<number>([last.i])
    if (last.s.side && prev?.s.side && prev.s.side !== last.s.side) drop.add(prev.i)
    onChange({ ...item, sets: item.sets.filter((_, i) => !drop.has(i)) })
  }
  /** Remove the warm-up row, but never its numbers: they move into a blank set 1, or the row becomes set 1. */
  const toggleWarmup = () => {
    const w = item.sets.find(s => s.kind === 'warmup')
    if (!w) { onChange({ ...item, sets: [newSet('warmup', item.sets[0]?.unit ?? settings.unit, { bar: item.sets[0]?.bar }), ...item.sets] }); return }
    const hasData = w.reps != null || w.weight != null
    if (!hasData) { onChange({ ...item, sets: item.sets.filter(s => s.id !== w.id) }); return }
    const first = item.sets.find(s => s.kind === 'working' && (!w.side || s.side === w.side))
    if (first && first.reps == null && first.weight == null) {
      const moved: SetEntry = { ...first, weight: w.weight, reps: w.reps, plus: w.plus, partials: w.partials, unit: w.unit, note: w.note ?? first.note }
      onChange({ ...item, sets: item.sets.filter(s => s.id !== w.id).map(s => (s.id === first.id ? moved : s)) })
    } else {
      onChange({ ...item, sets: item.sets.map(s => (s.id === w.id ? { ...s, kind: 'working' as const } : s)) })
    }
  }

  const editing = edit ? item.sets.find(s => s.id === edit.setId) : undefined
  const weightVals = (unit: string) => (unit === 'lbs' ? range(0, 600, 5) : range(0, 300, 2.5))
  const setup = { cableHeight: item.cableHeight, benchAngle: item.benchAngle, attachment: item.attachment }
  const setupText = setupLabel(setup)
  const gymNote = workout.gymId ? version.gymNotes?.[workout.gymId] : undefined
  const gymName = workout.gymId ? gyms.find(g => g.id === workout.gymId)?.name : undefined
  const video = version.media?.[0]

  return (
    <div className={'exercise' + (v === 'up' ? ' up' : '')}>
      <div className="row" onContextMenu={e => { e.preventDefault(); setMenu(true) }}
        onTouchStart={e => { const t = e.touches[0]; holdOrigin.current = { x: t.clientX, y: t.clientY }; window.clearTimeout(holdRef.current); holdRef.current = window.setTimeout(() => { swallowNextClick(); setMenu(true) }, 1500) }}
        onTouchEnd={() => window.clearTimeout(holdRef.current)} onTouchCancel={() => window.clearTimeout(holdRef.current)}
        onTouchMove={e => { const t = e.touches[0]; if (holdOrigin.current && Math.hypot(t.clientX - holdOrigin.current.x, t.clientY - holdOrigin.current.y) > 4) window.clearTimeout(holdRef.current) }}>
        <div className="grow">
          <h2 className="exname" onClick={() => setEditVersion(true)}>{version.name} {v === 'down' && <span className="dot red" title="under range" />}</h2>
          <div className="small faint row" style={{ gap: 6, flexWrap: 'wrap' }}>
            <span>{version.equipment}{version.arms === 'one' ? ' · one arm' : ''} · {version.repMin}-{version.repMax} reps{version.machine ? ` · ${version.machine}` : ''}</span>
            {video && <a href={video.url} target="_blank" rel="noreferrer" style={{ color: 'var(--fg2)' }}><PlayIcon /> {video.type === 'tiktok' ? 'TikTok' : 'video'}</a>}
          </div>
          <button className={'chip setup' + (setupText ? '' : ' empty')} onClick={e => { e.stopPropagation(); setSetupOpen(true) }} style={{ marginTop: 4 }}>
            {item.cableHeight != null && <CableIcon h={item.cableHeight} size={16} />}
            {item.benchAngle != null && <BenchIcon angle={item.benchAngle} size={16} />}
            {setupText || 'setup: height · bench · attachment'}
          </button>
          {onSwapTo && item.alts && item.alts.length > 0 && (
            <div className="alts small faint"><span>or</span>
              {item.alts.map(id => { const av = versions.find(x => x.id === id); return av ? <button key={id} className="chip" onClick={() => onSwapTo(id)}>{av.name}</button> : null })}
            </div>
          )}
          {gymNote && <div className="small" style={{ color: 'var(--fg2)', marginTop: 2 }}>📍 {gymName ? shortGym(gymName) + ': ' : ''}{gymNote}</div>}
        </div>
        <button className="iconbtn" onClick={() => setMenu(true)}>⋯</button>
      </div>
      {!compact && <LastTime last={last} other={other} />}
      <div className="stack" style={{ gap: 0, marginTop: 6 }}>
        {item.sets.map((s, i) => (
          <SetRow key={s.id} set={s} label={labels[i]} version={version}
            last={last ? matchLast(s, item.sets, last.item.sets) : undefined}
            improved={last ? improved(s, matchLast(s, item.sets, last.item.sets)) : false}
            onEdit={field => openEdit(s.id, field)}
            onPatch={p => patchSet(s.id, p)} />
        ))}
      </div>
      <div className="setbtns">
        <button className="btn sm" onClick={addSet}>+ set</button>
        <button className="btn sm" onClick={removeSet}>− set</button>
        <button className="btn sm" onClick={toggleWarmup}>{item.sets.some(s => s.kind === 'warmup') ? 'no warm-up' : '+ warm-up'}</button>
        {item.note && <span className="small faint" style={{ alignSelf: 'center' }}>{item.note}</span>}
      </div>

      <Sheet open={!!editing} onClose={cancelEdit}>
        {editing && edit && (() => {
          const lastMatch = last ? matchLast(editing, item.sets, last.item.sets) : undefined
          // blank field: the wheel sits on last time's weight as a hint, and the ± buttons nudge from that same number
          const weightHint = lastMatch?.weight ?? last?.item.sets.find(x => x.kind === 'working' && x.weight != null)?.weight
          // Done / reps → / next set → / a tap on a number: accept whatever the wheels show, even if never scrolled
          const commitShown = () => {
            const s = shown.current, patch: Partial<SetEntry> = {}
            if (edit.field === 'weight') { if (s.weight != null && s.weight !== editing.weight) patch.weight = s.weight }
            else {
              if (s.reps != null && s.reps !== editing.reps) patch.reps = s.reps
              if (s.partials != null && (s.partials || undefined) !== editing.partials) patch.partials = s.partials || undefined
            }
            if (Object.keys(patch).length) patchSet(editing.id, patch)
          }
          const done = () => { commitShown(); closeEdit() }
          return (
          <>
            <div className="row" style={{ marginBottom: 2 }}>
              <h3 className="grow" style={{ margin: 0 }}>Set {labels[item.sets.indexOf(editing)]} · {edit.field}</h3>
              {edit.field === 'weight' && (
                <button className="chip" onClick={() => patchSet(editing.id, { unit: editing.unit === 'kg' ? 'lbs' : 'kg' })}>{editing.unit}</button>
              )}
            </div>
            <div className="sub">{version.name}{last ? ` · last: ${last.item.sets.filter(x => x.reps != null || x.weight != null).map(x => `${x.weight ?? '–'}×${x.reps ?? '–'}${x.plus ? '+' : ''}`).join(' · ')}` : ''}</div>
            {edit.field === 'weight' ? (
              <>
                <Wheel key={editing.unit} values={weightVals(editing.unit)} value={editing.weight} hint={weightHint} onChange={w => patchSet(editing.id, { weight: w })} onPreview={v => { shown.current.weight = v }} />
                <div className="row" style={{ justifyContent: 'center', marginTop: 8 }}>
                  {(editing.unit === 'lbs' ? [-2.5, 2.5] : [-1.25, -0.5, 0.5, 1.25]).map(d => (
                    <button key={d} className="btn sm" onClick={() => patchSet(editing.id, { weight: Math.max(0, Math.round(((editing.weight ?? weightHint ?? 0) + d) * 100) / 100) })}>{d > 0 ? '+' : ''}{d}</button>
                  ))}
                  <span className="grow" style={{ textAlign: 'right', fontWeight: 700, fontSize: 20 }}>{editing.weight ?? '–'} {editing.unit}</span>
                </div>
              </>
            ) : (
              <>
                <div className="wheels">
                  <div style={{ flex: 1 }}><div className="lbl">reps</div>
                    <Wheel values={range(0, 40, 1)} value={editing.reps} hint={lastMatch?.reps ?? version.repMax} onChange={r => patchSet(editing.id, { reps: r })}
                      onPreview={v => { shown.current.reps = v }} onPick={v => { shown.current.reps = v; done() }} /></div>
                  <div style={{ flex: '0 0 96px' }}><div className="lbl">partials</div>
                    <Wheel values={range(0, 5, 1)} value={editing.partials ?? 0} format={v => (v === 0 ? '–' : `${v}p`)} onChange={p => patchSet(editing.id, { partials: p || undefined })}
                      onPreview={v => { shown.current.partials = v }} onPick={v => { shown.current.partials = v; done() }} /></div>
                </div>
                <div className="row" style={{ justifyContent: 'center', marginTop: 8 }}>
                  <button className={'chip' + (editing.plus ? ' on' : '')} onClick={() => patchSet(editing.id, { plus: !editing.plus })}>+ at least</button>
                  <span className="small faint">tap a number to save</span>
                </div>
              </>
            )}
            <input className="note" style={{ marginTop: 10 }} value={editing.note ?? ''} onChange={e => patchSet(editing.id, { note: e.target.value || undefined })} placeholder="Note for this set (grip, notch, how it felt)" />
            <div className="row" style={{ marginTop: 10 }}>
              {edit.field === 'weight' && <button className="btn grow" onClick={() => { commitShown(); editOrig.current = null; openEdit(editing.id, 'reps') }}>reps →</button>}
              {edit.field === 'reps' && (() => {
                const i = item.sets.indexOf(editing); const nxt = item.sets[i + 1]
                return nxt ? <button className="btn grow" onClick={() => { commitShown(); editOrig.current = null; openEdit(nxt.id, 'weight') }}>next set →</button> : null
              })()}
              <button className="btn primary grow" onClick={done}>Done</button>
            </div>
            <div className="small faint" style={{ textAlign: 'center', marginTop: 8 }}>tap outside to cancel</div>
          </>
          )
        })()}
      </Sheet>

      {editVersion && <VersionSheet open onClose={() => setEditVersion(false)} version={version} onSaved={() => setEditVersion(false)} />}
      <SetupSheet open={setupOpen} onClose={() => setSetupOpen(false)} version={version} setup={setup} last={last?.item}
        onChange={p => onChange({ ...item, cableHeight: p.cableHeight, benchAngle: p.benchAngle, attachment: p.attachment })} />
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
