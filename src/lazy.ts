/**
 * React.lazy with a safety net for PWAs.
 *
 * Problem: after a deploy, the hashed chunk an already-open page wants to lazy
 * load may no longer exist on the server (and is not in the new service worker
 * cache). The import rejects and the route renders nothing.
 *
 * Fix: on the first failure, reload the page once (the fresh index.html points at
 * the new chunks). If it fails again after a reload, surface the error normally so
 * the ErrorBoundary can show it.
 */
import { lazy, type ComponentType, type LazyExoticComponent } from 'react'

const RELOAD_FLAG = 'jimmy.chunkReload'

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export function lazyPage<T extends ComponentType<any>>(load: () => Promise<{ default: T }>): LazyExoticComponent<T> {
  return lazy(() =>
    load().then(m => { try { sessionStorage.removeItem(RELOAD_FLAG) } catch { /* ignore */ } return m })
      .catch((err: unknown) => {
        let reloaded = false
        try { reloaded = sessionStorage.getItem(RELOAD_FLAG) === '1'; if (!reloaded) sessionStorage.setItem(RELOAD_FLAG, '1') } catch { /* ignore */ }
        if (!reloaded) { location.reload(); return new Promise<{ default: T }>(() => {}) }
        throw err
      }),
  )
}
