/**
 * Routine planner. Rows support four gestures that must not fight each other:
 *  - tap                 -> edit the version (rep range, sets, notes)
 *  - swipe left          -> reveal delete (SwipeRow; needs clear horizontal intent)
 *  - hold 180 ms + move  -> drag to reorder (dnd-kit TouchSensor)
 *  - hold 1.5 s still    -> options sheet (useHold; cancels the dnd lift first)
 * A lift with no movement does nothing, so the still-hold is the only way to
 * open options by touch. See docs/ARCHITECTURE.md "Gestures" before tuning.
 */
import { useRef, useState, type ReactNode, type TouchEvent } from 'react'
import { DndContext, TouchSensor, MouseSensor, closestCenter, useSensor, useSensors, type DragEndEvent, type DragMoveEvent } from '@dnd-kit/core'
import { SortableContext, useSortable, verticalListSortingStrategy } from '@dnd-kit/sortable'
import { CSS } from '@dnd-kit/utilities'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { useStore } from '../store'
import { lastSession, routineLast } from '../derive'
import { historyIndex, versionIndex } from '../indexes'
import { fmtSet, uid, type Routine } from '../model'
import { workoutFromRoutine } from '../workout'
import { moveItem, pruneGroups, regroupAfterMove } from '../grouping'
import { AddExerciseSheet } from '../components/AddExerciseSheet'
import { Sheet } from '../components/Sheet'
import { SwipeRow } from '../components/SwipeRow'
import { VersionSheet } from '../components/VersionSheet'
import { HOLD_TOLERANCE, useHold } from '../components/useHold'

const DRAG_DELAY_MS = 180 // dnd-kit lift delay on touch; must be well under HOLD_MS

