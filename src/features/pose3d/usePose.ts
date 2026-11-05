import type { Exercise, Version } from '../../model'
import type { ExercisePose, PoseIndex } from './types'
import { SAMPLE_POSES } from './data/sample'

/** Exact version name wins over base exercise name. Pure, so it is trivially testable. */
export function findPose(index: PoseIndex, version: Version, exercise?: Exercise): ExercisePose | undefined {
  return index.poses.find(p => p.versionName === version.name)
    ?? (exercise ? index.poses.find(p => p.exerciseName === exercise.name) : undefined)
}

/** Today the index is bundled. Later: fetch `/poses/index.json` with the same cache pattern as news/api.ts. */
export function usePoseIndex(): PoseIndex {
  return SAMPLE_POSES
}
