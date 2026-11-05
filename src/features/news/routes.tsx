/**
 * The only file the main app imports from this feature. Pages are lazy so the
 * feature costs nothing in the main bundle while the flag is off.
 * Usage in App.tsx: `{FEATURES.news && newsRoutes()}` inside <Routes>.
 */
import { Route } from 'react-router-dom'
import { lazyPage } from '../../lazy'

const NewsPage = lazyPage(() => import('./pages/NewsPage'))
const AthletePage = lazyPage(() => import('./pages/AthletePage'))

export function newsRoutes() {
  return [
    <Route key="news" path="/news" element={<NewsPage />} />,
    <Route key="athlete" path="/news/athlete/:slug" element={<AthletePage />} />,
  ]
}
