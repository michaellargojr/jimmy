import { useEffect, useRef, useState, type ReactNode } from 'react'
import { createPortal } from 'react-dom'

// Body scroll lock shared by every open sheet. position:fixed is the only lock iOS honours.
let locks = 0, savedY = 0
function lockScroll() {
  if (locks++ > 0) return
  savedY = window.scrollY
  const b = document.body.style
  b.position = 'fixed'; b.top = `-${savedY}px`; b.left = '0'; b.right = '0'; b.width = '100%'
}
function unlockScroll() {
  if (--locks > 0) return
  const b = document.body.style
  b.position = ''; b.top = ''; b.left = ''; b.right = ''; b.width = ''
  window.scrollTo(0, savedY)
}

const CLOSE_PX = 90 // drag this far down to close
const CLOSE_V = 0.6 // or flick faster than this (px per ms)

/**
 * Sheet. `side="bottom"` (default): sized to the visual viewport so it stays above the iOS
 * keyboard, and it slides down with your finger to close, like a native sheet. Its content
 * scrolls normally; a downward drag only moves the sheet once the content is at its top.
 * `side="top"` hangs from the top of the screen (kept for reference, unused).
 */
export function Sheet({ open, onClose, title, children, side = 'bottom' }: { open: boolean; onClose: () => void; title?: string; children: ReactNode; side?: 'bottom' | 'top' }) {
  const openedAt = useRef(0)
  const backdrop = useRef<HTMLDivElement>(null)
  const sheet = useRef<HTMLDivElement>(null)
  const [vv, setVv] = useState<{ bottom: number; height: number }>({ bottom: 0, height: 0 })
  const [dy, setDy] = useState(0)
  const [dragging, setDragging] = useState(false)
  const onCloseRef = useRef(onClose); onCloseRef.current = onClose

  useEffect(() => {
    if (!open) return
    openedAt.current = Date.now()
    setDy(0); setDragging(false)
    lockScroll()
    const v = window.visualViewport
    let raf = 0
    const update = () => {
      if (!v) return
      // iOS often leaves the visual viewport scrolled up after the keyboard closes (offsetTop > 0
      // with full height). Put it back, and in the meantime let `bottom` follow the visible area.
      const keyboardClosed = v.height >= window.innerHeight - 1
      if (keyboardClosed && v.offsetTop > 0) { cancelAnimationFrame(raf); raf = requestAnimationFrame(() => window.scrollTo(0, 0)) }
      setVv({ bottom: Math.round(window.innerHeight - (v.height + v.offsetTop)), height: Math.round(v.height) })
    }
    update()
    v?.addEventListener('resize', update); v?.addEventListener('scroll', update)
    return () => { cancelAnimationFrame(raf); v?.removeEventListener('resize', update); v?.removeEventListener('scroll', update); unlockScroll() }
  }, [open])

  // Backdrop never scrolls the page; the sheet follows a downward drag (native listeners so we can preventDefault).
  useEffect(() => {
    if (!open) return
    const bd = backdrop.current, el = sheet.current
    if (!bd || !el) return
    const block = (e: TouchEvent) => e.preventDefault()
    bd.addEventListener('touchmove', block, { passive: false })
    if (side !== 'bottom') return () => bd.removeEventListener('touchmove', block)
    let start: { y: number; t: number } | null = null, moved = 0, active = false
    const onStart = (e: TouchEvent) => { start = { y: e.touches[0].clientY, t: Date.now() }; moved = 0; active = false }
    const onMove = (e: TouchEvent) => {
      if (!start) return
      const d = e.touches[0].clientY - start.y
      if (!active) {
        if (d > 6 && el.scrollTop <= 0) { active = true; setDragging(true) } // pulling down with content at its top
        else if (d < -6 || el.scrollTop > 0) { start = null; return } // scrolling content instead
        else return
      }
      moved = Math.max(0, d)
      setDy(moved)
      e.preventDefault() // no rubber band under the drag
    }
    const onEnd = () => {
      if (!start) return
      const dt = Math.max(1, Date.now() - start.t)
      const close = active && (moved > CLOSE_PX || (moved > 24 && moved / dt > CLOSE_V))
      start = null; active = false; setDragging(false)
      if (close) { setDy(el.offsetHeight + 40); setTimeout(() => { onCloseRef.current(); setDy(0) }, 160) }
      else setDy(0)
    }
    el.addEventListener('touchstart', onStart, { passive: true })
    el.addEventListener('touchmove', onMove, { passive: false })
    el.addEventListener('touchend', onEnd); el.addEventListener('touchcancel', onEnd)
    return () => {
      bd.removeEventListener('touchmove', block)
      el.removeEventListener('touchstart', onStart); el.removeEventListener('touchmove', onMove)
      el.removeEventListener('touchend', onEnd); el.removeEventListener('touchcancel', onEnd)
    }
  }, [open, side])

  // Fallback for a focused field the keyboard would hide: reveal it only if it is actually out of view.
  const onFocus = (e: React.FocusEvent) => {
    const t = e.target as HTMLElement
    if (t.tagName !== 'INPUT' && t.tagName !== 'TEXTAREA') return
    setTimeout(() => {
      const v = window.visualViewport; if (!v) return
      const r = t.getBoundingClientRect()
      if (r.bottom > v.offsetTop + v.height || r.top < v.offsetTop) t.scrollIntoView({ block: 'center', behavior: 'smooth' })
    }, 300)
  }

  if (!open) return null
  const style = side === 'top'
    ? { maxHeight: vv.height ? Math.round(vv.height - 8) : undefined }
    : { bottom: vv.bottom, maxHeight: vv.height ? Math.round(vv.height * 0.92) : undefined, transform: dy ? `translateY(${dy}px)` : undefined, transition: dragging ? 'none' : 'transform .18s ease-out' }
  return createPortal(
    <>
      <div ref={backdrop} className="backdrop" style={{ opacity: dy ? Math.max(0.2, 1 - dy / 400) : 1 }} onClick={() => { if (Date.now() - openedAt.current > 400) onClose() }} />
      <div ref={sheet} className={'sheet' + (side === 'top' ? ' top' : '')} role="dialog" style={style} onFocus={onFocus}>
        {side === 'bottom' && <div className="handle" />}
        {title && <h3>{title}</h3>}
        {children}
        {side === 'top' && <button className="handle close" onClick={onClose} aria-label="Close" />}
      </div>
    </>,
    document.body,
  )
}
