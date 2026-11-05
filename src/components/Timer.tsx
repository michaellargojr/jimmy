/**
 * Live elapsed time. Owns its own 1 s interval so only this <span> re-renders
 * every second, not the page that contains it. (Live.tsx used to keep the tick in
 * page state, which re-rendered every ExerciseCard, every set row and every
 * history lookup once per second.)
 */
import { useEffect, useState } from 'react'
import { elapsed } from '../derive'

export function Timer({ startedAt, endedAt, className, idle = 'not started' }: { startedAt?: number; endedAt?: number; className?: string; idle?: string }) {
  const running = !!startedAt && !endedAt
  const [, tick] = useState(0)
  useEffect(() => {
    if (!running) return
    const t = window.setInterval(() => tick(x => x + 1), 1000)
    return () => window.clearInterval(t)
  }, [running])
  if (!startedAt) return <span className={className}>{idle}</span>
  return <span className={className}>{elapsed((endedAt ?? Date.now()) - startedAt)}</span>
}
