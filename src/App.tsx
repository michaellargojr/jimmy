import { useEffect } from 'react'
import { Route, Routes } from 'react-router-dom'
import { useStore } from './store'
import { Home } from './pages/Home'
import { Plan } from './pages/Plan'
import { Live } from './pages/Live'
import { OverviewPage } from './pages/OverviewPage'
import { SettingsPage } from './pages/Settings'
import { Library } from './pages/Library'
import { IdeaFab } from './components/IdeaFab'

export default function App() {
  const { loaded, load } = useStore()
  useEffect(() => { void load() }, [load])
  if (!loaded) return <div className="page muted">Loading Jimmy…</div>
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
      <IdeaFab />
    </>
  )
}
