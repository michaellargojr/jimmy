import type { LastSession } from '../derive'
import { fmtSet, setupLabel, type Version } from '../model'

export function LastTime({ last, other }: { last?: LastSession; other?: LastSession & { version: Version } }) {
  if (!last && !other) return <div className="lasttime">first time</div>
  return (
    <div className="lasttime">
      {last && (
        <div>
          <b>{last.daysAgo === 0 ? 'today' : `${last.daysAgo}d ago`}</b>
          {last.verdict === 'up' && <span className="badge up" style={{ marginLeft: 8 }}>hit max</span>}
          {last.verdict === 'down' && <span className="badge down" style={{ marginLeft: 8 }}>under</span>}
          <br />
          {last.item.sets.filter(s => s.reps != null || s.weight != null).map(s => (s.kind === 'warmup' ? 'W ' : '') + fmtSet(s)).join(' · ')}
          {setupLabel(last.item) && <><br /><span className="small">setup: {setupLabel(last.item)}</span></>}
          {last.item.sets.some(s => s.note) && <><br /><span className="small">{last.item.sets.filter(s => s.note).map(s => `${s.side ?? ''}${s.kind === 'warmup' ? 'W' : ''} ${s.note}`.trim()).join(' · ')}</span></>}
          {last.item.note && <><br /><span className="small">{last.item.note}</span></>}
        </div>
      )}
      {other && (
        <div className="small" style={{ marginTop: 4, opacity: .8 }}>
          {other.version.name} ({other.daysAgo}d): {other.item.sets.filter(s => s.reps != null).map(fmtSet).join(' · ')}
        </div>
      )}
    </div>
  )
}
