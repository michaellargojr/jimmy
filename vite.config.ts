import { readFileSync, writeFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { defineConfig, type Plugin } from 'vite'
import react from '@vitejs/plugin-react'

/** Give each build its own service-worker cache name so an update drops the previous build's files. */
function swStamp(): Plugin {
  const stamp = Date.now().toString(36)
  return {
    name: 'jimmy-sw-stamp',
    closeBundle() {
      const p = fileURLToPath(new URL('./dist/sw.js', import.meta.url))
      try { writeFileSync(p, readFileSync(p, 'utf8').replace('__BUILD__', stamp)) } catch { /* no dist (dev) */ }
    },
  }
}

export default defineConfig({
  plugins: [react(), swStamp()],
  base: './',
  build: { target: 'es2020', sourcemap: false },
})
