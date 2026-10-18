const CACHE = 'jimmy-v1'
self.addEventListener('install', e => { self.skipWaiting(); e.waitUntil(caches.open(CACHE).then(c => c.addAll(['./', './index.html', './manifest.webmanifest']).catch(() => {}))) })
self.addEventListener('activate', e => { e.waitUntil(caches.keys().then(keys => Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k)))).then(() => self.clients.claim())) })
self.addEventListener('fetch', e => {
  const req = e.request
  if (req.method !== 'GET' || new URL(req.url).origin !== location.origin) return
  const isNav = req.mode === 'navigate'
  e.respondWith((async () => {
    const cache = await caches.open(CACHE)
    if (isNav) {
      try { const fresh = await fetch(req); cache.put('./index.html', fresh.clone()); return fresh }
      catch { return (await cache.match('./index.html')) || (await cache.match('./')) || Response.error() }
    }
    const hit = await cache.match(req)
    if (hit) return hit
    try { const fresh = await fetch(req); if (fresh.ok) cache.put(req, fresh.clone()); return fresh }
    catch { return Response.error() }
  })())
})
