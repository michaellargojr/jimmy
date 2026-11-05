/**
 * Tap-to-load video card. Nothing third-party loads until the user taps, which
 * keeps the page fast and avoids tracking by default.
 *  - YouTube: thumbnail from i.ytimg.com, then a youtube-nocookie iframe.
 *  - TikTok / other: a card that opens the link (TikTok's embed needs their script).
 */
import { useState } from 'react'
import type { Video } from '../types'

export function youtubeId(url: string): string | undefined {
  try {
    const u = new URL(url)
    if (u.hostname === 'youtu.be') return u.pathname.slice(1) || undefined
    if (u.hostname.endsWith('youtube.com')) {
      if (u.searchParams.get('v')) return u.searchParams.get('v') ?? undefined
      const m = u.pathname.match(/\/(shorts|embed)\/([\w-]+)/)
      if (m) return m[2]
    }
  } catch { /* not a URL */ }
  return undefined
}

export function VideoEmbed({ video }: { video: Video }) {
  const [playing, setPlaying] = useState(false)
  const yt = video.kind === 'youtube' ? youtubeId(video.url) : undefined
  if (yt && playing) {
    return (
      <div className="news-video">
        <iframe
          src={`https://www.youtube-nocookie.com/embed/${yt}?autoplay=1&playsinline=1&rel=0`}
          title={video.title} allow="autoplay; encrypted-media; picture-in-picture" allowFullScreen />
      </div>
    )
  }
  if (yt) {
    return (
      <button className="news-video" onClick={() => setPlaying(true)} aria-label={`Play ${video.title}`}>
        <img src={`https://i.ytimg.com/vi/${yt}/hqdefault.jpg`} alt="" loading="lazy" />
        <span className="news-play">▶</span>
        <span className="news-video-title">{video.title}</span>
      </button>
    )
  }
  return (
    <a className="news-video news-video-link" href={video.url} target="_blank" rel="noopener noreferrer">
      <span className="news-play">↗</span>
      <span className="news-video-title">{video.title}<br /><span className="small faint">{video.kind === 'tiktok' ? 'Opens in TikTok' : 'Opens link'}</span></span>
    </a>
  )
}
