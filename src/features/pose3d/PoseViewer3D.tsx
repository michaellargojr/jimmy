/**
 * STUB for approach 3 in the README (real-time 3D). Intentionally imports no 3D
 * library: `three` + `@react-three/fiber` would roughly double the app's bundle,
 * so the decision to add them must be explicit.
 *
 * Plan when the time comes:
 *  1. `pnpm add three @react-three/fiber @react-three/drei` and lazy-load this
 *     component only (it already sits behind React.lazy via PosePreview).
 *  2. One rigged mannequin exported from Blender as glTF (Draco-compressed, ~1 MB).
 *     Each exercise = two animation clips (or two poses) named in `model`.
 *  3. Render with <Canvas>, load with useGLTF, drive a mixer where
 *     weight(startClip) = 1 - t and weight(endClip) = t, with t oscillating on
 *     the same period PoseCycler uses. OrbitControls limited to yaw so the figure
 *     stays upright.
 *  4. Keep PoseCycler as the fallback when `pose.model` is absent or WebGL is
 *     unavailable.
 */
import type { ExercisePose } from './types'
import './pose3d.css'

export function PoseViewer3D({ pose }: { pose: ExercisePose }) {
  return (
    <div className="pose pose-stub" role="img" aria-label="3D viewer not implemented">
      <span className="small faint" style={{ padding: 12, textAlign: 'center' }}>
        3D viewer stub{pose.model ? ` for ${pose.model.url}` : ''}.<br />See src/features/pose3d/README.md.
      </span>
    </div>
  )
}
