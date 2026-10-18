import { useState } from 'react'
import { DndContext, TouchSensor, MouseSensor, closestCenter, useSensor, useSensors, type DragEndEvent } from '@dnd-kit/core'
import { SortableContext, arrayMove, useSortable, verticalListSortingStrategy } from '@dnd-kit/sortable'
import { CSS } from '@dnd-kit/utilities'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { useStore } from '../store'
import { lastSession, routineLast } from '../derive'
import { fmtSet, uid } from '../model'
import { workoutFromRoutine } from '../workout'
import type { Routine } from '../model'
import { AddExerciseSheet } from '../components/AddExerciseSheet'
import { Sheet } from '../components/Sheet'
import { SwipeRow } from '../components/SwipeRow'
import { VersionSheet } from '../components/VersionSheet'

function SortableRow({ id, children, onDelete }: { id: string; children: React.ReactNode; onDelete: () => void }) {
  const { attributes, listeners, setNodeRef, transform, transition, isDragging } = useSortable({ id })
  return (
    <div ref={setNodeRef} {...attributes} {...listeners}
      style={{ transform: CSS.Transform.toString(transform), transition, opacity: isDragging ? .85 : 1, zIndex: isDragging ? 2 : undefined, position: 'relative', boxShadow: isDragging ? '0 10px 30px rgba(0,0,0,.45)' : undefined, borderRadius: 'var(--radius)', touchAction: 'pan-y' }}>
      <SwipeRow onDelete={onDelete} disabled={isDragging}>{children}</SwipeRow>
    </div>
  )
}

export function reorderRoutine(r: Routine, from: number, to: number): Routine {
  const moved = arrayMove(r.items, from, to)
  const items = moved.map((it, i) => {
    if (!it.groupId) return it
    const prev = moved[i - 1], next = moved[i + 1]
    const adjacent = (prev && prev.groupId === it.groupId) || (next && next.groupId === it.groupId)
    return adjacent ? it : { ...it, groupId: undefined }
  })
  return { ...r, items, groups: r.groups.filter(g => items.some(i => i.groupId === g.id)) }
}

