# Pose 3D (DRAFT, flag `pose3d`, off by default)

## Purpose

Show the **start and end position of an exercise** on the exercise card and let
them animate between each other, so a glance tells you the movement. The owner's
idea: two 3D images per exercise that cycle, becoming an animation.

## Approaches, cheapest first

| # | Approach | Cost | Where it lands |
|---|---|---|---|
| 1 | **Two rendered stills** (WebP/PNG/SVG) of a 3D figure at start and end, cross-faded with CSS. | No new dependency. ~20-60 KB per exercise. | `PoseCycler.tsx`, **working now** with the sample SVGs. |
| 2 | **Sprite strip**: 8-16 rendered frames per exercise, stepped with CSS `steps()`. Smooth, still no runtime 3D. | ~150-400 KB per exercise. | Same component with `frames: string[]` instead of two images; a small extension. |
| 3 | **Real 3D**: one glTF figure + per-exercise animation clips, interpolated at runtime with three.js. User can orbit. | `three` + `@react-three/fiber` add ~600 KB (gz ~150 KB), more than the whole app today. Needs a rigged model and an animation pipeline (Blender/Mixamo). | `PoseViewer3D.tsx` is a documented stub; do not add `three` until approach 1 has proven the UX. |

Recommendation: ship approach 1, generate the stills from a single 3D scene so
they look consistent, and only move to 3 if orbiting the figure is really wanted.

## What is real and what is placeholder

| Piece | Status |
|---|---|
| `PoseCycler` | Real. Cross-fades two images on a timer, tap to pause, honours `prefers-reduced-motion`, preloads both frames. |
| `PosePreview` | Real. Looks up a pose for the current version (exact version name, then base exercise name) and renders `PoseCycler`, or nothing. This is the mount point used by ExerciseCard. |
| `data/sample.ts` | **Placeholder art.** Two inline SVG stick figures for a biceps curl, so the feature renders without binary assets. Replace with rendered 3D stills under `public/poses/<slug>-{start,end}.webp`. |
| `PoseViewer3D` | Stub. Documents the props and the pipeline for approach 3. Renders a labelled box. |

## Asset pipeline (approach 1)

1. One Blender scene with a neutral mannequin, fixed camera, fixed light.
2. Per exercise, pose start and end, render 512x512 transparent PNG, convert to
   WebP (`cwebp -q 80`). Keep both frames from the same camera so the cross-fade
   reads as motion.
3. Save to `public/poses/<slug>-start.webp` and `-end.webp`; add an entry to the
   pose index (today `data/sample.ts`; later a JSON file next to the images).
4. Budget: 60 KB per exercise, so 100 exercises ~ 6 MB, fetched lazily and cached
   by the service worker on first view (not precached).

## Wiring points in the main app

- `src/components/ExerciseCard.tsx`: `{FEATURES.pose3d && <Suspense><PosePreview version={version} /></Suspense>}` under the header. Already in place, lazy, inert when the flag is off.
- When shipping: move the pose index out of `data/sample.ts` into a fetched JSON
  so adding art does not need a rebuild, and precache nothing (images are
  cache-on-first-view in `public/sw.js`).

## Open questions for the owner

- Mannequin style: anatomical, blocky, or silhouette? Silhouette hides the lack
  of detail and matches the planned cable-height silhouette slider.
- Should the figure be mirrored for one-arm versions when on the R side?
- Is tap-to-pause enough, or do you want a scrub slider between start and end?
