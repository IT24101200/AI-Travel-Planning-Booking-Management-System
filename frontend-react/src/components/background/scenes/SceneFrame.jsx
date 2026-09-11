import { useId } from 'react'

/**
 * Shared shell for every procedural landscape: sky wash, atmospheric haze and
 * a sun/moon glow, with the scene's own layers passed in as children.
 *
 * Gradient ids are made unique per mount so several scenes can be stacked
 * (hero backdrop + card thumbnails) without their <defs> colliding.
 */
export function SceneFrame({ palette, children, sunX = 1075, sunY = 215, sunR = 120 }) {
  const uid = useId().replace(/[^a-zA-Z0-9_-]/g, '')
  const sky = `sky-${uid}`
  const glow = `glow-${uid}`
  const mist = `mist-${uid}`

  return (
    <svg
      viewBox="0 0 1440 900"
      preserveAspectRatio="xMidYMid slice"
      aria-hidden="true"
      focusable="false"
    >
      <defs>
        <linearGradient id={sky} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor={palette.skyTop} />
          <stop offset="58%" stopColor={palette.haze} />
          <stop offset="100%" stopColor={palette.skyBottom} />
        </linearGradient>
        <radialGradient id={glow} cx="50%" cy="50%" r="50%">
          <stop offset="0%" stopColor={palette.sun} stopOpacity="0.9" />
          <stop offset="42%" stopColor={palette.sun} stopOpacity="0.3" />
          <stop offset="100%" stopColor={palette.sun} stopOpacity="0" />
        </radialGradient>
        <linearGradient id={mist} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor={palette.haze} stopOpacity="0" />
          <stop offset="100%" stopColor={palette.haze} stopOpacity="0.55" />
        </linearGradient>
      </defs>

      <rect width="1440" height="900" fill={`url(#${sky})`} />
      <circle cx={sunX} cy={sunY} r={sunR * 2.3} fill={`url(#${glow})`} />
      <circle cx={sunX} cy={sunY} r={sunR * 0.32} fill={palette.sun} opacity="0.92" />

      {children}

      {/* Ground-level haze that ties the layers together. */}
      <rect y="560" width="1440" height="200" fill={`url(#${mist})`} opacity="0.5" />
    </svg>
  )
}
