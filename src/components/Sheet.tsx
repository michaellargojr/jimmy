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

/**
 * Sheet. `side="bottom"` (default) is for pickers and menus: no typing, sized to the visual
 * viewport. `side="top"` is for anything with a text field: it hangs from the top of the screen
 * with the field right under the status bar, so the iOS keyboard can never cover it, whatever
 * the viewport does in a home-screen app.
 */
export function Sheet({ open, onClose, title, children, side = 'bottom' }: { open: boolean; onClose: () => void; title?: string; children: ReactNode; side?: 'bottom' | 'top' }) {
  const openedAt = useRef(0)
  const backdrop = useRef<HTMLDivElement>(null)
  const [vv, setVv] = useState<{ bottom: number; height: number }>({ bottom: 0, height: 0 })
  useEffect(() => {
    if (!open) return
    openedAt.current = Date.now()
    lockScroll()
    const v = window.visualViewport
    let raf = 0
    const update = () => {
      if (!v) return
      // iOS often leaves the visual viewport scrolled up after the keyboard closes (offsetTop > 0
      // with full height). Put it back, and in the meantime let `bottom` go negative so the sheet
      // follows the visible area down instead of hanging above it with the page showing underneath.
      const keyboardClosed = v.height >= window.innerHeight - 1
      if (keyboardClosed && v.offsetTop > 0) { cancelAnimationFrame(raf); raf = requestAnimationFrame(() => window.scrollTo(0, 0)) }
      setVv({ bottom: Math.round(window.innerHeight - (v.height + v.offsetTop)), height: Math.round(v.height) })
    }
    update()
    v?.addEventListener('resize', update); v?.addEventListener('scroll', update)
    return () => { cancelAnimationFrame(raf); v?.removeEventListener('resize', update); v?.removeEventListener('scroll', update); unlockScroll() }
  }, [open])
  useEffect(() => {
    const el = backdrop.current; if (!el) return
    const block = (e: TouchEvent) => e.preventDefault()
    el.addEventListener('touchmove', block, { passive: false })
    return () => el.removeEventListener('touchmove', block)
  }, [open])
  // Fallback for a focused field the keyboard would hide: ask the browser to reveal it once the keyboard is up.
  const onFocus = (e: React.FocusEvent) => {
    const t = e.target as HTMLElement
    if (t.tagName === 'INPUT' || t.tagName === 'TEXTAREA') setTimeout(() => t.scrollIntoView({ block: 'center', behavior: 'smooth' }), 250)
  }
  if (!open) return null
  const style = side === 'top'
    ? { maxHeight: vv.height ? Math.round(vv.height - 8) : undefined }
    : { bottom: vv.bottom, maxHeight: vv.height ? Math.round(vv.height * 0.92) : undefined }
  return createPortal(
    <>
      <div ref={backdrop} className="backdrop" onClick={() => { if (Date.now() - openedAt.current > 400) onClose() }} />
      <div className={'sheet' + (side === 'top' ? ' top' : '')} role="dialog" style={style} onFocus={onFocus}>
        {side === 'bottom' && <div className="handle" />}
        {title && <h3>{title}</h3>}
        {children}
        {side === 'top' && <button className="handle close" onClick={onClose} aria-label="Close" />}
      </div>
    </>,
    document.body,
  )
}
