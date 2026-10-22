import { useMemo, useState } from 'react'
import { MUSCLES, type MuscleGroup, type Version } from '../model'
import { useStore } from '../store'
import { lastSession } from '../derive'
import { Sheet } from './Sheet'
import { VersionSheet } from './VersionSheet'

export function AddExerciseSheet({ open, onClose, onPick }: { open: boolean; onClose: () => void; onPick: (v: Version) => void }) {
  const { exercises, versions, workouts } = useStore()
  const [q, setQ] = useState('')
  const [muscle, setMuscle] = useState<MuscleGroup | null>(null)
  const [creating, setCreating] = useState<{ name: string; muscle: MuscleGroup } | null>(null)

  const results = useMemo(() => {
    const needle = q.trim().toLowerCase()
    const exById = new Map(exercises.map(e => [e.id, e]))
    const match = (s: string) => s.toLowerCase().includes(needle)
    const vs = versions
      .filter(v => { const ex = exById.get(v.exerciseId); return (!muscle || ex?.muscleGroup === muscle) && (!needle || match(v.name) || (ex && (match(ex.name) || ex.aliases.some(match)))) })
      .map(v => ({ v, ex: exById.get(v.exerciseId)!, last: lastSession(v.id, workouts, versions) }))
      .sort((a, b) => (b.last ? 1 : 0) - (a.last ? 1 : 0) || a.v.name.localeCompare(b.v.name))
    const haveVersion = new Set(versions.map(v => v.exerciseId))
    const bases = exercises
      .filter(e => !haveVersion.has(e.id) && (!muscle || e.muscleGroup === muscle) && (!needle || match(e.name) || e.aliases.some(match)))
      .sort((a, b) => a.name.localeCompare(b.name))
    return { vs: vs.slice(0, needle ? 40 : 60), bases: bases.slice(0, needle ? 40 : 30) }
  }, [q, muscle, exercises, versions, workouts])

  return (
    <>
      <Sheet open={open && !creating} onClose={onClose} title="Add exercise" side="top">
        <input className="search" autoFocus value={q} onChange={e => setQ(e.target.value)} placeholder="Type a few letters…" />
        <div className="row" style={{ flexWrap: 'nowrap', overflowX: 'auto', gap: 6, margin: '10px 0' }}>
          <button className={'chip' + (muscle == null ? ' on' : '')} onClick={() => setMuscle(null)}>all</button>
          {MUSCLES.map(m => <button key={m} className={'chip' + (muscle === m ? ' on' : '')} onClick={() => setMuscle(m)}>{m}</button>)}
        </div>
        <div>
          {results.vs.map(({ v, ex, last }) => (
            <button key={v.id} className="result" style={{ width: '100%', textAlign: 'left' }} onClick={() => { onPick(v); onClose(); setQ('') }}>
              <div className="grow">
                <div style={{ fontWeight: 600 }}>{v.name}</div>
                <div className="small faint">{ex.muscleGroup} · {v.equipment}{v.arms === 'one' ? ' · one arm' : ''}{last ? ` · ${last.daysAgo}d ago` : ''}</div>
              </div>
              <span className="faint">+</span>
            </button>
          ))}
          {results.bases.map(e => (
            <button key={e.id} className="result" style={{ width: '100%', textAlign: 'left' }} onClick={() => setCreating({ name: e.name, muscle: e.muscleGroup })}>
              <div className="grow"><div>{e.name}</div><div className="small faint">{e.muscleGroup} · library</div></div>
              <span className="faint">new ›</span>
            </button>
          ))}
          {q.trim() && (
            <button className="result" style={{ width: '100%', textAlign: 'left' }} onClick={() => setCreating({ name: q.trim(), muscle: muscle ?? 'Back' })}>
              <div className="grow"><div>Create “{q.trim()}”</div><div className="small faint">new exercise</div></div>
              <span className="faint">new ›</span>
            </button>
          )}
        </div>
      </Sheet>
      {creating && (
        <VersionSheet open onClose={() => setCreating(null)} exerciseName={creating.name} muscle={creating.muscle}
          onSaved={v => { setCreating(null); onPick(v); onClose(); setQ('') }} />
      )}
    </>
  )
}
