/*
 * Jimmy service worker.
 *
 * VERSION and PRECACHE are stamped at build time by the swStamp plugin in
 * vite.config.ts (in dev they keep the placeholder values below). A new build =>
 * a new cache name => old assets are deleted on activate, so the cache no longer
 * grows forever.
 *
 * Update policy: a new worker installs and WAITS until the page posts
 * SKIP_WAITING (user tapped "update ready"). See src/pwa.ts.
 *
 * Fetch policy:
 *  - navigations: network first (so a new deploy is picked up), cached index.html
 *    when offline.
 *  - everything else same-origin: cache first, then network, caching good responses.
 */
const VERSION = '__SW_VERSION__'
const PRECACHE = /*__PRECACHE__*/[]
const CACHE = 'jimmy-' + VERSION
const SHELL = ['./', './index.html', './manifest.webmanifest', './icons/icon-192.png', './icons/icon-512.png']

self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE).then(c => Promise.allSettled([...SHELL, ...PRECACHE].map(u => c.add(u)))))
})

self.addEventListener('message', e => {
  if (e.data && e.data.type === 'SKIP_WAITING') self.skipWaiting()
})

self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys()
      .then(keys => Promise.all(keys.filter(k => k.startsWith('jimmy-') && k !== CACHE).map(k => caches.delete(k))))
      .then(() => self.clients.claim()),
  )
})

self.addEventListener('fetch', e => {
  const req = e.request
  if (req.method !== 'GET' || new URL(req.url).origin !== location.origin) return
  const isNav = req.mode === 'navigate'
  e.respondWith((async () => {
    const cache = await caches.open(CACHE)
    if (isNav) {
      try {
        const fresh = await fetch(req)
        if (fresh.ok) cache.put('./index.html', fresh.clone())
        return fresh
      } catch {
        return (await cache.match('./index.html')) || (await cache.match('./')) || Response.error()
      }
    }
    const hit = await cache.match(req)
    if (hit) return hit
    try {
      const fresh = await fetch(req)
      if (fresh.ok) cache.put(req, fresh.clone())
      return fresh
    } catch {
      return Response.error()
    }
  })())
})
