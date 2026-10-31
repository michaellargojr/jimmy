let ctx: AudioContext | undefined

function get(): AudioContext | undefined {
  try { ctx ??= new (window.AudioContext || (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext)() } catch { return undefined }
  return ctx
}

/**
 * iOS only lets audio start inside a user gesture. The green ding fires from a
 * wheel-scroll timer, not a tap, so unlock the context once on the first touch.
 */
export function primeAudio() {
  const c = get(); if (!c) return
  try {
    if (c.state === 'suspended') void c.resume()
    const b = c.createBuffer(1, 1, 22050), s = c.createBufferSource()
    s.buffer = b; s.connect(c.destination); s.start(0)
  } catch { /* ignore */ }
}

export function ding() {
  try {
    const c = get(); if (!c) return
    if (c.state === 'suspended') void c.resume()
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
  if ('vibrate' in navigator) try { navigator.vibrate?.(30) } catch { /* ignore */ }
}
