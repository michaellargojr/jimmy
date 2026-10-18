import { useEffect, useRef, type ReactNode } from 'react'

export function Sheet({ open, onClose, title, children }: { open: boolean; onClose: () => void; title?: string; children: ReactNode }) {
  const openedAt = useRef(0)
  useEffect(() => {
    if (!open) return
    openedAt.current = Date.now()
    const prev = document.body.style.overflow
    document.body.style.overflow = 'hidden'
    return () => { document.body.style.overflow = prev }
  }, [open])
  if (!open) return null
  return (
    <>
      <div className="backdrop" onClick={() => { if (Date.now() - openedAt.current > 400) onClose() }} />
      <div className="sheet" role="dialog">
        <div className="handle" />
        {title && <h3>{title}</h3>}
        {children}
      </div>
    </>
  )
}
