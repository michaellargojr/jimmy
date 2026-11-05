import { Link, useParams } from 'react-router-dom'
import { useNews } from '../useNews'
import { Avatar } from '../components/RankingList'
import { VideoEmbed } from '../components/VideoEmbed'
import '../news.css'

export default function AthletePage() {
  const { slug } = useParams()
  const { result } = useNews()
  const a = result?.bundle.athletes.find(x => x.slug === slug)
  if (!result) return <div className="page muted">Loading…</div>
  if (!a) return <div className="page">Athlete not found. <Link to="/news">Back to news</Link></div>
  const videosFor = (exerciseId: string) => a.videos.filter(v => v.exerciseIds?.includes(exerciseId))
  const generalVideos = a.videos.filter(v => !v.exerciseIds?.length)
  return (
    <div className="page">
      <div className="topbar"><Link className="iconbtn" to="/news" aria-label="Back">‹</Link><h1>{a.name}</h1></div>
      <div className="card row" style={{ alignItems: 'flex-start' }}>
        <Avatar athlete={a} size={64} />
        <div className="grow">
          <div className="small muted">{[a.country, a.division, a.bestResult].filter(Boolean).join(' · ')}</div>
          {a.stats && (
            <div className="small faint" style={{ marginTop: 4 }}>
              {[a.stats.heightCm && `${a.stats.heightCm} cm`, a.stats.competitionWeightKg && `${a.stats.competitionWeightKg} kg on stage`, a.stats.proSince && `pro since ${a.stats.proSince}`].filter(Boolean).join(' · ')}
            </div>
          )}
          {a.bio && <p className="small" style={{ margin: '8px 0 0' }}>{a.bio}</p>}
        </div>
      </div>

      <div className="small faint" style={{ margin: '16px 0 6px' }}>Favourite exercises</div>
      <div className="stack">
        {a.favoriteExercises.map(f => (
          <div key={f.id} className="card stack" style={{ gap: 6 }}>
            <div className="row">
              <div className="grow"><b>{f.name}</b>{f.muscle && <span className="small faint"> · {f.muscle}</span>}</div>
              {/* Library.tsx does not read ?q yet; see README "Wiring points". */}
              <Link className="chip" to={`/library?q=${encodeURIComponent(f.libraryName ?? f.name)}`}>find in library</Link>
            </div>
            {f.why && <div className="small muted">{f.why}</div>}
            {f.cue && <div className="small" style={{ fontStyle: 'italic' }}>Cue: {f.cue}</div>}
            {videosFor(f.id).map(v => <VideoEmbed key={v.id} video={v} />)}
          </div>
        ))}
        {a.favoriteExercises.length === 0 && <div className="muted">No favourites recorded.</div>}
      </div>

      {generalVideos.length > 0 && (
        <>
          <div className="small faint" style={{ margin: '16px 0 6px' }}>Training videos</div>
          <div className="stack">{generalVideos.map(v => <VideoEmbed key={v.id} video={v} />)}</div>
        </>
      )}

      {a.sources && a.sources.length > 0 && (
        <div className="small faint" style={{ marginTop: 16 }}>
          Sources: {a.sources.map((s, i) => <a key={s} href={s} target="_blank" rel="noopener noreferrer" style={{ textDecoration: 'underline' }}>[{i + 1}]</a>)}
        </div>
      )}
    </div>
  )
}
