import { useMemo, useState } from 'react'
import { useStore } from '../store'
import { Sheet } from './Sheet'
import { parseNote, planImport } from '../importer'
import { uid, type Exercise, type Version, type Workout } from '../model'
import { shortGym } from './VersionSheet'

/** Paste an Apple Note, preview the match, import as a finished workout on that date. */
export function ImportSheet({ open, onClose }: { open: boolean; onClose: () => void }) {
  const { versions, exercises, gyms, workouts, settings, putExercise, putVersion, putWorkout } = useStore()
  const [text, setText] = useState('')
  const [gymId, setGymId] = useState<string | undefined>(() => workouts.slice().sort((a, b) => b.date.localeCompare(a.date))[0]?.gymId)
  const plan = useMemo(() => (text.trim() ? planImport(parseNote(text, settings.unit), versions, exercises) : undefined), [text, versions, exercises, settings.unit])
  const total = plan?.items.reduce((n, i) => n + i.entry.sets.length, 0) ?? 0

  const doImport = () => {
    if (!plan || plan.items.length === 0) return
    const exByName = new Map(exercises.map(e => [e.name.toLowerCase(), e]))
    const items = plan.items.map(it => {
      let v = it.version
      if (!v && it.create) {
        let ex: Exercise | undefined = exByName.get(it.create.name.toLowerCase())
        if (!ex) { ex = { id: uid(), name: it.create.name, muscleGroup: it.create.muscle, aliases: [] }; putExercise(ex); exByName.set(ex.name.toLowerCase(), ex) }
        v = { id: uid(), exerciseId: ex.id, name: it.create.name, equipment: it.create.equipment, arms: it.create.arms, repMin: 5, repMax: 8, defaultWarmup: it.entry.sets.some(s => s.kind === 'warmup'), defaultSets: Math.max(1, it.entry.sets.filter(s => s.kind === 'working').length), gymNotes: {}, media: [], changes: [] } satisfies Version
        putVersion(v)
      }
      return { id: uid(), versionId: v!.id, sets: it.entry.sets, note: it.entry.note }
    })
    const started = new Date(plan.date + 'T09:00:00').getTime()
    const w: Workout = { id: uid(), name: plan.title ?? 'Imported workout', date: plan.date, gymId, startedAt: started, endedAt: started + 60 * 60 * 1000, notes: 'Imported from Apple Notes', items, groups: [] }
    putWorkout(w)
    setText(''); onClose()
    alert(`Imported ${items.length} exercises, ${total} sets, dated ${plan.date}.`)
  }

  return (
    <Sheet open={open} onClose={onClose} title="Import from Apple Notes">
      <div className="stack">
        <textarea className="ta" autoFocus value={text} onChange={e => setText(e.target.value)} style={{ minHeight: 140, fontSize: 14 }}
          placeholder={'Paste the note. One exercise name per line, sets under it:\nIncline Chest Fly Machine\n15kg - warm up - 10+\n20kg - 8\n22.5kg - 6 p2'} />
        {plan && (
          <div className="stack small" style={{ gap: 4 }}>
            <div className="muted">{plan.date}{plan.title ? ` · ${plan.title}` : ''} · {plan.items.length} exercises · {total} sets</div>
            {plan.items.map((it, i) => (
              <div key={i} className="row" style={{ alignItems: 'flex-start' }}>
                <span style={{ width: 18 }}>{it.version ? '✓' : '+'}</span>
                <span className="grow">{it.version ? it.version.name : `${it.create?.name} (new · ${it.create?.muscle} · ${it.create?.equipment}${it.create?.arms === 'one' ? ' · one arm' : ''})`}
                  <span className="faint"> · {it.entry.sets.length} sets</span></span>
              </div>
            ))}
            {plan.warnings.map((w, i) => <div key={i} style={{ color: 'var(--amber)' }}>⚠ {w}</div>)}
          </div>
        )}
        {gyms.length > 0 && (
          <div className="row" style={{ gap: 6, flexWrap: 'wrap' }}>
            <span className="small muted">Gym</span>
            {gyms.map(g => <button key={g.id} className={'chip' + (g.id === gymId ? ' on' : '')} onClick={() => setGymId(g.id === gymId ? undefined : g.id)}>{shortGym(g.name)}</button>)}
          </div>
        )}
        <button className="btn primary block" disabled={!plan || plan.items.length === 0} onClick={doImport}>Import as workout</button>
        <div className="small faint">“+” rows create a new exercise version with the guessed muscle and equipment; fix them later from the Exercises page.</div>
      </div>
    </Sheet>
  )
}
