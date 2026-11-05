/**
 * Last line of defence. Without this, any render-time exception leaves a blank
 * white screen on the phone with no way to get the data out. This shows the
 * error, offers a reload, and an Export that talks to Dexie directly (so it works
 * even if the store or a page is what broke).
 */
import { Component, type ReactNode } from 'react'
import { exportSnapshot } from '../db'
import { shareJson } from '../share'

interface Props { children: ReactNode }
interface State { error?: Error }

export class ErrorBoundary extends Component<Props, State> {
  state: State = {}
  static getDerivedStateFromError(error: Error): State { return { error } }
  componentDidCatch(error: Error, info: { componentStack?: string | null }) {
    console.error('Jimmy crashed', error, info.componentStack)
  }
  render() {
    const { error } = this.state
    if (!error) return this.props.children
    return (
      <div className="page stack">
        <h1>Something broke</h1>
        <div className="muted small">Your data is safe in the phone's storage. Reload to continue, or export a copy first.</div>
        <pre className="small faint" style={{ whiteSpace: 'pre-wrap', wordBreak: 'break-word', background: 'var(--bg2)', padding: 12, borderRadius: 12 }}>{error.name}: {error.message}</pre>
        <button className="btn primary block" onClick={() => location.reload()}>Reload</button>
        <button className="btn block" onClick={async () => { try { await shareJson(await exportSnapshot(), `jimmy-rescue-${new Date().toISOString().slice(0, 10)}.json`) } catch (e) { alert(`Export failed: ${String(e)}`) } }}>Export all data (JSON)</button>
        <button className="btn ghost block" onClick={() => { location.hash = '#/'; location.reload() }}>Go home</button>
      </div>
    )
  }
}
