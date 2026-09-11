import { SceneFrame } from './SceneFrame.jsx'

/** Flat-topped dry-zone tree, the shape that reads instantly as savanna. */
function Acacia({ x, y, scale = 1, color }) {
  return (
    <g transform={`translate(${x} ${y}) scale(${scale})`} fill={color}>
      <path d="M-4 0 L-7 -62 L-22 -84 h10 L-2 -66 L4 -66 L14 -86 h10 L7 -62 L4 0 Z" />
      <path d="M-74 -88 C -46 -108, 46 -108, 74 -88 C 40 -80, -40 -80, -74 -88 Z" />
      <path d="M-52 -100 C -28 -116, 28 -116, 52 -100 C 24 -94, -24 -94, -52 -100 Z" opacity="0.85" />
    </g>
  )
}

/** Yala at dusk: heat-hazed scrub, a granite outcrop and a drinking waterhole. */
export function WildlifeScene({ palette }) {
  return (
    <SceneFrame palette={palette} sunX={1160} sunY={300} sunR={140}>
      {/* Birds heading in */}
      <g stroke={palette.near} strokeWidth="2.5" fill="none" opacity="0.45">
        {[
          [280, 200],
          [330, 176],
          [386, 208],
        ].map(([x, y]) => (
          <path key={`${x}-${y}`} d={`M${x} ${y} q 11 -9 22 0 M${x + 22} ${y} q 11 -9 22 0`} />
        ))}
      </g>

      <g className="scene__far">
        <path
          d="M0 566 C 200 542, 420 556, 640 548 S 1080 528, 1440 552 L1440 900 L0 900 Z"
          fill={palette.far}
          opacity="0.5"
        />
        {/* Granite outcrop */}
        <path d="M980 552 C 1016 500, 1078 494, 1120 540 L1146 566 L964 566 Z" fill={palette.far} opacity="0.85" />
      </g>

      <g className="scene__mid">
        <path d="M0 646 C 280 624, 700 664, 1440 630 L1440 900 L0 900 Z" fill={palette.mid} opacity="0.7" />
        <Acacia x={214} y={648} scale={1.05} color={palette.near} />
        <Acacia x={1298} y={640} scale={0.78} color={palette.near} />
      </g>

      <g className="scene__near">
        <path d="M0 716 C 320 694, 880 736, 1440 702 L1440 900 L0 900 Z" fill={palette.near} />

        {/* Waterhole catching the last light */}
        <ellipse cx="640" cy="790" rx="250" ry="28" fill={palette.haze} opacity="0.32" />
        <ellipse cx="640" cy="790" rx="176" ry="16" fill={palette.sun} opacity="0.18" />

        {/* Grass tufts along the near edge */}
        <g stroke={palette.near} strokeWidth="3" fill="none" opacity="0.95">
          {Array.from({ length: 26 }, (_, i) => 20 + i * 56).map((x, i) => (
            <path key={x} d={`M${x} 900 C ${x - 8} ${856 - (i % 3) * 10}, ${x + 6} ${844}, ${x + 12} ${822}`} />
          ))}
        </g>

        <Acacia x={126} y={764} scale={1.35} color={palette.near} />
      </g>
    </SceneFrame>
  )
}