/** Cancel any in-flight dnd-kit drag (its pointer sensors cancel on Escape). */
function cancelDrag() { document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', code: 'Escape', bubbles: true })) }

function SortableRow({ id, children, onDelete, onHold, onTap }: { id: string; children: ReactNode; onDelete: () => void; onHold: () => void; onTap: () => void }) {
  const { attributes, listeners, setNodeRef, transform, transition, isDragging } = useSortable({ id })
  const hold = useHold(onHold, { beforeFire: cancelDrag })
  const dndTouchStart = (listeners as Record<string, (e: TouchEvent) => void> | undefined)?.onTouchStart
  return (
    <div ref={setNodeRef} {...attributes} {...listeners} {...hold}
      onTouchStart={e => { dndTouchStart?.(e); hold.onTouchStart(e) }}
      style={{ transform: CSS.Transform.toString(transform), transition, opacity: isDragging ? .85 : 1, zIndex: isDragging ? 2 : undefined, position: 'relative', boxShadow: isDragging ? '0 10px 30px rgba(0,0,0,.45)' : undefined, borderRadius: 'var(--radius)', touchAction: 'pan-y' }}>
      <SwipeRow onDelete={onDelete} onTap={onTap} disabled={isDragging}>{children}</SwipeRow>
    </div>
  )
}

/** Move one item and apply the group invariants (see src/grouping.ts). */
export function reorderRoutine(r: Routine, from: number, to: number): Routine {
  const next = regroupAfterMove(moveItem(r.items, from, to), r.groups)
  return { ...r, items: next.items, groups: next.groups }
}

export function Plan() {
  const { routineId } = useParams()
  const nav = useNavigate()
  const routines = useStore(s => s.routines)
  const versions = useStore(s => s.versions)
  const workouts = useStore(s => s.workouts)
  const gyms = useStore(s => s.gyms)
  const settings = useStore(s => s.settings)
  const putRoutine = useStore(s => s.putRoutine)
  const deleteRoutine = useStore(s => s.deleteRoutine)
  const putWorkout = useStore(s => s.putWorkout)
  const putGym = useStore(s => s.putGym)
  const r = routines.find(x => x.id === routineId)
  const [adding, setAdding] = useState(false)
  // Default gym: where this routine was last done, else wherever the last workout was.
  const [gymId, setGymId] = useState<string | undefined>(() => (r ? routineLast(r, workouts)?.gymId : undefined) ?? historyIndex(workouts).sorted[0]?.gymId)
  const [gymSheet, setGymSheet] = useState(false)
  const [newGym, setNewGym] = useState('')
  const [renaming, setRenaming] = useState(false)
  const [name, setName] = useState(r?.name ?? '')
  const [opts, setOpts] = useState<number | null>(null)
  const sensors = useSensors(useSensor(MouseSensor, { activationConstraint: { distance: 6 } }), useSensor(TouchSensor, { activationConstraint: { delay: DRAG_DELAY_MS, tolerance: 6 } }))
  const dragMoved = useRef(false)
  const [editV, setEditV] = useState<string | null>(null)
  if (!r) return <div className="page">Routine not found. <Link to="/">Home</Link></div>
  const vmap = versionIndex(versions).byId
  const gmap = new Map(r.groups.map(g => [g.id, g]))

  const removeAt = (i: number) => {
    const items = r.items.filter((_, j) => j !== i)
    putRoutine({ ...r, items, groups: pruneGroups(items, r.groups) })
    setOpts(null)
  }
  const move = (i: number, d: -1 | 1) => {
    const j = i + d; if (j < 0 || j >= r.items.length) return
    putRoutine(reorderRoutine(r, i, j)); setOpts(j)
  }
  const ids = r.items.map(it => it.id)
  const onDragMove = (e: DragMoveEvent) => { if (Math.hypot(e.delta.x, e.delta.y) > HOLD_TOLERANCE) dragMoved.current = true }
  const onDragEnd = (e: DragEndEvent) => {
    const moved = dragMoved.current; dragMoved.current = false
    if (!moved) return // a lift with no movement does nothing; options come only from the still-hold timer
    const from = ids.indexOf(String(e.active.id))
    const to = e.over ? ids.indexOf(String(e.over.id)) : -1
    if (from < 0 || to < 0 || to === from) return
    putRoutine(reorderRoutine(r, from, to))
  }
  const start = () => {
    const w = workoutFromRoutine(r, versions, settings.unit, workouts, gymId)
    w.startedAt = Date.now()
    putWorkout(w); nav(`/workout/${w.id}`, { replace: true })
  }
  return (
    <div className="page">
      <div className="topbar">
        <Link className="iconbtn" to="/" aria-label="Home">‹</Link>
        <h1 onClick={() => setRenaming(true)}>{r.name}</h1>
        <button className="chip" onClick={() => setGymSheet(true)}>{gyms.find(g => g.id === gymId)?.name.replace('Ultradynamic Fitness - ', '') ?? 'gym?'}</button>
      </div>
      <DndContext sensors={sensors} collisionDetection={closestCenter} onDragStart={() => { dragMoved.current = false }} onDragMove={onDragMove} onDragEnd={onDragEnd} onDragCancel={() => { dragMoved.current = false }}>
      <SortableContext items={ids} strategy={verticalListSortingStrategy}>
      <div className="stack" style={{ gap: 8 }}>
        {r.items.map((it, i) => {
          const v = vmap.get(it.versionId); if (!v) return null
          const last = lastSession(v.id, workouts, versions)
          const g = it.groupId ? gmap.get(it.groupId) : undefined
          return (
            <SortableRow key={it.id} id={it.id} onDelete={() => removeAt(i)} onHold={() => setOpts(i)} onTap={() => setEditV(it.versionId)}>
              <div className="card" style={{ padding: '12px 14px', borderLeft: g ? '3px solid var(--accent)' : undefined }}>
                <div className="row"><b className="grow">{v.name}</b>{g && <span className="small" style={{ color: 'var(--accent)' }}>{g.type}</span>}</div>
                <div className="small faint" style={{ fontStyle: 'italic' }}>
                  {last ? `${last.daysAgo}d ago · ` + last.item.sets.filter(s => s.reps != null).map(fmtSet).join(' · ') : 'first time'}
                </div>
              </div>
            </SortableRow>
          )
        })}
        {r.items.length === 0 && <div className="muted">No exercises yet. Add some, then start.</div>}
        {r.items.length > 0 && <div className="small faint" style={{ textAlign: 'center' }}>tap to edit · swipe left to delete · hold to drag · hold still for options</div>}
      </div>
      </SortableContext>
      </DndContext>
      <div className="row" style={{ marginTop: 14 }}>
        <button className="btn grow" onClick={() => setAdding(true)}>+ Add</button>
        <Link className="btn grow" to={`/plan/${r.id}/overview`}>Order & groups</Link>
      </div>
      <button className="btn primary block" style={{ marginTop: 12, minHeight: 56, fontSize: 19 }} onClick={start} disabled={r.items.length === 0}>Start workout</button>
      <button className="btn ghost block danger" style={{ marginTop: 20 }} onClick={() => { if (confirm('Delete this routine? History is kept.')) { deleteRoutine(r.id); nav('/') } }}>Delete routine</button>

      <AddExerciseSheet open={adding} onClose={() => setAdding(false)} onPick={v => putRoutine({ ...r, items: [...r.items, { id: uid(), versionId: v.id }] })} />
      <Sheet open={gymSheet} onClose={() => setGymSheet(false)} title="Which gym?">
        <div className="stack">
          {gyms.map(g => <button key={g.id} className={'btn' + (g.id === gymId ? ' primary' : '')} onClick={() => { setGymId(g.id); setGymSheet(false) }}>{g.name}</button>)}
          <div className="row"><input className="search grow" value={newGym} onChange={e => setNewGym(e.target.value)} placeholder="New gym name" /><button className="btn" onClick={() => { if (!newGym.trim()) return; const g = { id: uid(), name: newGym.trim() }; putGym(g); setGymId(g.id); setNewGym(''); setGymSheet(false) }}>Add</button></div>
        </div>
      </Sheet>
      <Sheet open={opts != null} onClose={() => setOpts(null)} title={opts != null ? vmap.get(r.items[opts]?.versionId)?.name : ''}>
        {opts != null && r.items[opts] && (
          <div className="stack">
            <div className="row"><button className="btn grow" onClick={() => move(opts, -1)}>↑ Move up</button><button className="btn grow" onClick={() => move(opts, 1)}>↓ Move down</button></div>
            <button className="btn" onClick={() => { setEditV(r.items[opts].versionId); setOpts(null) }}>Edit exercise (rep range, sets, notes)</button>
            <button className="btn" onClick={() => { setOpts(null); nav(`/plan/${r.id}/overview`) }}>Reorder & groups</button>
            <button className="btn danger" onClick={() => removeAt(opts)}>🗑 Remove from routine</button>
          </div>
        )}
      </Sheet>
      {editV && <VersionSheet open onClose={() => setEditV(null)} version={vmap.get(editV)} onSaved={() => setEditV(null)} />}
      <Sheet open={renaming} onClose={() => setRenaming(false)} title="Rename routine">
        <div className="stack"><input className="search" value={name} onChange={e => setName(e.target.value)} /><button className="btn primary" onClick={() => { putRoutine({ ...r, name: name.trim() || r.name }); setRenaming(false) }}>Save</button></div>
      </Sheet>
    </div>
  )
}
