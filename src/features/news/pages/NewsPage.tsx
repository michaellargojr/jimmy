import { useState } from 'react'
import { Link } from 'react-router-dom'
import { useNews } from '../useNews'
import { RankingList } from '../components/RankingList'
import '../news.css'

type Tab = 'top10' | 'news'

export default function NewsPage() {
  const { loading, result, refresh } = useNews()
  const [tab, setTab] = useState<Tab>('top10')
  const bundle = result?.bundle
  const athletes = new Map(bundle?.athletes.map(a => [a.id, a]) ?? [])
  return (
    <div className="page">
      <div className="topbar">
        <Link className="iconbtn" to="/" aria-label="Home">‹</Link>
        <h1>News</h1>
        <button className="chip" onClick={refresh} disabled={loading}>{loading ? '…' : 'refresh'}</button>
      </div>
      {result?.origin === 'sample' && <div className="banner">Showing placeholder data. Configure VITE_NEWS_URL to load a real bundle.</div>}
      <div className="row" style={{ gap: 6, marginBottom: 12 }}>
        <button className={'chip' + (tab === 'top10' ? ' on' : '')} onClick={() => setTab('top10')}>Top 10</button>
        <button className={'chip' + (tab === 'news' ? ' on' : '')} onClick={() => setTab('news')}>News</button>
        <span className="grow" />
        {bundle && <span className="small faint">updated {bundle.generatedAt.slice(0, 10)}</span>}
      </div>
      {!bundle && <div className="muted">Loading…</div>}
      {bundle && tab === 'top10' && bundle.rankings.map(r => <RankingList key={r.id} ranking={r} athletes={athletes} />)}
      {bundle && tab === 'news' && (
        <div className="stack">
          {bundle.news.slice().sort((a, b) => b.publishedAt.localeCompare(a.publishedAt)).map(n => (
            <a key={n.id} className="card news-item" href={n.url} target="_blank" rel="noopener noreferrer">
              <div style={{ fontWeight: 600 }}>{n.title}</div>
              {n.summary && <div className="small muted" style={{ marginTop: 4 }}>{n.summary}</div>}
              <div className="small faint" style={{ marginTop: 6 }}>{n.source} · {n.publishedAt.slice(0, 10)}</div>
            </a>
          ))}
          {bundle.news.length === 0 && <div className="muted">No news yet.</div>}
        </div>
      )}
    </div>
  )
}
