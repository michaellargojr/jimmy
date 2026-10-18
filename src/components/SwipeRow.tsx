import { useRef, useState, type ReactNode } from 'react'

/** Swallow the click iOS synthesizes when a finger lifts after a hold-triggered action. */
export function swallowNextClick(ms = 800) {
  const handler = (e: Event) => { e.preventDefault(); e.stopPropagation(); cleanup() }
  const cleanup = () => { document.removeEventListener('click', handler, true); window.clearTimeout(t) }
  document.addEventListener('click', handler, true)
  const t = window.setTimeout(cleanup, ms)
}

const TrashIcon = () => (
  <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
    <path d="M4 7h16" /><path d="M10 11v6" /><path d="M14 11v6" />
    <path d="M6 7l1 13h10l1-13" /><path d="M9 7V4h6v3" />
  </svg>
)

const OPEN_W = 84 // px the row slides to reveal delete
const INTENT_PX = 10 // travel before we decide swipe vs scroll
const INTENT_RATIO = 1.5 // |dx| must beat |dy| by this much to count as a swipe

/** Swipe left (clear horizontal intent only) to reveal delete; tap closes an open row, otherwise onTap. */
export function SwipeRow({ children, onDelete, onTap, disabled }: { children: ReactNode; onDelete: () => void; onTap?: () => void; disabled?: boolean }) {
  const [dx, setDx] = useState(0)
  const [open, setOpen] = useState(false)
  const [dragging, setDragging] = useState(false)
  const start = useRef<{ x: number; y: number } | null>(null)
  const axis = useRef<'x' | 'y' | null>(null)

  const onStart = (x: number, y: number) => { if (disabled) return; start.current = { x, y }; axis.current = null }
  const onMove = (x: number, y: number) => {
    if (!start.current || disabled) return
    const ddx = x - start.current.x, ddy = y - start.current.y
    if (axis.current == null) {
      if (Math.abs(ddx) < INTENT_PX && Math.abs(ddy) < INTENT_PX) return
      axis.current = Math.abs(ddx) > Math.abs(ddy) * INTENT_RATIO ? 'x' : 'y'
      if (axis.current === 'x') setDragging(true)
    }
    if (axis.current !== 'x') return
    const base = open ? -OPEN_W : 0
    setDx(Math.max(-OPEN_W - 16, Math.min(0, base + ddx)))
  }
  const onEnd = () => {
    if (!start.current) return
    start.current = null
    if (axis.current === 'x') {
      const shouldOpen = dx < -OPEN_W / 2
      setOpen(shouldOpen); setDx(shouldOpen ? -OPEN_W : 0)
    }
    axis.current = null; setDragging(false)
  }
  const onClick = () => {
    if (open) { setOpen(false); setDx(0); return }
    onTap?.()
  }
  return (
    <div style={{ position: 'relative', overflow: 'hidden', borderRadius: 'var(--radius)', background: 'var(--bg)' }}>
      <button onClick={e => { e.stopPropagation(); onDelete() }} aria-label="Delete"
        style={{ position: 'absolute', top: 0, bottom: 0, right: 0, width: OPEN_W, background: 'var(--red)', color: '#fff', display: 'grid', placeItems: 'center', visibility: dx < 0 ? 'visible' : 'hidden' }}>
        <TrashIcon />
      </button>
      <div
        style={{ transform: `translateX(${dx}px)`, transition: dragging ? 'none' : 'transform .18s ease', touchAction: 'pan-y', position: 'relative' }}
        onTouchStart={e => onStart(e.touches[0].clientX, e.touches[0].clientY)}
        onTouchMove={e => onMove(e.touches[0].clientX, e.touches[0].clientY)}
        onTouchEnd={onEnd} onTouchCancel={onEnd}
        onPointerDown={e => { if (e.pointerType === 'mouse') onStart(e.clientX, e.clientY) }}
        onPointerMove={e => { if (e.pointerType === 'mouse' && e.buttons) onMove(e.clientX, e.clientY) }}
        onPointerUp={e => { if (e.pointerType === 'mouse') onEnd() }}
        onClick={onClick}
      >
        {children}
      </div>
    </div>
  )
}
