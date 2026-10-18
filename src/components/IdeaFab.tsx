import { useState } from 'react'
import { useLocation } from 'react-router-dom'
import { useStore } from '../store'
import { uid } from '../model'
import { Sheet } from './Sheet'

export function IdeaFab() {
  const [open, setOpen] = useState(false)
  const [kind, setKind] = useState<'bug' | 'feature'>('feature')
  const [text, setText] = useState('')
  const [saved, setSaved] = useState(false)
  const { putIdea, ideas } = useStore()
  const loc = useLocation()
  const save = () => {
    if (!text.trim()) return
    putIdea({ id: uid(), kind, text: text.trim(), createdAt: Date.now(), page: loc.pathname })
    setText(''); setSaved(true); setTimeout(() => { setSaved(false); setOpen(false) }, 600)
  }
  return (
    <>
      <button className="fab" onClick={() => setOpen(true)} aria-label="Capture an idea">💡</button>
      <Sheet open={open} onClose={() => setOpen(false)} title={saved ? 'Saved ✓' : 'Idea for Jimmy'}>
        <div className="stack">
          <div className="row" style={{ gap: 6 }}>
            <button className={'chip' + (kind === 'feature' ? ' on' : '')} onClick={() => setKind('feature')}>feature / change</button>
            <button className={'chip' + (kind === 'bug' ? ' on' : '')} onClick={() => setKind('bug')}>bug</button>
            <span className="grow" /><span className="small faint">{ideas.length} saved</span>
          </div>
          <textarea className="ta" autoFocus value={text} onChange={e => setText(e.target.value)} placeholder="Dictate it. Saved in the app, hand it to Claude whenever." />
          <button className="btn primary block" onClick={save} disabled={!text.trim()}>Save idea</button>
        </div>
      </Sheet>
    </>
  )
}
