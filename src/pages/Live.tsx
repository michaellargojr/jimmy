/**
 * Live workout: a vertical pager, one pane per exercise (or per group). The
 * current pane index is remembered in localStorage so reopening the app lands on
 * the exercise you were doing.
 *
 * Performance notes:
 *  - The elapsed clock is its own component (<Timer>) so the page does not
 *    re-render every second.
 *  - onScroll fires at frame rate; we only touch localStorage once the scroll has
 *    been quiet for PERSIST_DEBOUNCE_MS.
 *  - Every set edit is a full putWorkout (see store.ts write policy). That is
 *    intentional: the cost is one small IndexedDB put.
 */
import { useEffect, useRef, useState } from 'react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { useStore } from '../store'
import { versionIndex } from '../indexes'
import { uid, type Version, type WorkoutItem } from '../model'
import { itemDone, newItem, panes } from '../workout'
import { pruneGroups } from '../grouping'
import { ExerciseCard } from '../components/ExerciseCard'
import { AddExerciseSheet } from '../components/AddExerciseSheet'
import { Sheet } from '../components/Sheet'
import { Timer } from '../components/Timer'
import { exportSnapshot } from '../db'
import { shareJson } from '../share'

const PERSIST_DEBOUNCE_MS = 150
const RESTORE_DELAY_MS = 30 // let the panes lay out before scrolling to the saved one
const SCROLL_AFTER_ADD_MS = 50

const paneKey = (workoutId: string) => `jimmy.pane.${workoutId}`

export function Live() {
  const { id } = useParams()
  const nav = useNavigate()
  const workouts = useStore(s => s.workouts)
  const versions = useStore(s => s.versions)
  const gyms = useStore(s => s.gyms)
  const settings = useStore(s => s.settings)
  const putWorkout = useStore(s => s.putWorkout)
  const deleteWorkout = useStore(s => s.deleteWorkout)
  const putGym = useStore(s => s.putGym)
  const w = workouts.find(x => x.id === id)
  const [adding, setAdding] = useState<{ afterItemId?: string; swapItemId?: string } | null>(null)
  const [ending, setEnding] = useState(false)
  const [notes, setNotes] = useState(w?.notes ?? '')
  const [gymSheet, setGymSheet] = useState(false)
  const [newGym, setNewGym] = useState('')
  const pagerRef = useRef<HTMLDivElement>(null)
  const persistTimer = useRef<number | undefined>(undefined)
  const [cur, setCur] = useState(0)
  useEffect(() => {
    if (!id) return
    let saved = 0
    try { saved = Number(localStorage.getItem(paneKey(id)) ?? 0) } catch { /* storage unavailable */ }
    const t = saved > 0 ? window.setTimeout(() => { const el = pagerRef.current?.children[saved] as HTMLElement | undefined; el?.scrollIntoView({ block: 'start' }) }, RESTORE_DELAY_MS) : undefined
    sessionStorage.removeItem('jimmy.left')
    return () => { window.clearTimeout(t); window.clearTimeout(persistTimer.current) }
  }, [id])
  if (!w) return <div className="page">Workout not found. <Link to="/">Home</Link></div>
  const vmap = versionIndex(versions).byId
  const ps = panes(w.items)
  const running = !!w.startedAt && !w.endedAt

  const updateItem = (item: WorkoutItem) => putWorkout({ ...w, items: w.items.map(i => (i.id === item.id ? item : i)) })
  const removeItem = (itemId: string) => {
    const items = w.items.filter(i => i.id !== itemId)
    putWorkout({ ...w, items, groups: pruneGroups(items, w.groups) })
  }
  const scrollTo = (paneIdx: number) => {
    const el = pagerRef.current?.children[paneIdx] as HTMLElement | undefined
    el?.scrollIntoView({ behavior: 'smooth', block: 'start' })
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
    window.setTimeout(() => scrollTo(panes(items).findIndex(p => p.some(i => i.id === item.id))), SCROLL_AFTER_ADD_MS)
  }
  const onScroll = () => {
    const el = pagerRef.current; if (!el) return
    const top = el.scrollTop; let best = 0, bd = Infinity
    for (let i = 0; i < el.children.length; i++) {
      const d = Math.abs((el.children[i] as HTMLElement).offsetTop - top)
      if (d < bd) { bd = d; best = i }
    }
    setCur(best)
    window.clearTimeout(persistTimer.current)
    persistTimer.current = window.setTimeout(() => { try { localStorage.setItem(paneKey(w.id), String(best)) } catch { /* storage unavailable */ } }, PERSIST_DEBOUNCE_MS)
  }
  const finish = () => {
    putWorkout({ ...w, endedAt: w.endedAt ?? Date.now(), notes })
    setEnding(false)
    nav('/')
  }
  const exportNow = async () => { await shareJson(await exportSnapshot(), `jimmy-${w.date}.json`) }
  const remaining = w.items.filter(i => !itemDone(i)).length
  const gymName = gyms.find(g => g.id === w.gymId)?.name.replace('Ultradynamic Fitness - ', '') ?? 'gym?'

  return (
    <div style={{ height: '100dvh', display: 'flex', flexDirection: 'column' }}>
      <div className="topbar" style={{ padding: '8px 16px' }}>
        <Link className="iconbtn" to="/" onClick={() => sessionStorage.setItem('jimmy.left', w.id)} aria-label="Home">‹</Link>
        <div className="grow">
          <div style={{ fontWeight: 700 }}>{w.name}</div>
          <div className="small">
            <Timer className="timer" startedAt={w.startedAt} endedAt={w.endedAt} />
            <button className="faint" style={{ marginLeft: 8 }} onClick={() => setGymSheet(true)}>{gymName}</button>
          </div>
        </div>
        <Link className="iconbtn" to={`/workout/${w.id}/overview`} aria-label="Overview">⠿</Link>
        {running ? <button className="btn sm" onClick={() => setEnding(true)}>End</button>
          : !w.startedAt ? <button className="btn sm primary" onClick={() => putWorkout({ ...w, startedAt: Date.now() })}>Start</button>
          : <span className="small faint">done</span>}
      </div>

      <div className="pager" ref={pagerRef} onScroll={onScroll}>
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
        <button className="item" onClick={() => setAdding({})} aria-label="add exercise">+</button>
      </div>

      <AddExerciseSheet open={!!adding} onClose={() => setAdding(null)} onPick={addVersion} />
      <Sheet open={ending} onClose={() => setEnding(false)} title="End workout">
        <div className="stack">
          <div className="muted small"><Timer startedAt={w.startedAt} endedAt={w.endedAt} idle="" /> · {w.items.filter(itemDone).length}/{w.items.length} exercises · {w.items.reduce((n, i) => n + i.sets.filter(s => s.reps != null).length, 0)} sets logged</div>
          <textarea className="ta" autoFocus value={notes} onChange={e => setNotes(e.target.value)} placeholder="How did it go? Dictate anything: machines, notches, what to change next time." />
          <button className="btn primary block" onClick={finish}>Save & finish</button>
          <button className="btn block" onClick={() => void exportNow()}>Export all data (JSON)</button>
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
