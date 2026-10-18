import { useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { useStore } from '../store'
import { routineLast } from '../derive'
import { daysBetween, today, uid, type Routine } from '../model'
import { Sheet } from '../components/Sheet'

export function Home() {
  const { routines, workouts, versions, putRoutine, putWorkout } = useStore()
  const nav = useNavigate()
  const [naming, setNaming] = useState(false)
  const [name, setName] = useState('')
  const vmap = new Map(versions.map(v => [v.id, v]))
  const active = workouts.find(w => w.startedAt && !w.endedAt)
  const history = workouts.slice().sort((a, b) => b.date.localeCompare(a.date)).filter(w => w.endedAt).slice(0, 8)

  const createRoutine = () => {
    const r: Routine = { id: uid(), name: name.trim() || 'New routine', items: [], groups: [] }
    putRoutine(r); setNaming(false); setName(''); nav(`/plan/${r.id}`)
  }
  const quick = () => {
    const w = { id: uid(), name: 'Quick workout', date: today(), startedAt: Date.now(), items: [], groups: [] }
    putWorkout(w); nav(`/workout/${w.id}`)
  }

  return (
    <div className="page">
      <div className="topbar">
        <h1>Jimmy</h1>
        <Link className="iconbtn" to="/library" aria-label="Exercises">☰</Link>
        <Link className="iconbtn" to="/settings" aria-label="Settings">⚙︎</Link>
      </div>
      {active && (
        <Link to={`/workout/${active.id}`} className="card routine" style={{ marginBottom: 12, outline: '2px solid var(--accent)' }}>
          <div className="small" style={{ color: 'var(--accent)', fontWeight: 700 }}>IN PROGRESS</div>
          <h2>{active.name}</h2>
          <div className="small muted">{active.items.map(i => vmap.get(i.versionId)?.name).filter(Boolean).join(' · ')}</div>
        </Link>
      )}
      <div className="stack">
        {routines.map(r => {
          const last = routineLast(r, workouts)
          const templateNames = r.items.map(i => vmap.get(i.versionId)?.name).filter(Boolean) as string[]
          const lastNames = last ? (last.items.map(i => vmap.get(i.versionId)?.name).filter(Boolean) as string[]) : []
          const added = lastNames.filter(n => !templateNames.includes(n))
          return (
            <Link key={r.id} to={`/plan/${r.id}`} className="card routine">
              <div className="row"><h2 className="grow">{r.name}</h2><span className="small muted">{last ? `${daysBetween(last.date, today())}d ago` : 'never'}</span></div>
              <div className="small muted">{templateNames.join(' · ') || 'empty - tap to plan'}</div>
              {added.length > 0 && <div className="small faint" style={{ marginTop: 4 }}>+ last time: {added.join(', ')}</div>}
            </Link>
          )
        })}
      </div>
      <div className="row" style={{ marginTop: 14 }}>
        <button className="btn grow" onClick={() => setNaming(true)}>New routine</button>
        <button className="btn grow" onClick={quick}>Quick workout</button>
      </div>
      {history.length > 0 && (
        <>
          <div className="hr" style={{ margin: '18px 0 10px' }} />
          <div className="small faint" style={{ marginBottom: 6 }}>History</div>
          <div className="stack" style={{ gap: 6 }}>
            {history.map(w => (
              <Link key={w.id} to={`/workout/${w.id}`} className="row small" style={{ padding: '8px 4px' }}>
                <span className="muted" style={{ width: 92 }}>{w.date.slice(5)}</span>
                <span className="grow">{w.name}</span>
                <span className="faint">{w.items.length} ex</span>
              </Link>
            ))}
          </div>
        </>
      )}
      <Sheet open={naming} onClose={() => setNaming(false)} title="New routine">
        <div className="stack">
          <input className="search" autoFocus value={name} onChange={e => setName(e.target.value)} placeholder="e.g. Legs" />
          <button className="btn primary block" onClick={createRoutine}>Create</button>
        </div>
      </Sheet>
    </div>
  )
}
