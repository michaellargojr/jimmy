import { useState } from 'react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { useStore } from '../store'
import { lastSession, routineLast } from '../derive'
import { fmtSet, uid } from '../model'
import { workoutFromRoutine } from '../workout'
import { AddExerciseSheet } from '../components/AddExerciseSheet'
import { Sheet } from '../components/Sheet'

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
  if (!r) return <div className="page">Routine not found. <Link to="/">Home</Link></div>
  const vmap = new Map(versions.map(v => [v.id, v]))
  const gmap = new Map(r.groups.map(g => [g.id, g]))

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
      <div className="stack" style={{ gap: 8 }}>
        {r.items.map((it, i) => {
          const v = vmap.get(it.versionId); if (!v) return null
          const last = lastSession(v.id, workouts, versions)
          const g = it.groupId ? gmap.get(it.groupId) : undefined
          return (
            <div key={i} className="card" style={{ padding: '12px 14px', borderLeft: g ? '3px solid var(--accent)' : undefined }}>
              <div className="row"><b className="grow">{v.name}</b>{g && <span className="small" style={{ color: 'var(--accent)' }}>{g.type}</span>}</div>
              <div className="small faint" style={{ fontStyle: 'italic' }}>
                {last ? `${last.daysAgo}d ago · ` + last.item.sets.filter(s => s.reps != null).map(fmtSet).join(' · ') : 'first time'}
              </div>
            </div>
          )
        })}
        {r.items.length === 0 && <div className="muted">No exercises yet. Add some, then start.</div>}
      </div>
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
      <Sheet open={renaming} onClose={() => setRenaming(false)} title="Rename routine">
        <div className="stack"><input className="search" value={name} onChange={e => setName(e.target.value)} /><button className="btn primary" onClick={() => { putRoutine({ ...r, name: name.trim() || r.name }); setRenaming(false) }}>Save</button></div>
      </Sheet>
    </div>
  )
}
