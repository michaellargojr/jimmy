import { useEffect, useState } from 'react'
import { loadNewsBundle, type LoadResult } from './api'

export interface NewsState { loading: boolean; result?: LoadResult; refresh: () => void }

/** One load per mount, with a manual refresh. Components look up athletes via the returned bundle. */
export function useNews(): NewsState {
  const [result, setResult] = useState<LoadResult | undefined>(undefined)
  const [loading, setLoading] = useState(true)
  const [nonce, setNonce] = useState(0)
  useEffect(() => {
    let alive = true
    setLoading(true)
    void loadNewsBundle({ force: nonce > 0 }).then(r => { if (alive) { setResult(r); setLoading(false) } })
    return () => { alive = false }
  }, [nonce])
  return { loading, result, refresh: () => setNonce(n => n + 1) }
}
