import { defineConfig, type Plugin } from 'vite'
import react from '@vitejs/plugin-react'
import { existsSync, readFileSync, writeFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { createHash } from 'node:crypto'

const pkg = JSON.parse(readFileSync(new URL('./package.json', import.meta.url), 'utf8')) as { version: string }

/**
 * Stamps public/sw.js after the build with:
 *  - VERSION: a hash of the emitted asset names (content-hashed, so it changes
 *    exactly when the app changes), which becomes the cache name.
 *  - PRECACHE: every emitted js/css asset, so the first install caches all lazy
 *    chunks and the app works offline from the first launch.
 * In dev the placeholders stay in place and the SW is not registered (src/pwa.ts).
 */
function swStamp(): Plugin {
  let outDir = 'dist'
  let assets: string[] = []
  return {
    name: 'jimmy-sw-stamp',
    apply: 'build',
    configResolved(c) { outDir = c.build.outDir },
    generateBundle(_, bundle) {
      assets = Object.keys(bundle).filter(f => /\.(js|css|woff2?)$/.test(f)).sort()
    },
    closeBundle() {
      const file = resolve(outDir, 'sw.js')
      if (!existsSync(file)) return
      const version = createHash('sha1').update(assets.join('\n') + pkg.version).digest('hex').slice(0, 10)
      const src = readFileSync(file, 'utf8')
        .replace("'__SW_VERSION__'", JSON.stringify(version))
        .replace('/*__PRECACHE__*/[]', JSON.stringify(assets.map(a => './' + a)))
      writeFileSync(file, src)
      this.info(`sw.js stamped: version ${version}, ${assets.length} precached assets`)
    },
  }
}

export default defineConfig({
  plugins: [react(), swStamp()],
  base: './',
  define: {
    __APP_VERSION__: JSON.stringify(pkg.version),
    __BUILD_TIME__: JSON.stringify(new Date().toISOString()),
  },
  build: { target: 'es2020', sourcemap: false },
})
