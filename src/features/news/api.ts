/**
 * Loads the NewsBundle. Order: fresh localStorage cache -> network -> stale cache
 * -> bundled sample. The app is offline-first, so a failed fetch is normal, not an
 * error; we only report an error when there is nothing at all to show.
 */
import type { NewsBundle } from './types'
import { SAMPLE_BUNDLE } from './data/sample'

/** Build-time URL of the JSON bundle. Unset => sample data. */
export const NEWS_URL: string | undefined = import.meta.env.VITE_NEWS_URL as string | undefined
const CACHE_KEY = 'jimmy.news.bundle'
const CACHE_TTL_MS = 6 * 60 * 60 * 1000

interface Cached { fetchedAt: number; bundle: NewsBundle }

function readCache(): Cached | undefined {
  try {
    const raw = localStorage.getItem(CACHE_KEY)
    if (!raw) return undefined
    const c = JSON.parse(raw) as Cached
    return c.bundle?.version === 1 ? c : undefined
  } catch { return undefined }
}

function writeCache(bundle: NewsBundle) {
  try { localStorage.setItem(CACHE_KEY, JSON.stringify({ fetchedAt: Date.now(), bundle } satisfies Cached)) } catch { /* storage full or unavailable */ }
}

function isBundle(x: unknown): x is NewsBundle {
  if (!x || typeof x !== 'object') return false
  const b = x as Partial<NewsBundle>
  return b.version === 1 && Array.isArray(b.rankings) && Array.isArray(b.athletes) && Array.isArray(b.news)
}

export interface LoadResult { bundle: NewsBundle; origin: 'cache' | 'network' | 'stale-cache' | 'sample' }

export async function loadNewsBundle(opts: { force?: boolean } = {}): Promise<LoadResult> {
  const cached = readCache()
  if (!opts.force && cached && Date.now() - cached.fetchedAt < CACHE_TTL_MS) return { bundle: cached.bundle, origin: 'cache' }
  if (NEWS_URL) {
    try {
      const res = await fetch(NEWS_URL, { cache: 'no-cache' })
      if (res.ok) {
        const json: unknown = await res.json()
        if (isBundle(json)) { writeCache(json); return { bundle: json, origin: 'network' } }
      }
    } catch { /* offline */ }
  }
  if (cached) return { bundle: cached.bundle, origin: 'stale-cache' }
  return { bundle: SAMPLE_BUNDLE, origin: 'sample' }
}
