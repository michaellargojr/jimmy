/**
 * Bottom sheet rendered at document.body so it escapes any transformed /
 * overflow-hidden ancestor (the Live pager, dnd-kit rows). Backdrop taps are
 * ignored for the first 400 ms so the tap that opened the sheet cannot also close
 * it. Escape closes it on desktop.
 */
import { useEffect, useRef, type ReactNode } from 'react'
import { createPortal } from 'react-dom'

const IGNORE_BACKDROP_MS = 400

export function Sheet({ open, onClose, title, children }: { open: boolean; onClose: () => void; title?: string; children: ReactNode }) {
  const openedAt = useRef(0)
  useEffect(() => {
    if (!open) return
    openedAt.current = Date.now()
    const prev = document.body.style.overflow
    document.body.style.overflow = 'hidden'
    const onKey = (e: KeyboardEvent) => { if (e.key === 'Escape') onClose() }
    document.addEventListener('keydown', onKey)
    return () => { document.body.style.overflow = prev; document.removeEventListener('keydown', onKey) }
  }, [open, onClose])
  if (!open) return null
  return createPortal(
    <>
      <div className="backdrop" onClick={() => { if (Date.now() - openedAt.current > IGNORE_BACKDROP_MS) onClose() }} />
      <div className="sheet" role="dialog" aria-modal="true" aria-label={title}>
        <div className="handle" />
        {title && <h3>{title}</h3>}
        {children}
      </div>
    </>,
    document.body,
  )
}
