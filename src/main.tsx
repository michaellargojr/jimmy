import React from 'react'
import ReactDOM from 'react-dom/client'
import { HashRouter } from 'react-router-dom'
import App from './App'
import { primeAudio } from './components/Sound'
import './theme.css'

if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => { navigator.serviceWorker.register('./sw.js').catch(() => {}) })
}
// Unlock audio on the first real gesture so the green ding can play later.
window.addEventListener('touchend', primeAudio, { once: true, passive: true })
window.addEventListener('click', primeAudio, { once: true })

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <HashRouter>
      <App />
    </HashRouter>
  </React.StrictMode>,
)
