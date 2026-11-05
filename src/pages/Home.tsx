/**
 * Home: routines ordered by "longest since last done" (never-done first), an
 * in-progress banner, quick actions, recent history. If a workout is in progress
 * we jump straight into it unless the user explicitly backed out of it
 * (sessionStorage 'jimmy.left', set by the ‹ button on Live).
 */
import { useEffect, useMemo, useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { useStore } from '../store'
import { historyIndex, versionIndex } from '../indexes'
import { daysBetween, today, uid, type Routine } from '../model'
import { Sheet } from '../components/Sheet'
import { applyUpdate } from '../pwa'

const HISTORY_ROWS = 8

export function Home() {
  const routines = useStore(s => s.routines)
  const workouts = useStore(s => s.workouts)
  const versions = useStore(s => s.versions)
  const putRoutine = useStore(s => s.putRoutine)
  const putWorkout = useStore(s => s.putWorkout)
  const updateReady = useStore(s => s.updateReady)
  const nav = useNavigate()
  const [naming, setNaming] = useState(false)
  const [name, setName] = useState('')
  const vmap = versionIndex(versions).byId
  const h = historyIndex(workouts)
  const active = h.active
  const activeId = active?.id
  useEffect(() => {
    if (activeId && sessionStorage.getItem('jimmy.left') !== activeId) nav(`/workout/${activeId}`, { replace: true })
  }, [activeId, nav])
  const history = h.sorted.filter(w => w.endedAt).slice(0, HISTORY_ROWS)
  const ordered = useMemo(() => {
    const lastDate = (r: Routine) => h.lastFinishedByRoutine.get(r.id)?.date ?? '0'
    return routines.slice().sort((a, b) => lastDate(a).localeCompare(lastDate(b)))
  }, [routines, h])

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
      {updateReady && (
        <button className="banner" onClick={() => void applyUpdate()}>A new version of Jimmy is ready · tap to install</button>
      )}
      {active && (
        <Link to={`/workout/${active.id}`} className="card routine" style={{ marginBottom: 12, outline: '2px solid var(--accent)' }}>
          <div className="small" style={{ color: 'var(--accent)', fontWeight: 700 }}>IN PROGRESS</div>
          <h2>{active.name}</h2>
          <div className="small muted">{active.items.map(i => vmap.get(i.versionId)?.name).filter(Boolean).join(' · ')}</div>
        </Link>
      )}
      <div className="stack">
        {ordered.map(r => {
          const last = h.lastFinishedByRoutine.get(r.id)
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
