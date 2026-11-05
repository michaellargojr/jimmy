/** One still image of the figure. `src` may be a URL or a data: URI. */
export interface PoseFrame { src: string; alt?: string }

export interface ExercisePose {
  id: string
  /** Match by exact Version.name first... */
  versionName?: string
  /** ...then by base Exercise.name. */
  exerciseName?: string
  start: PoseFrame
  end: PoseFrame
  /** Full start -> end -> start cycle, ms. */
  periodMs?: number
  /** Approach 3 only: a glTF with two named animation clips to blend between. */
  model?: { url: string; startClip: string; endClip: string }
  credit?: string
}

/** Lookup table a data source must produce (today: data/sample.ts). */
export interface PoseIndex { version: 1; poses: ExercisePose[] }
