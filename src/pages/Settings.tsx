import { useRef } from 'react'
import { Link } from 'react-router-dom'
import { useStore } from '../store'
import { db, exportSnapshot, importSnapshot, type Snapshot } from '../db'
import { shareJson } from '../share'

export function SettingsPage() {
  const { settings, setSettings, ideas, putIdea, deleteIdea, reload } = useStore()
  const fileRef = useRef<HTMLInputElement>(null)
  const onImport = async (f: File) => {
    const s = JSON.parse(await f.text()) as Snapshot
    if (!s.workouts || !s.versions) { alert('Not a Jimmy export'); return }
    if (!confirm(`Replace all data with this export (${s.workouts.length} workouts)?`)) return
    await importSnapshot(s); await reload()
  }
  const reseed = async () => {
    if (!confirm('Erase everything and reload the Notion seed? Ideas are kept.')) return
    await Promise.all([db.exercises.clear(), db.versions.clear(), db.workouts.clear(), db.routines.clear(), db.gyms.clear()])
    await db.settings.put({ ...settings, seeded: false })
    location.reload()
  }
  const copyIdeas = async () => {
    const text = ideas.map(i => `- [${i.kind}] ${new Date(i.createdAt).toLocaleDateString()} ${i.text}`).join('\n')
    try { await navigator.clipboard.writeText(text); alert('Copied') } catch { prompt('Copy:', text) }
  }
  return (
    <div className="page">
      <div className="topbar"><Link className="iconbtn" to="/">‹</Link><h1>Settings</h1></div>
      <div className="stack">
        <div className="card stack">
          <div className="row"><span className="grow">Default unit</span>
            <button className={'chip' + (settings.unit === 'kg' ? ' on' : '')} onClick={() => setSettings({ unit: 'kg' })}>kg</button>
            <button className={'chip' + (settings.unit === 'lbs' ? ' on' : '')} onClick={() => setSettings({ unit: 'lbs' })}>lbs</button></div>
          <div className="row"><span className="grow">Theme</span>
            {(['dark', 'light', 'paper'] as const).map(t => <button key={t} className={'chip' + (settings.theme === t ? ' on' : '')} onClick={() => setSettings({ theme: t })}>{t}</button>)}</div>
          <div className="row"><span className="grow">Sound on green</span><button className={'chip' + (settings.sound ? ' on' : '')} onClick={() => setSettings({ sound: !settings.sound })}>{settings.sound ? 'on' : 'off'}</button></div>
        </div>
        <div className="card stack">
          <b>Data</b>
          <button className="btn" onClick={async () => shareJson(await exportSnapshot(), `jimmy-${new Date().toISOString().slice(0, 10)}.json`)}>Export everything (JSON)</button>
          <button className="btn" onClick={() => fileRef.current?.click()}>Import JSON</button>
          <input ref={fileRef} type="file" accept="application/json" hidden onChange={e => { const f = e.target.files?.[0]; if (f) void onImport(f) }} />
          <button className="btn ghost danger" onClick={reseed}>Reset to Notion seed</button>
          <div className="small faint">Data lives on this phone. Add Jimmy to your Home Screen so iOS keeps it. Export after workouts until sync exists.</div>
        </div>
        <div className="card stack">
          <div className="row"><b className="grow">💡 Ideas ({ideas.length})</b>{ideas.length > 0 && <button className="chip" onClick={copyIdeas}>copy for Claude</button>}</div>
          {ideas.slice().sort((a, b) => b.createdAt - a.createdAt).map(i => (
            <div key={i.id} className="row" style={{ alignItems: 'flex-start' }}>
              <button className={'tog sm' + (i.done ? ' on' : '')} onClick={() => putIdea({ ...i, done: !i.done })}>{i.done ? '✓' : ''}</button>
              <div className="grow small" style={{ textDecoration: i.done ? 'line-through' : undefined }}>
                <span className={'badge ' + (i.kind === 'bug' ? 'down' : 'up')}>{i.kind}</span> <span className="faint">{new Date(i.createdAt).toLocaleDateString()}</span><br />{i.text}
              </div>
              <button className="faint" onClick={() => deleteIdea(i.id)}>✕</button>
            </div>
          ))}
          {ideas.length === 0 && <div className="small faint">Tap the light bulb on any page to capture a bug or a change while you train.</div>}
        </div>
        <div className="small faint">Jimmy v0.1 · built {new Date().getFullYear()}</div>
      </div>
    </div>
  )
}
