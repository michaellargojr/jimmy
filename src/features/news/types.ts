/**
 * Contract between the news UI and whatever produces the JSON bundle.
 * Keep it flat and JSON-friendly. Every record that states a fact about a real
 * person should carry `sources` so the claim can be checked.
 */
import type { MuscleGroup } from '../../model'

export type Division = 'Open' | 'Classic Physique' | '212' | "Men's Physique"

export interface Video {
  id: string
  title: string
  /** Canonical URL: youtube.com/watch?v=..., youtu.be/..., youtube.com/shorts/..., tiktok.com/@user/video/... */
  url: string
  kind: 'youtube' | 'tiktok' | 'other'
  durationSec?: number
  /** Which favourite exercises this video demonstrates (FavoriteExercise.id). */
  exerciseIds?: string[]
  tags?: string[]
}

export interface FavoriteExercise {
  id: string
  name: string
  /** Exact name in Jimmy's library (src/seed/library.ts) so "find in library" can match. */
  libraryName?: string
  muscle?: MuscleGroup
  /** Why they like it, in their words or paraphrased. */
  why?: string
  /** One coaching cue. */
  cue?: string
}

export interface Athlete {
  id: string
  slug: string
  name: string
  country?: string
  division: Division
  photoUrl?: string
  bio?: string
  stats?: { heightCm?: number; competitionWeightKg?: number; born?: string; proSince?: number }
  bestResult?: string
  favoriteExercises: FavoriteExercise[]
  videos: Video[]
  links?: { instagram?: string; youtube?: string; website?: string }
  /** URLs backing the facts above. */
  sources?: string[]
}

export interface RankingEntry { rank: number; athleteId: string; note?: string }

export interface Ranking {
  id: string
  /** e.g. "2026 Mr. Olympia: top 10 candidates" */
  title: string
  year: number
  division: Division
  updatedAt: string // ISO date
  source?: string
  entries: RankingEntry[]
}

export interface NewsItem {
  id: string
  title: string
  summary?: string
  url: string
  source: string
  publishedAt: string // ISO date
  tags?: string[]
  athleteIds?: string[]
}

export interface NewsBundle {
  /** Bump when the shape changes; the loader rejects newer versions. */
  version: 1
  generatedAt: string
  rankings: Ranking[]
  athletes: Athlete[]
  news: NewsItem[]
}
