import type { SetEntry, Version } from '../model'
import { isBarbell } from '../model'

export function SetRow({ set, label, version, last, improved, onEdit, onPatch }: {
  set: SetEntry; label: string; version: Version; last?: SetEntry; improved: boolean
  onEdit: (field: 'weight' | 'reps') => void; onPatch: (patch: Partial<SetEntry>) => void
}) {
  const unitLabel = set.unit === 'lbs' ? 'lb' : 'kg'
  const cycleSide = () => onPatch({ side: set.side === undefined ? 'L' : set.side === 'L' ? 'R' : undefined })
  return (
    <div className="setrow">
      <button className="k" onClick={() => onPatch({ kind: set.kind === 'warmup' ? 'working' : 'warmup' })}>{label}</button>
      <button className={'field' + (set.weight == null ? ' empty' : '')} onClick={() => onEdit('weight')}>
        {last?.weight != null && <span className="ghost">{last.weight}</span>}
        {set.weight == null ? 'weight' : <>{set.weight}<small>{unitLabel}</small></>}
      </button>
      <button className={'field' + (set.reps == null ? ' empty' : '')} onClick={() => onEdit('reps')}>
        {last?.reps != null && <span className="ghost">{last.reps}{last.plus ? '+' : ''}{last.partials ? ` ${last.partials}p` : ''}</span>}
        {set.reps == null ? 'reps' : <>{set.reps}{set.plus ? '+' : ''}{set.partials ? <small>{set.partials}p</small> : null}</>}
        {improved && <span className="check">✓</span>}
      </button>
      <div className="setextras">
        <button className={'tog' + (set.plus ? ' on' : '')} onClick={() => onPatch({ plus: !set.plus })} aria-label="at least">+</button>
        {(version.arms === 'one' || isBarbell(version)) && (
          <div className="stack" style={{ gap: 4 }}>
            {version.arms === 'one' && <button className={'tog sm' + (set.side ? ' on' : '')} onClick={cycleSide}>{set.side ?? 'LR'}</button>}
            {isBarbell(version) && <button className={'tog sm' + (set.bar === 'ez' ? ' on' : '')} onClick={() => onPatch({ bar: set.bar === 'ez' ? 'straight' : 'ez' })}>{set.bar === 'ez' ? 'EZ' : 'BAR'}</button>}
          </div>
        )}
      </div>
      {set.note && <div className="setnote">{set.note}</div>}
    </div>
  )
}
