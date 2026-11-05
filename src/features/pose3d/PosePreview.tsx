/**
 * Mount point used by ExerciseCard (lazy, flag-gated). Finds a pose for the
 * version and renders the cheapest available viewer. Renders nothing when there
 * is no art for this exercise, so cards without poses look exactly as before.
 */
import type { Version } from '../../model'
import { useStore } from '../../store'
import { exerciseIndex } from '../../indexes'
import { PoseCycler } from './PoseCycler'
import { PoseViewer3D } from './PoseViewer3D'
import { findPose, usePoseIndex } from './usePose'

export default function PosePreview({ version }: { version: Version }) {
  const exercises = useStore(s => s.exercises)
  const index = usePoseIndex()
  const pose = findPose(index, version, exerciseIndex(exercises).byId.get(version.exerciseId))
  if (!pose) return null
  if (pose.model) return <PoseViewer3D pose={pose} />
  return <PoseCycler start={pose.start} end={pose.end} periodMs={pose.periodMs} label={version.name} />
}
