import { useRef, useState, type ReactNode } from 'react'

/** Swipe left to reveal a red delete button; press and hold for options. */
export function SwipeRow({ children, onDelete, onHold, disabled }: { children: ReactNode; onDelete: () => void; onHold?: () => void; disabled?: boolean }) {
  const [dx, setDx] = useState(0)
  const [open, setOpen] = useState(false)
  const start = useRef<{ x: number; y: number } | null>(null)
  const moved = useRef(false)
  const hold = useRef<number | undefined>(undefined)
  const W = 84

  const onStart = (x: number, y: number) => {
    if (disabled) return
    start.current = { x, y }; moved.current = false
    if (onHold) hold.current = window.setTimeout(() => { if (!moved.current) { hold.current = undefined; try { navigator.vibrate?.(15) } catch {} ; onHold() } }, 450)
  }
  const onMove = (x: number, y: number) => {
    if (!start.current || disabled) return
    const ddx = x - start.current.x, ddy = y - start.current.y
    if (Math.abs(ddx) > 6 || Math.abs(ddy) > 6) { moved.current = true; window.clearTimeout(hold.current) }
    if (Math.abs(ddy) > Math.abs(ddx)) return
    const base = open ? -W : 0
    setDx(Math.max(-W - 20, Math.min(0, base + ddx)))
  }
  const onEnd = () => {
    window.clearTimeout(hold.current)
    if (!start.current) return
    const shouldOpen = dx < -W / 2
    setOpen(shouldOpen); setDx(shouldOpen ? -W : 0)
    start.current = null
  }
  return (
    <div style={{ position: 'relative', overflow: 'hidden', borderRadius: 'var(--radius)' }}>
      <button onClick={onDelete} aria-label="Delete"
        style={{ position: 'absolute', top: 0, bottom: 0, right: 0, width: W, background: 'var(--red)', color: '#fff', display: 'grid', placeItems: 'center', fontSize: 22 }}>🗑</button>
      <div
        style={{ transform: `translateX(${dx}px)`, transition: start.current ? 'none' : 'transform .18s ease', touchAction: 'pan-y', position: 'relative' }}
        onTouchStart={e => onStart(e.touches[0].clientX, e.touches[0].clientY)}
        onTouchMove={e => onMove(e.touches[0].clientX, e.touches[0].clientY)}
        onTouchEnd={onEnd}
        onPointerDown={e => { if (e.pointerType === 'mouse') onStart(e.clientX, e.clientY) }}
        onPointerMove={e => { if (e.pointerType === 'mouse' && e.buttons) onMove(e.clientX, e.clientY) }}
        onPointerUp={e => { if (e.pointerType === 'mouse') onEnd() }}
        onContextMenu={e => { if (onHold) { e.preventDefault(); onHold() } }}
        onClick={() => { if (open) { setOpen(false); setDx(0) } }}
      >
        {children}
      </div>
    </div>
  )
}
