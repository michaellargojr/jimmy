/**
 * Cross-fades between a start frame and an end frame on a timer. Tap to pause /
 * resume. With `prefers-reduced-motion` it does not auto-play: it shows the start
 * frame and each tap flips to the other frame.
 *
 * Both <img> elements are always mounted (stacked) so the browser has both frames
 * decoded before the first fade.
 */
import { useEffect, useState } from 'react'
import type { PoseFrame } from './types'
import './pose3d.css'

const DEFAULT_PERIOD_MS = 2400

function prefersReducedMotion(): boolean {
  return typeof matchMedia === 'function' && matchMedia('(prefers-reduced-motion: reduce)').matches
}

export function PoseCycler({ start, end, periodMs = DEFAULT_PERIOD_MS, label }: { start: PoseFrame; end: PoseFrame; periodMs?: number; label?: string }) {
  const [atEnd, setAtEnd] = useState(false)
  const [playing, setPlaying] = useState(() => !prefersReducedMotion())
  useEffect(() => {
    if (!playing) return
    const t = window.setInterval(() => setAtEnd(x => !x), periodMs / 2)
    return () => window.clearInterval(t)
  }, [playing, periodMs])
  const onTap = () => { if (prefersReducedMotion()) setAtEnd(x => !x); else setPlaying(p => !p) }
  return (
    <button className="pose" onClick={onTap} aria-label={`${label ?? 'exercise'} animation, ${playing ? 'tap to pause' : 'tap to play'}`} style={{ ['--pose-fade' as string]: `${Math.round(periodMs / 6)}ms` }}>
      <img className={'pose-frame' + (atEnd ? '' : ' on')} src={start.src} alt={start.alt ?? 'start position'} draggable={false} />
      <img className={'pose-frame' + (atEnd ? ' on' : '')} src={end.src} alt={end.alt ?? 'end position'} draggable={false} />
      <span className="pose-label">{atEnd ? 'end' : 'start'}{playing ? '' : ' · paused'}</span>
    </button>
  )
}
