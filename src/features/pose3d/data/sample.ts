/**
 * PLACEHOLDER ART. Two inline SVG stick figures (a biceps curl at the bottom and
 * at the top) so the feature can render with zero binary assets. Replace with
 * rendered 3D stills; see README "Asset pipeline".
 */
import type { PoseIndex } from '../types'

const svg = (body: string) => 'data:image/svg+xml;utf8,' + encodeURIComponent(
  `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 120 160" width="120" height="160">
    <g fill="none" stroke="#a7afc2" stroke-width="6" stroke-linecap="round" stroke-linejoin="round">
      <circle cx="60" cy="22" r="12" fill="#a7afc2" stroke="none"/>
      <path d="M60 36 V 92"/>
      <path d="M60 92 L 44 150"/><path d="M60 92 L 76 150"/>
      ${body}
    </g>
  </svg>`,
)

// Arms hanging, bar at thigh level.
const CURL_START = svg(`<path d="M60 46 L 40 90"/><path d="M60 46 L 80 90"/><path d="M34 90 H 86" stroke="#5dd68c"/>`)
// Elbows pinned, forearms up, bar at the chest.
const CURL_END = svg(`<path d="M60 46 L 44 74 L 44 50"/><path d="M60 46 L 76 74 L 76 50"/><path d="M38 50 H 82" stroke="#5dd68c"/>`)

export const SAMPLE_POSES: PoseIndex = {
  version: 1,
  poses: [
    { id: 'curl', exerciseName: 'Barbell Curl', start: { src: CURL_START, alt: 'arms down' }, end: { src: CURL_END, alt: 'bar at chest' }, periodMs: 2400, credit: 'placeholder' },
    { id: 'curl-standing', versionName: 'Standing Barbell Curl', start: { src: CURL_START }, end: { src: CURL_END }, periodMs: 2400, credit: 'placeholder' },
  ],
}
