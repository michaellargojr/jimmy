/**
 * The "you hit max" ding. Web Audio only, no asset to load.
 *
 * iOS gotcha: an AudioContext only produces sound if it was created or resumed
 * inside a user gesture. The ding is triggered from a React effect after a
 * debounced wheel scroll, which is NOT a gesture, so without priming it is silent.
 * installAudioUnlock() creates/resumes the context on the next touch and keeps it
 * running; App calls it when sound is enabled.
 */
let ctx: AudioContext | undefined
let unlockInstalled = false

function getCtx(): AudioContext | undefined {
  try {
    ctx ??= new (window.AudioContext || (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext)()
  } catch { /* no Web Audio */ }
  return ctx
}

export function installAudioUnlock() {
  if (unlockInstalled) return
  unlockInstalled = true
  const unlock = () => {
    const c = getCtx()
    if (c && c.state !== 'running') void c.resume().catch(() => {})
  }
  document.addEventListener('touchend', unlock, { passive: true })
  document.addEventListener('pointerup', unlock, { passive: true })
}

export function ding() {
  const c = getCtx()
  if (c) {
    try {
      if (c.state !== 'running') void c.resume().catch(() => {})
      const t = c.currentTime
      const tone = (f: number, start: number, dur: number) => {
        const o = c.createOscillator(), g = c.createGain()
        o.type = 'sine'; o.frequency.value = f
        g.gain.setValueAtTime(0.0001, t + start)
        g.gain.exponentialRampToValueAtTime(0.25, t + start + 0.02)
        g.gain.exponentialRampToValueAtTime(0.0001, t + start + dur)
        o.connect(g).connect(c.destination); o.start(t + start); o.stop(t + start + dur + 0.05)
      }
      tone(880, 0, 0.18); tone(1320, 0.14, 0.26)
    } catch { /* no audio */ }
  }
  if ('vibrate' in navigator) try { navigator.vibrate?.(30) } catch { /* ignore */ }
}
