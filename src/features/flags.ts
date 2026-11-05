/**
 * Feature flags for work that is in the repo but not in the product yet.
 *
 * Defaults are what ships. To try a draft on a device without a rebuild, set
 *   localStorage.setItem('jimmy.flags', JSON.stringify({ news: true }))
 * in the browser console and reload. Remove the flag when a feature ships.
 */
export interface FeatureFlags {
  /** Bodybuilding news + Mr. Olympia top 10 + athlete profiles. DRAFT. */
  news: boolean
  /** Two-state (start/end) exercise animation on ExerciseCard. DRAFT. */
  pose3d: boolean
}

const DEFAULTS: FeatureFlags = { news: false, pose3d: false }

function readOverrides(): Partial<FeatureFlags> {
  try {
    const raw = typeof localStorage !== 'undefined' ? localStorage.getItem('jimmy.flags') : null
    return raw ? (JSON.parse(raw) as Partial<FeatureFlags>) : {}
  } catch { return {} }
}

export const FEATURES: Readonly<FeatureFlags> = Object.freeze({ ...DEFAULTS, ...readOverrides() })
