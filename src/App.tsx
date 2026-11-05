/**
 * Route table + app-level chrome. Pages that pull in dnd-kit (Plan, Overview) and
 * rarely visited pages (Library, Settings) are lazy so the first paint only loads
 * what Home and Live need.
 *
 * Experimental features live under src/features/ behind flags; their routes are
 * spliced in here only when the flag is on. See src/features/README.md.
 */
import { Suspense, useEffect } from 'react'
import { Route, Routes } from 'react-router-dom'
import { useStore } from './store'
import { Home } from './pages/Home'
import { Live } from './pages/Live'
import { IdeaFab } from './components/IdeaFab'
import { installAudioUnlock } from './components/Sound'
import { lazyPage } from './lazy'
import { FEATURES } from './features/flags'
import { newsRoutes } from './features/news/routes'
import { exportSnapshot } from './db'
import { shareJson } from './share'

const Plan = lazyPage(() => import('./pages/Plan').then(m => ({ default: m.Plan })))
const OverviewPage = lazyPage(() => import('./pages/OverviewPage').then(m => ({ default: m.OverviewPage })))
const SettingsPage = lazyPage(() => import('./pages/Settings').then(m => ({ default: m.SettingsPage })))
const Library = lazyPage(() => import('./pages/Library').then(m => ({ default: m.Library })))

function PersistBanner({ error }: { error: string }) {
  const clear = useStore(s => s.clearPersistError)
  return (
    <div className="banner danger" role="alert">
      <div className="grow">Could not save to this phone's storage. Export your data now.<div className="small faint">{error}</div></div>
      <button className="btn sm" onClick={async () => shareJson(await exportSnapshot(), `jimmy-rescue-${new Date().toISOString().slice(0, 10)}.json`)}>Export</button>
      <button className="btn sm ghost" onClick={clear} aria-label="dismiss">✕</button>
    </div>
  )
}

export default function App() {
  const loaded = useStore(s => s.loaded)
  const loadError = useStore(s => s.loadError)
  const persistError = useStore(s => s.persistError)
  const sound = useStore(s => s.settings.sound)
  const load = useStore(s => s.load)
  useEffect(() => { void load() }, [load])
  useEffect(() => { if (sound) installAudioUnlock() }, [sound])
  if (!loaded) return <div className="page muted">Loading Jimmy…</div>
  if (loadError) {
    return (
      <div className="page stack">
        <h1>Jimmy could not open its storage</h1>
        <div className="muted small">{loadError}</div>
        <div className="small faint">This usually means Safari is in Private mode or storage was cleared. Add Jimmy to the Home Screen and open it from there.</div>
        <button className="btn primary block" onClick={() => location.reload()}>Try again</button>
      </div>
    )
  }
  return (
    <>
      {persistError && <PersistBanner error={persistError} />}
      <Suspense fallback={<div className="page muted">Loading…</div>}>
        <Routes>
          <Route path="/" element={<Home />} />
          <Route path="/plan/:routineId" element={<Plan />} />
          <Route path="/plan/:routineId/overview" element={<OverviewPage mode="routine" />} />
          <Route path="/workout/:id" element={<Live />} />
          <Route path="/workout/:id/overview" element={<OverviewPage mode="workout" />} />
          <Route path="/settings" element={<SettingsPage />} />
          <Route path="/library" element={<Library />} />
          {FEATURES.news && newsRoutes()}
          <Route path="*" element={<Home />} />
        </Routes>
      </Suspense>
      <IdeaFab />
    </>
  )
}
