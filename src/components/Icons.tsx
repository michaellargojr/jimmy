export { CABLE_MARKS, cableLabel } from '../model'

/** Standing silhouette with a green marker at cable height h (0..1). */
export function CableIcon({ h, size = 22 }: { h: number; size?: number }) {
  const y = 2 + (1 - Math.max(0, Math.min(1, h))) * 20
  return (
    <svg width={size / 2} height={size} viewBox="0 0 12 24" aria-hidden="true" style={{ verticalAlign: 'middle', overflow: 'visible' }}>
      <circle cx="6" cy="3" r="2.2" fill="currentColor" opacity=".45" />
      <path d="M6 5.5v8M3 7.5l3-1 3 1M6 13.5l-2.5 8M6 13.5l2.5 8" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" fill="none" opacity=".45" />
      <line x1="-1" x2="13" y1={y} y2={y} stroke="var(--accent)" strokeWidth="2.2" strokeLinecap="round" />
    </svg>
  )
}

/** Bench seen from the side: flat seat, back rotated up by `angle` degrees. */
export function BenchIcon({ angle, size = 22 }: { angle: number; size?: number }) {
  const a = (Math.max(0, Math.min(90, angle)) * Math.PI) / 180
  const x2 = 10 - Math.cos(a) * 9, y2 = 16 - Math.sin(a) * 9
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" aria-hidden="true" style={{ verticalAlign: 'middle' }}>
      <line x1="10" y1="16" x2="22" y2="16" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" opacity=".55" />
      <line x1="10" y1="16" x2={x2} y2={y2} stroke="var(--accent)" strokeWidth="2.4" strokeLinecap="round" />
      <path d="M13 17v4M19 17v4" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" opacity=".4" />
    </svg>
  )
}

export function PlayIcon({ size = 14 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" aria-hidden="true" style={{ verticalAlign: '-2px' }}>
      <path d="M7 4.5v15l12-7.5z" fill="currentColor" />
    </svg>
  )
}
