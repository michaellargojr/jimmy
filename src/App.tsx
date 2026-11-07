import { useEffect } from 'react'
import { Route, Routes, useLocation } from 'react-router-dom'
import { useStore } from './store'
import { Home } from './pages/Home'
import { Plan } from './pages/Plan'
import { Live } from './pages/Live'
import { OverviewPage } from './pages/OverviewPage'
import { SettingsPage } from './pages/Settings'
import { Library } from './pages/Library'
import { IdeaFab } from './components/IdeaFab'

export default function App() {
  const { loaded, loadError, load } = useStore()
  const loc = useLocation()
  useEffect(() => { void load() }, [load])
  if (loadError) return <div className="page muted">Jimmy could not open its database.<br /><span className="small">{loadError}</span><br /><button className="btn" style={{ marginTop: 12 }} onClick={() => location.reload()}>Retry</button></div>
  if (!loaded) return <div className="page muted">Loading Jimmy…</div>
  // The live workout page hosts the lightbulb in its bottom strip so it never covers Next / Finish.
  const onLive = /^\/workout\/[^/]+$/.test(loc.pathname)
  return (
    <>
      <Routes>
        <Route path="/" element={<Home />} />
        <Route path="/plan/:routineId" element={<Plan />} />
        <Route path="/plan/:routineId/overview" element={<OverviewPage mode="routine" />} />
        <Route path="/workout/:id" element={<Live />} />
        <Route path="/workout/:id/overview" element={<OverviewPage mode="workout" />} />
        <Route path="/settings" element={<SettingsPage />} />
        <Route path="/library" element={<Library />} />
      </Routes>
      {!onLive && <IdeaFab />}
    </>
  )
}
