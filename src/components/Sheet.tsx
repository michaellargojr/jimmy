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
 * Bottom sheet. Sized to the *visual* viewport so it stays above the iOS keyboard and its
 * buttons stay where they are drawn (fixed elements otherwise drift when Safari scrolls
 * the page to reveal a focused field, which is what made taps land on the wrong thing).
 */
export function Sheet({ open, onClose, title, children }: { open: boolean; onClose: () => void; title?: string; children: ReactNode }) {
  const openedAt = useRef(0)
  const backdrop = useRef<HTMLDivElement>(null)
  const [vv, setVv] = useState<{ bottom: number; height: number }>({ bottom: 0, height: 0 })
  useEffect(() => {
    if (!open) return
    openedAt.current = Date.now()
    lockScroll()
    const v = window.visualViewport
    const update = () => {
      if (!v) return
      setVv({ bottom: Math.max(0, Math.round(window.innerHeight - (v.height + v.offsetTop))), height: Math.round(v.height) })
    }
    update()
    v?.addEventListener('resize', update); v?.addEventListener('scroll', update)
    return () => { v?.removeEventListener('resize', update); v?.removeEventListener('scroll', update); unlockScroll() }
  }, [open])
  useEffect(() => {
    const el = backdrop.current; if (!el) return
    const block = (e: TouchEvent) => e.preventDefault()
    el.addEventListener('touchmove', block, { passive: false })
    return () => el.removeEventListener('touchmove', block)
  }, [open])
  if (!open) return null
  return createPortal(
    <>
      <div ref={backdrop} className="backdrop" onClick={() => { if (Date.now() - openedAt.current > 400) onClose() }} />
      <div className="sheet" role="dialog" style={{ bottom: vv.bottom, maxHeight: vv.height ? Math.round(vv.height * 0.92) : undefined }}>
        <div className="handle" />
        {title && <h3>{title}</h3>}
        {children}
      </div>
    </>,
    document.body,
  )
}
