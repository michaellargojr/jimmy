/**
 * Thin adapter: maps a routine or a live workout onto the generic <Overview>
 * editor (OvItem[] + groups) and writes the result back.
 */
import { useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { useStore } from '../store'
import { Overview, type OvItem } from '../components/Overview'
import { AddExerciseSheet } from '../components/AddExerciseSheet'
import { newItem, itemDone } from '../workout'
import { uid, type Group } from '../model'

export function OverviewPage({ mode }: { mode: 'workout' | 'routine' }) {
  const { id, routineId } = useParams()
  const workouts = useStore(s => s.workouts)
  const routines = useStore(s => s.routines)
  const versions = useStore(s => s.versions)
  const settings = useStore(s => s.settings)
  const putWorkout = useStore(s => s.putWorkout)
  const putRoutine = useStore(s => s.putRoutine)
  const [adding, setAdding] = useState(false)
  if (mode === 'workout') {
    const w = workouts.find(x => x.id === id)
    if (!w) return <div className="page">Workout not found. <Link to="/">Home</Link></div>
    const items: OvItem[] = w.items.map(i => ({ id: i.id, versionId: i.versionId, groupId: i.groupId, done: itemDone(i) }))
    const onChange = (next: OvItem[], groups: Group[]) => {
      const byId = new Map(w.items.map(i => [i.id, i]))
      putWorkout({ ...w, groups, items: next.flatMap(n => { const it = byId.get(n.id); return it ? [{ ...it, groupId: n.groupId }] : [] }) })
    }
    return (
      <div className="page">
        <div className="topbar"><Link className="iconbtn" to={`/workout/${w.id}`} aria-label="Back">‹</Link><h1>Order & groups</h1></div>
        <Overview items={items} groups={w.groups} versions={versions} onChange={onChange} onAdd={() => setAdding(true)} />
        <AddExerciseSheet open={adding} onClose={() => setAdding(false)} onPick={v => putWorkout({ ...w, items: [...w.items, newItem(v, settings.unit, workouts)] })} />
      </div>
    )
  }
  const r = routines.find(x => x.id === routineId)
  if (!r) return <div className="page">Routine not found. <Link to="/">Home</Link></div>
  const items: OvItem[] = r.items.map(it => ({ id: it.id, versionId: it.versionId, groupId: it.groupId }))
  const onChange = (next: OvItem[], groups: Group[]) => putRoutine({ ...r, groups, items: next.map(n => ({ id: n.id, versionId: n.versionId, groupId: n.groupId })) })
  return (
    <div className="page">
      <div className="topbar"><Link className="iconbtn" to={`/plan/${r.id}`} aria-label="Back">‹</Link><h1>{r.name}: order & groups</h1></div>
      <Overview items={items} groups={r.groups} versions={versions} onChange={onChange} onAdd={() => setAdding(true)} />
      <AddExerciseSheet open={adding} onClose={() => setAdding(false)} onPick={v => putRoutine({ ...r, items: [...r.items, { id: uid(), versionId: v.id }] })} />
    </div>
  )
}
