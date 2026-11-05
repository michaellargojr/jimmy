/**
 * PLACEHOLDER DATA. Every athlete below is invented ("Sample Athlete N").
 * Exercise names are generic library movements. There are no videos.
 *
 * Purpose: let the UI render and be designed against a realistic shape. Replace
 * with a maintained bundle (see README "Data source plan") before enabling the
 * feature for real. Do not add real athletes here without `sources`.
 */
import type { Athlete, NewsBundle, Ranking } from '../types'

const FAVES: Array<Array<{ name: string; muscle: Athlete['favoriteExercises'][number]['muscle']; cue: string }>> = [
  [{ name: 'Incline Bench Press', muscle: 'Chest', cue: 'Elbows under the bar, pause at the chest.' }, { name: 'Lat Pulldown', muscle: 'Back', cue: 'Drive the elbows down and back.' }],
  [{ name: 'Hack Squat', muscle: 'Legs', cue: 'Heels down, knees track over toes.' }, { name: 'Romanian Deadlift', muscle: 'Legs', cue: 'Hips back, bar glides along the thigh.' }],
  [{ name: 'Seated Cable Row', muscle: 'Back', cue: 'Chest tall, squeeze at the back.' }, { name: 'Lateral Raise', muscle: 'Shoulders', cue: 'Lead with the elbows.' }],
  [{ name: 'Pec Deck', muscle: 'Chest', cue: 'Slow stretch, hard squeeze.' }, { name: 'Leg Press', muscle: 'Legs', cue: 'Do not lock out.' }],
  [{ name: 'Chest-Supported Row', muscle: 'Back', cue: 'Pull to the hips, not the chest.' }, { name: 'Skull Crusher', muscle: 'Triceps', cue: 'Elbows fixed, full stretch overhead.' }],
  [{ name: 'Overhead Press', muscle: 'Shoulders', cue: 'Brace, bar path straight up.' }, { name: 'Hammer Curl', muscle: 'Biceps', cue: 'No swing, control the way down.' }],
  [{ name: 'Leg Extension', muscle: 'Legs', cue: 'Pause at the top for a second.' }, { name: 'Seated Calf Raise', muscle: 'Calves', cue: 'Full stretch at the bottom.' }],
  [{ name: 'Dumbbell Row', muscle: 'Back', cue: 'Row to the hip pocket.' }, { name: 'Cable Fly', muscle: 'Chest', cue: 'Hands meet in front, hold.' }],
  [{ name: 'Front Squat', muscle: 'Legs', cue: 'Elbows high, sit between the heels.' }, { name: 'Face Pull', muscle: 'Shoulders', cue: 'Pull to the forehead, rotate out.' }],
  [{ name: 'Hip Thrust', muscle: 'Glutes', cue: 'Chin tucked, squeeze at lockout.' }, { name: 'Rope Pushdown', muscle: 'Triceps', cue: 'Spread the rope at the bottom.' }],
]

const athletes: Athlete[] = Array.from({ length: 10 }, (_, i) => {
  const n = i + 1
  return {
    id: `sample-${n}`,
    slug: `sample-athlete-${n}`,
    name: `Sample Athlete ${n}`,
    division: 'Open',
    bio: 'Placeholder profile. Replace with a sourced biography.',
    stats: { heightCm: 170 + n, competitionWeightKg: 100 + n * 2 },
    bestResult: `Placeholder: finished ${n}th at a sample show`,
    favoriteExercises: FAVES[i].map((f, j) => ({ id: `sample-${n}-fav-${j}`, name: f.name, libraryName: f.name, muscle: f.muscle, cue: f.cue, why: 'Placeholder reason.' })),
    videos: [],
    sources: [],
  }
})

const ranking: Ranking = {
  id: 'sample-olympia-top10',
  title: 'Sample ranking: top 10 candidates (placeholder)',
  year: new Date().getFullYear(),
  division: 'Open',
  updatedAt: '2026-01-01',
  entries: athletes.map((a, i) => ({ rank: i + 1, athleteId: a.id })),
}

export const SAMPLE_BUNDLE: NewsBundle = {
  version: 1,
  generatedAt: '2026-01-01T00:00:00Z',
  rankings: [ranking],
  athletes,
  news: [
    { id: 'sample-news-1', title: 'Placeholder headline: this is where bodybuilding news will appear', summary: 'The real feed will be produced by a scheduled job. See src/features/news/README.md.', url: 'https://example.com', source: 'placeholder', publishedAt: '2026-01-01' },
  ],
}
