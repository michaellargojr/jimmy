import { useEffect, useRef, useState } from 'react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { useStore } from '../store'
import { elapsed } from '../derive'
import { uid, type Version, type WorkoutItem } from '../model'
import { itemDone, newItem, panes } from '../workout'
import { ExerciseCard } from '../components/ExerciseCard'
import { AddExerciseSheet } from '../components/AddExerciseSheet'
import { Sheet } from '../components/Sheet'
import { exportSnapshot } from '../db'
import { shareJson } from '../share'
import { IdeaFab } from '../components/IdeaFab'

export function Live() {
  const { id } = useParams()
  const nav = useNavigate()
  const { workouts, versions, gyms, settings, putWorkout, deleteWorkout, putGym } = useStore()
  const w = workouts.find(x => x.id === id)
  const [adding, setAdding] = useState<{ afterItemId?: string; swapItemId?: string } | null>(null)
  const [ending, setEnding] = useState(false)
  const [notes, setNotes] = useState(w?.notes ?? '')
  const [gymSheet, setGymSheet] = useState(false)
  const [newGym, setNewGym] = useState('')
  const [, tick] = useState(0)
  const pagerRef = useRef<HTMLDivElement>(null)
  const [cur, setCur] = useState(0)
  useEffect(() => { const t = setInterval(() => tick(x => x + 1), 1000); return () => clearInterval(t) }, [])
  useEffect(() => {
    const saved = Number(localStorage.getItem(`jimmy.pane.${id}`) ?? 0)
    if (saved > 0) setTimeout(() => { const el = pagerRef.current?.children[saved] as HTMLElement | undefined; el?.scrollIntoView({ block: 'start' }) }, 30)
    sessionStorage.removeItem('jimmy.left')
    setNotes(workouts.find(x => x.id === id)?.notes ?? '')
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [id])
  if (!w) return <div className="page">Workout not found. <Link to="/">Home</Link></div>
  const vmap = new Map(versions.map(v => [v.id, v]))
  const ps = panes(w.items)
  const running = !!w.startedAt && !w.endedAt

  const updateItem = (item: WorkoutItem) => putWorkout({ ...w, items: w.items.map(i => (i.id === item.id ? item : i)) })
  const removeItem = (itemId: string) => {
    const items = w.items.filter(i => i.id !== itemId)
    putWorkout({ ...w, items, groups: w.groups.filter(g => items.some(i => i.groupId === g.id)) })
  }
  const addVersion = (v: Version) => {
    const item = newItem(v, settings.unit, workouts)
    if (adding?.swapItemId) {
      const old = w.items.find(i => i.id === adding.swapItemId)
      putWorkout({ ...w, items: w.items.map(i => (i.id === adding.swapItemId ? { ...item, groupId: old?.groupId } : i)) })
      return
    }
    const idx = adding?.afterItemId ? w.items.findIndex(i => i.id === adding.afterItemId) : -1
    const items = w.items.slice()
    if (idx < 0) items.push(item); else items.splice(idx + 1, 0, item)
    putWorkout({ ...w, items })
    setTimeout(() => scrollTo(panes(items).findIndex(p => p.some(i => i.id === item.id))), 50)
  }
  const scrollTo = (paneIdx: number) => {
    const el = pagerRef.current?.children[paneIdx] as HTMLElement | undefined
    el?.scrollIntoView({ behavior: 'smooth', block: 'start' })
  }
  const onScroll = () => {
    const el = pagerRef.current; if (!el) return
    const top = el.scrollTop; let best = 0, bd = Infinity
    Array.from(el.children).forEach((c, i) => { const d = Math.abs((c as HTMLElement).offsetTop - top); if (d < bd) { bd = d; best = i } })
    setCur(best)
    try { localStorage.setItem(`jimmy.pane.${w.id}`, String(best)) } catch {}
  }
  const finish = async () => {
    putWorkout({ ...w, endedAt: w.endedAt ?? Date.now(), notes })
    setEnding(false)
    nav('/')
  }
  const exportNow = async () => { shareJson(await exportSnapshot(), `jimmy-${w.date}.json`) }
  const remaining = w.items.filter(i => !itemDone(i)).length

  return (
    <div style={{ height: '100dvh', display: 'flex', flexDirection: 'column' }}>
      <div className="topbar" style={{ padding: '8px 16px' }}>
        <Link className="iconbtn" to="/" onClick={() => sessionStorage.setItem('jimmy.left', w.id)}>‹</Link>
        <div className="grow">
          <div style={{ fontWeight: 700 }}>{w.name}</div>
          <div className="small">
            <span className="timer">{w.startedAt ? elapsed((w.endedAt ?? Date.now()) - w.startedAt) : 'not started'}</span>
            <button className="faint" style={{ marginLeft: 8 }} onClick={() => setGymSheet(true)}>{gyms.find(g => g.id === w.gymId)?.name.replace('Ultradynamic Fitness - ', '') ?? 'gym?'}</button>
          </div>
        </div>
        <Link className="iconbtn" to={`/workout/${w.id}/overview`} aria-label="Overview">⠿</Link>
        {running ? <button className="btn sm" onClick={() => setEnding(true)}>End</button>
          : !w.startedAt ? <button className="btn sm primary" onClick={() => putWorkout({ ...w, startedAt: Date.now() })}>Start</button>
          : <span className="small faint">done</span>}
      </div>

      <div className="pager grow" ref={pagerRef} onScroll={onScroll} style={{ height: 'auto', scrollSnapType: 'y proximity' }}>
        {ps.map((pane, pi) => {
          const g = pane[0].groupId ? w.groups.find(x => x.id === pane[0].groupId) : undefined
          return (
            <div className="pane" key={pane[0].id}>
              {g && pane.length > 1 && <div className="small" style={{ color: 'var(--accent)', fontWeight: 700, margin: '0 0 6px 4px', textTransform: 'uppercase', letterSpacing: '.06em' }}>{g.type}</div>}
              {pane.map(item => {
                const v = vmap.get(item.versionId)
                if (!v) return null
                return <ExerciseCard key={item.id} workout={w} item={item} version={v} compact={item.skipped}
                  onChange={updateItem} onRemove={() => removeItem(item.id)} onSwap={() => setAdding({ swapItemId: item.id })} />
              })}
              <div className="row" style={{ marginTop: 12 }}>
                <button className="btn sm ghost" onClick={() => setAdding({ afterItemId: pane[pane.length - 1].id })}>+ add after</button>
                <span className="grow" />
                {pi < ps.length - 1 ? <button className="btn primary" onClick={() => scrollTo(pi + 1)}>Next →</button>
                  : running ? <button className="btn primary" onClick={() => setEnding(true)}>Finish</button> : null}
              </div>
            </div>
          )
        })}
        {ps.length === 0 && (
          <div className="pane" style={{ display: 'grid', placeItems: 'center' }}>
            <button className="btn primary" onClick={() => setAdding({})}>+ Add first exercise</button>
          </div>
        )}
      </div>

      <div className="strip">
        <span>{remaining} left</span>
        {ps.map((pane, i) => (
          <button key={pane[0].id} className={'item' + (pane.every(itemDone) ? ' done' : '') + (i === cur ? ' cur' : '')} onClick={() => scrollTo(i)}>
            {pane.map(it => vmap.get(it.versionId)?.name.split(' ').slice(0, 2).join(' ')).join(' + ')}
          </button>
        ))}
        <button className="item" onClick={() => setAdding({})}>+</button>
        <IdeaFab variant="strip" />
      </div>

      <AddExerciseSheet open={!!adding} onClose={() => setAdding(null)} onPick={addVersion} />
      <Sheet open={ending} onClose={() => setEnding(false)} title="End workout">
        <div className="stack">
          <div className="muted small">{w.startedAt ? elapsed(Date.now() - w.startedAt) : ''} · {w.items.filter(itemDone).length}/{w.items.length} exercises · {w.items.reduce((n, i) => n + i.sets.filter(s => s.reps != null).length, 0)} sets logged</div>
          <textarea className="ta" autoFocus value={notes} onChange={e => setNotes(e.target.value)} placeholder="How did it go? Dictate anything: machines, notches, what to change next time." />
          <button className="btn primary block" onClick={finish}>Save & finish</button>
          <button className="btn block" onClick={exportNow}>Export all data (JSON)</button>
          <button className="btn ghost block danger" onClick={() => { if (confirm('Discard this workout?')) { deleteWorkout(w.id); nav('/') } }}>Discard workout</button>
        </div>
      </Sheet>
      <Sheet open={gymSheet} onClose={() => setGymSheet(false)} title="Which gym?">
        <div className="stack">
          {gyms.map(g => <button key={g.id} className={'btn' + (g.id === w.gymId ? ' primary' : '')} onClick={() => { putWorkout({ ...w, gymId: g.id }); setGymSheet(false) }}>{g.name}</button>)}
          <div className="row"><input className="search grow" value={newGym} onChange={e => setNewGym(e.target.value)} placeholder="New gym name" /><button className="btn" onClick={() => { if (!newGym.trim()) return; const g = { id: uid(), name: newGym.trim() }; putGym(g); putWorkout({ ...w, gymId: g.id }); setNewGym(''); setGymSheet(false) }}>Add</button></div>
        </div>
      </Sheet>
    </div>
  )
}
