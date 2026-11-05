import { Link } from 'react-router-dom'
import type { Athlete, Ranking } from '../types'

export function initials(name: string): string {
  return name.split(/\s+/).filter(Boolean).slice(0, 2).map(p => p[0]!.toUpperCase()).join('')
}

export function Avatar({ athlete, size = 44 }: { athlete: Athlete; size?: number }) {
  return athlete.photoUrl
    ? <img className="news-avatar" src={athlete.photoUrl} alt="" width={size} height={size} loading="lazy" />
    : <span className="news-avatar news-avatar-text" style={{ width: size, height: size }}>{initials(athlete.name)}</span>
}

export function RankingList({ ranking, athletes }: { ranking: Ranking; athletes: Map<string, Athlete> }) {
  return (
    <div className="stack" style={{ gap: 6 }}>
      <div className="row"><b className="grow">{ranking.title}</b><span className="small faint">{ranking.updatedAt}</span></div>
      {ranking.entries.slice().sort((a, b) => a.rank - b.rank).map(e => {
        const a = athletes.get(e.athleteId)
        if (!a) return null
        return (
          <Link key={e.athleteId} to={`/news/athlete/${a.slug}`} className="card row news-rank">
            <span className="news-rank-no">{e.rank}</span>
            <Avatar athlete={a} />
            <div className="grow">
              <div style={{ fontWeight: 600 }}>{a.name}</div>
              <div className="small faint">{[a.country, a.division, e.note].filter(Boolean).join(' · ')}</div>
            </div>
            <span className="faint">›</span>
          </Link>
        )
      })}
    </div>
  )
}
