let ctx: AudioContext | undefined
export function ding() {
  try {
    ctx ??= new (window.AudioContext || (window as any).webkitAudioContext)()
    const t = ctx.currentTime
    const tone = (f: number, start: number, dur: number) => {
      const o = ctx!.createOscillator(), g = ctx!.createGain()
      o.type = 'sine'; o.frequency.value = f
      g.gain.setValueAtTime(0.0001, t + start)
      g.gain.exponentialRampToValueAtTime(0.25, t + start + 0.02)
      g.gain.exponentialRampToValueAtTime(0.0001, t + start + dur)
      o.connect(g).connect(ctx!.destination); o.start(t + start); o.stop(t + start + dur + 0.05)
    }
    tone(880, 0, 0.18); tone(1320, 0.14, 0.26)
  } catch { /* no audio */ }
  if ('vibrate' in navigator) try { navigator.vibrate?.(30) } catch { /* ignore */ }
}
