/**
 * Press-and-hold-still gesture for touch screens.
 *
 * Fires `onHold` once when a finger stays down for `ms` and drifts less than
 * `tolerance` px. Used by Plan rows (open the options sheet) and ExerciseCard
 * headers (open the ⋯ menu). On fire it:
 *  1. runs `beforeFire` (Plan cancels dnd-kit's in-flight drag here),
 *  2. swallows the click iOS synthesises when the finger lifts,
 *  3. gives a short haptic where the platform supports it (not iOS Safari).
 *
 * Timing constants live here so both call sites feel identical. Changing HOLD_MS
 * also changes how long "hold to drag" (dnd-kit, 180 ms) and "hold still for
 * options" (this, 1500 ms) overlap; see docs/ARCHITECTURE.md "Gestures".
 */
import { useEffect, useRef, type TouchEvent } from 'react'
import { swallowNextClick } from './SwipeRow'

export const HOLD_MS = 1500
export const HOLD_TOLERANCE = 4 // px of drift that cancels the hold

export interface HoldHandlers {
  onTouchStart: (e: TouchEvent) => void
  onTouchMove: (e: TouchEvent) => void
  onTouchEnd: () => void
  onTouchCancel: () => void
}

export function useHold(onHold: () => void, opts: { ms?: number; tolerance?: number; beforeFire?: () => void } = {}): HoldHandlers {
  const { ms = HOLD_MS, tolerance = HOLD_TOLERANCE, beforeFire } = opts
  const timer = useRef<number | undefined>(undefined)
  const origin = useRef<{ x: number; y: number } | null>(null)
  // Always call the newest callbacks even though the timer captured an older render.
  const latest = useRef({ onHold, beforeFire })
  useEffect(() => { latest.current = { onHold, beforeFire } })
  const clear = () => { window.clearTimeout(timer.current); timer.current = undefined; origin.current = null }
  useEffect(() => clear, [])
  return {
    onTouchStart: e => {
      const t = e.touches[0]
      origin.current = { x: t.clientX, y: t.clientY }
      window.clearTimeout(timer.current)
      timer.current = window.setTimeout(() => {
        if (!origin.current) return
        latest.current.beforeFire?.()
        clear()
        swallowNextClick()
        try { navigator.vibrate?.(20) } catch { /* unsupported */ }
        latest.current.onHold()
      }, ms)
    },
    onTouchMove: e => {
      if (!origin.current) return
      const t = e.touches[0]
      if (Math.hypot(t.clientX - origin.current.x, t.clientY - origin.current.y) > tolerance) clear()
    },
    onTouchEnd: clear,
    onTouchCancel: clear,
  }
}
