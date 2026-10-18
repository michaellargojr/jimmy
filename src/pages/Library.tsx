import { useState } from 'react'
import { Link } from 'react-router-dom'
import { useStore } from '../store'
import { MUSCLES, type Version } from '../model'
import { lastSession } from '../derive'
import { VersionSheet } from '../components/VersionSheet'

export function Library() {
  const { exercises, versions, workouts } = useStore()
  const [edit, setEdit] = useState<Version | null>(null)
  const [q, setQ] = useState('')
  const exById = new Map(exercises.map(e => [e.id, e]))
  const needle = q.toLowerCase()
  return (
    <div className="page">
      <div className="topbar"><Link className="iconbtn" to="/">‹</Link><h1>Exercises</h1></div>
      <input className="search" value={q} onChange={e => setQ(e.target.value)} placeholder="Filter" />
      {MUSCLES.map(m => {
        const vs = versions.filter(v => exById.get(v.exerciseId)?.muscleGroup === m && (!needle || v.name.toLowerCase().includes(needle))).sort((a, b) => a.name.localeCompare(b.name))
        if (vs.length === 0) return null
        return (
          <div key={m} style={{ marginTop: 16 }}>
            <div className="small faint" style={{ marginBottom: 6 }}>{m}</div>
            <div className="stack" style={{ gap: 6 }}>
              {vs.map(v => {
                const last = lastSession(v.id, workouts, versions)
                return (
                  <button key={v.id} className="card row" style={{ padding: '10px 14px', textAlign: 'left' }} onClick={() => setEdit(v)}>
                    <div className="grow"><div style={{ fontWeight: 600 }}>{v.name}</div><div className="small faint">{v.equipment}{v.arms === 'one' ? ' · one arm' : ''} · {v.repMin}-{v.repMax} · {v.defaultSets} sets{v.defaultWarmup ? ' + W' : ''}</div></div>
                    <span className="small faint">{last ? `${last.daysAgo}d` : ''}</span>
                  </button>
                )
              })}
            </div>
          </div>
        )
      })}
      {edit && <VersionSheet open onClose={() => setEdit(null)} version={edit} onSaved={() => setEdit(null)} />}
    </div>
  )
}
