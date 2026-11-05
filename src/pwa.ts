/**
 * Service-worker lifecycle, user-controlled updates.
 *
 * Flow:
 *  1. registerSW() runs once at startup (production builds only; in dev a cached
 *     old bundle just causes confusion).
 *  2. The browser finds a new sw.js (we also ask on every return to foreground).
 *     The new worker installs and then WAITS. It does not take over on its own.
 *  3. We flip store.updateReady; Home shows "A new version is ready".
 *  4. Tapping it posts SKIP_WAITING; the worker activates; `controllerchange`
 *     fires and we reload so the page runs the new code with the new cache.
 *
 * Why not auto-activate (self.skipWaiting in install)? Because the old page would
 * keep running while its lazy chunks vanish from the cache. See src/lazy.ts for
 * the belt-and-braces fallback.
 */
import { useStore } from './store'

export function registerSW() {
  if (!import.meta.env.PROD || !('serviceWorker' in navigator)) return
  const sw = navigator.serviceWorker
  const markReady = () => useStore.getState().setUpdateReady(true)

  window.addEventListener('load', () => {
    sw.register('./sw.js').then(reg => {
      const watch = (worker: ServiceWorker | null) => {
        if (!worker) return
        worker.addEventListener('statechange', () => {
          // "installed" with an existing controller means an update is waiting; on a first install there is no controller.
          if (worker.state === 'installed' && sw.controller) markReady()
        })
      }
      if (reg.waiting && sw.controller) markReady()
      watch(reg.installing)
      reg.addEventListener('updatefound', () => watch(reg.installing))
      document.addEventListener('visibilitychange', () => { if (document.visibilityState === 'visible') void reg.update().catch(() => {}) })
    }).catch(() => { /* registration failure is not fatal; the app works without offline support */ })

    // Reload once the waiting worker has taken control. Skip the very first install (controller goes from null to set).
    let hadController = !!sw.controller
    sw.addEventListener('controllerchange', () => {
      if (!hadController) { hadController = true; return }
      location.reload()
    })
  })
}

/** Called from the "update ready" banner. */
export async function applyUpdate() {
  if (!('serviceWorker' in navigator)) return
  const reg = await navigator.serviceWorker.getRegistration()
  if (reg?.waiting) reg.waiting.postMessage({ type: 'SKIP_WAITING' })
  else location.reload()
}
