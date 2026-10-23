import { useRef, useState } from 'react'
import { Link } from 'react-router-dom'
import { useStore } from '../store'
import { db, exportSnapshot, importSnapshot, type Snapshot } from '../db'
import { shareJson } from '../share'
import { THEMES } from '../model'
import { ImportSheet } from '../components/ImportSheet'
import { syncIdeas } from '../github'

export function SettingsPage() {
  const { settings, setSettings, ideas, putIdea, deleteIdea, reload } = useStore()
  const fileRef = useRef<HTMLInputElement>(null)
  const [importing, setImporting] = useState(false)
  const [ghOpen, setGhOpen] = useState(false)
  const [syncing, setSyncing] = useState(false)
  const [syncMsg, setSyncMsg] = useState('')
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
  const ideasText = () => {
    const sorted = ideas.slice().sort((a, b) => a.createdAt - b.createdAt)
    const line = (i: typeof ideas[number]) => `- [${i.kind}]${i.done ? ' [done]' : ''} ${new Date(i.createdAt).toLocaleDateString()} ${i.text}${i.issue ? ` (#${i.issue})` : ''}`
    return [...sorted.filter(i => !i.done), ...sorted.filter(i => i.done)].map(line).join('\n')
  }
  const copyIdeas = async () => {
    const text = ideasText()
    try { await navigator.clipboard.writeText(text); alert('Copied. Paste it to Claude.') } catch { prompt('Copy:', text) }
  }
  const shareIdeas = async () => {
    const text = ideasText()
    try { await navigator.share({ title: 'Jimmy ideas', text }) } catch { /* cancelled or unsupported */ }
  }
  const canShare = typeof navigator !== 'undefined' && 'share' in navigator
  const pending = ideas.filter(i => (i.issue == null && !i.done) || (i.issue != null && i.done && !i.closedAt)).length
  const sync = async () => {
    setSyncing(true); setSyncMsg('')
    const r = await syncIdeas(ideas, settings, putIdea)
    setSyncing(false)
    setSyncMsg([r.created ? `${r.created} filed` : '', r.closed ? `${r.closed} closed` : '', ...r.errors].filter(Boolean).join(' · ') || 'Nothing to send')
  }
  return (
    <div className="page">
      <div className="topbar"><Link className="iconbtn" to="/">‹</Link><h1>Settings</h1></div>
      <div className="stack">
        <div className="card stack">
          <div className="row"><span className="grow">Default unit</span>
            <button className={'chip' + (settings.unit === 'kg' ? ' on' : '')} onClick={() => setSettings({ unit: 'kg' })}>kg</button>
            <button className={'chip' + (settings.unit === 'lbs' ? ' on' : '')} onClick={() => setSettings({ unit: 'lbs' })}>lbs</button></div>
          <div className="row" style={{ flexWrap: 'wrap' }}><span className="grow">Theme</span>
            {THEMES.map(t => <button key={t} className={'chip' + (settings.theme === t ? ' on' : '')} onClick={() => setSettings({ theme: t })}>{t}</button>)}</div>
          <div className="row"><span className="grow">Sound on green</span><button className={'chip' + (settings.sound ? ' on' : '')} onClick={() => setSettings({ sound: !settings.sound })}>{settings.sound ? 'on' : 'off'}</button></div>
        </div>
        <div className="card stack">
          <b>Data</b>
          <button className="btn" onClick={async () => shareJson(await exportSnapshot(), `jimmy-${new Date().toISOString().slice(0, 10)}.json`)}>Export everything (JSON)</button>
          <button className="btn" onClick={() => fileRef.current?.click()}>Import JSON</button>
          <input ref={fileRef} type="file" accept="application/json" hidden onChange={e => { const f = e.target.files?.[0]; if (f) void onImport(f) }} />
          <button className="btn" onClick={() => setImporting(true)}>Import a workout from Apple Notes</button>
          <button className="btn ghost danger" onClick={reseed}>Reset to Notion seed</button>
          <div className="small faint">Data lives on this phone. Add Jimmy to your Home Screen so iOS keeps it. Export after workouts until sync exists.</div>
        </div>
        <div className="card stack">
          <div className="row"><b className="grow">💡 Ideas ({ideas.length})</b>
            {ideas.length > 0 && canShare && <button className="chip" onClick={shareIdeas}>share</button>}
            {ideas.length > 0 && <button className="chip" onClick={copyIdeas}>copy for Claude</button>}</div>
          {(ideas.length > 0 || settings.githubToken) && <div className="row" style={{ flexWrap: 'wrap' }}>
            <button className="btn sm" disabled={syncing || pending === 0 || !settings.githubToken} onClick={sync}>{syncing ? 'Sending…' : `Send ${pending} to GitHub`}</button>
            <button className="btn sm ghost" onClick={() => setGhOpen(!ghOpen)}>{settings.githubToken ? 'GitHub settings' : 'Set up GitHub'}</button>
            {syncMsg && <span className="small muted">{syncMsg}</span>}
          </div>}
          {ghOpen && (
            <div className="stack" style={{ gap: 6 }}>
              <input className="search" value={settings.githubRepo ?? ''} onChange={e => setSettings({ githubRepo: e.target.value.trim() })} placeholder="owner/repo" autoCapitalize="none" autoCorrect="off" />
              <input className="search" type="password" value={settings.githubToken ?? ''} onChange={e => setSettings({ githubToken: e.target.value.trim() })} placeholder="Fine-grained token (Issues: read & write)" autoCapitalize="none" autoCorrect="off" />
              <div className="small faint">Each idea becomes an issue labelled bug or feature, so Claude can read them straight from the repo. Marking an idea done closes its issue on the next send. Token: github.com → Settings → Developer settings → Fine-grained tokens → only this repo, Issues read/write. It stays on this phone.</div>
            </div>
          )}
          {ideas.slice().sort((a, b) => b.createdAt - a.createdAt).map(i => (
            <div key={i.id} className="row" style={{ alignItems: 'flex-start' }}>
              <button className={'tog sm' + (i.done ? ' on' : '')} onClick={() => putIdea({ ...i, done: !i.done })}>{i.done ? '✓' : ''}</button>
              <div className="grow small" style={{ textDecoration: i.done ? 'line-through' : undefined }}>
                <span className={'badge ' + (i.kind === 'bug' ? 'down' : 'up')}>{i.kind}</span> <span className="faint">{new Date(i.createdAt).toLocaleDateString()}</span>
                {i.issueUrl && <> <a className="faint" href={i.issueUrl} target="_blank" rel="noreferrer">#{i.issue}</a></>}
                <br />{i.text}
              </div>
              <button className="faint" onClick={() => { if (i.issue == null || confirm('Delete locally? The GitHub issue stays.')) deleteIdea(i.id) }}>✕</button>
            </div>
          ))}
          {ideas.length === 0 && <div className="small faint">Tap the light bulb on any page to capture a bug or a change while you train.</div>}
        </div>
        <div className="small faint">Jimmy v0.2 · built {new Date().getFullYear()}</div>
      </div>
      <ImportSheet open={importing} onClose={() => setImporting(false)} />
    </div>
  )
}