export function Plan() {
  const { routineId } = useParams()
  const nav = useNavigate()
  const { routines, versions, workouts, gyms, settings, putRoutine, deleteRoutine, putWorkout, putGym } = useStore()
  const r = routines.find(x => x.id === routineId)
  const [adding, setAdding] = useState(false)
  const [gymId, setGymId] = useState<string | undefined>(() => routineLast(r!, workouts)?.gymId ?? workouts.slice().sort((a, b) => b.date.localeCompare(a.date))[0]?.gymId)
  const [gymSheet, setGymSheet] = useState(false)
  const [newGym, setNewGym] = useState('')
  const [renaming, setRenaming] = useState(false)
  const [name, setName] = useState(r?.name ?? '')
  const [opts, setOpts] = useState<number | null>(null)
  const sensors = useSensors(useSensor(MouseSensor, { activationConstraint: { distance: 6 } }), useSensor(TouchSensor, { activationConstraint: { delay: 280, tolerance: 8 } }))
  const [editV, setEditV] = useState<string | null>(null)
  if (!r) return <div className="page">Routine not found. <Link to="/">Home</Link></div>
  const vmap = new Map(versions.map(v => [v.id, v]))
  const gmap = new Map(r.groups.map(g => [g.id, g]))

  const removeAt = (i: number) => {
    const items = r.items.filter((_, j) => j !== i)
    putRoutine({ ...r, items, groups: r.groups.filter(g => items.some(it => it.groupId === g.id)) })
    setOpts(null)
  }
  const move = (i: number, d: -1 | 1) => {
    const j = i + d; if (j < 0 || j >= r.items.length) return
    const items = r.items.slice(); const [it] = items.splice(i, 1); items.splice(j, 0, it)
    putRoutine({ ...r, items }); setOpts(j)
  }
  const ids = r.items.map((it, i) => `${it.versionId}-${i}`)
  const onDragEnd = (e: DragEndEvent) => {
    const from = ids.indexOf(String(e.active.id))
    const to = e.over ? ids.indexOf(String(e.over.id)) : -1
    const moved = Math.hypot(e.delta.x, e.delta.y) > 6
    if (!moved || to < 0 || to === from) { setOpts(from); return } // held without moving: options
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
        <Link className="iconbtn" to="/">‹</Link>
        <h1 onClick={() => setRenaming(true)}>{r.name}</h1>
        <button className="chip" onClick={() => setGymSheet(true)}>{gyms.find(g => g.id === gymId)?.name.replace('Ultradynamic Fitness - ', '') ?? 'gym?'}</button>
      </div>
      <DndContext sensors={sensors} collisionDetection={closestCenter} onDragEnd={onDragEnd}>
      <SortableContext items={ids} strategy={verticalListSortingStrategy}>
      <div className="stack" style={{ gap: 8 }}>
        {r.items.map((it, i) => {
          const v = vmap.get(it.versionId); if (!v) return null
          const last = lastSession(v.id, workouts, versions)
          const g = it.groupId ? gmap.get(it.groupId) : undefined
          return (
            <SortableRow key={ids[i]} id={ids[i]} onDelete={() => removeAt(i)}>
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
        {r.items.length > 0 && <div className="small faint" style={{ textAlign: 'center' }}>swipe left to delete · hold to drag or for options</div>}
      </div>
      </SortableContext>
      </DndContext>
      <div className="row" style={{ marginTop: 14 }}>
        <button className="btn grow" onClick={() => setAdding(true)}>+ Add</button>
        <Link className="btn grow" to={`/plan/${r.id}/overview`}>Order & groups</Link>
      </div>
      <button className="btn primary block" style={{ marginTop: 12, minHeight: 56, fontSize: 19 }} onClick={start} disabled={r.items.length === 0}>Start workout</button>
      <button className="btn ghost block danger" style={{ marginTop: 20 }} onClick={() => { if (confirm('Delete this routine? History is kept.')) { deleteRoutine(r.id); nav('/') } }}>Delete routine</button>

      <AddExerciseSheet open={adding} onClose={() => setAdding(false)} onPick={v => putRoutine({ ...r, items: [...r.items, { versionId: v.id }] })} />
      <Sheet open={gymSheet} onClose={() => setGymSheet(false)} title="Which gym?">
        <div className="stack">
          {gyms.map(g => <button key={g.id} className={'btn' + (g.id === gymId ? ' primary' : '')} onClick={() => { setGymId(g.id); setGymSheet(false) }}>{g.name}</button>)}
          <div className="row"><input className="search grow" value={newGym} onChange={e => setNewGym(e.target.value)} placeholder="New gym name" /><button className="btn" onClick={() => { if (!newGym.trim()) return; const g = { id: uid(), name: newGym.trim() }; putGym(g); setGymId(g.id); setNewGym(''); setGymSheet(false) }}>Add</button></div>
        </div>
      </Sheet>
      <Sheet open={opts != null} onClose={() => setOpts(null)} title={opts != null ? vmap.get(r.items[opts]?.versionId)?.name : ''}>
        {opts != null && (
          <div className="stack">
            <div className="row"><button className="btn grow" onClick={() => move(opts, -1)}>↑ Move up</button><button className="btn grow" onClick={() => move(opts, 1)}>↓ Move down</button></div>
            <button className="btn" onClick={() => { setEditV(r.items[opts].versionId); setOpts(null) }}>Edit exercise (rep range, sets, notes)</button>
            <button className="btn" onClick={() => { setOpts(null); nav(`/plan/${r.id}/overview`) }}>Reorder & groups</button>
            <button className="btn danger" onClick={() => removeAt(opts)}>🗑 Remove from routine</button>
          </div>
        )}
      </Sheet>
      {editV && <VersionSheet open onClose={() => setEditV(null)} version={versions.find(v => v.id === editV)} onSaved={() => setEditV(null)} />}
      <Sheet open={renaming} onClose={() => setRenaming(false)} title="Rename routine">
        <div className="stack"><input className="search" value={name} onChange={e => setName(e.target.value)} /><button className="btn primary" onClick={() => { putRoutine({ ...r, name: name.trim() || r.name }); setRenaming(false) }}>Save</button></div>
      </Sheet>
    </div>
  )
}
