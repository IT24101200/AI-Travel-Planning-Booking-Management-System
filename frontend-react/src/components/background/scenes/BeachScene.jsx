import { SceneFrame } from './SceneFrame.jsx'

/** A leaning coconut palm, silhouetted. `flip` mirrors the lean. */
function Palm({ x, y, scale = 1, color, flip = false }) {
  const dir = flip ? -1 : 1
  return (
    <g transform={`translate(${x} ${y}) scale(${dir * scale} ${scale})`} fill={color}>
      <path d="M0 0 C 6 -60, 14 -120, 34 -172 l10 5 C 28 -118, 18 -58, 12 0 Z" />
      {[-1.05, -0.55, 0, 0.55, 1.05].map((a, i) => (
        <path
          key={i}
          transform={`translate(40 -174) rotate(${a * 42 - 18})`}
          d="M0 0 C 30 -20, 66 -24, 96 -12 C 66 -2, 32 6, 0 6 Z"
        />
      ))}
      <circle cx="34" cy="-166" r="6" />
      <circle cx="46" cy="-160" r="5" />
    </g>
  )
}

/** Tropical coast: ocean bands, a sun path on the water, palms on the sand. */
export function BeachScene({ palette }) {
  return (
    <SceneFrame palette={palette} sunX={880} sunY={250} sunR={110}>
      {/* Headland */}
      <g className="scene__far">
        <path
          d="M0 520 C 90 470, 210 462, 300 508 L340 528 L0 528 Z"
          fill={palette.far}
          opacity="0.7"
        />
        <path d="M1180 522 C 1250 480, 1350 480, 1440 516 L1440 534 L1180 534 Z" fill={palette.far} opacity="0.6" />
      </g>

      {/* Ocean */}
      <g className="scene__mid">
        <rect y="528" width="1440" height="212" fill={palette.mid} />
        <rect y="528" width="1440" height="212" fill={palette.near} opacity="0.2" />
        {[548, 572, 598, 626, 656, 690, 726].map((y, i) => (
          <path
            key={y}
            d={`M-20 ${y} q 120 ${i % 2 ? -8 : 8} 240 0 t 240 0 t 240 0 t 240 0 t 240 0 t 240 0`}
            stroke={palette.haze}
            strokeWidth={1 + i * 0.3}
            fill="none"
            opacity={0.16 + i * 0.05}
          />
        ))}
        {/* Sun path on the water */}
        <path d="M844 528 L916 528 L980 740 L780 740 Z" fill={palette.sun} opacity="0.16" />
      </g>

      {/* Sand + palms */}
      <g className="scene__near">
        <path d="M0 740 C 300 716, 900 764, 1440 728 L1440 900 L0 900 Z" fill={palette.skyBottom} opacity="0.55" />
        <path d="M0 772 C 320 752, 940 796, 1440 762 L1440 900 L0 900 Z" fill={palette.near} />
        <Palm x={168} y={786} scale={1.15} color={palette.near} />
        <Palm x={330} y={800} scale={0.82} color={palette.near} flip />
        <Palm x={1276} y={790} scale={1.05} color={palette.near} flip />
      </g>
    </SceneFrame>
  )
}
