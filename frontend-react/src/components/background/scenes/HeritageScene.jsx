import { SceneFrame } from './SceneFrame.jsx'

/** A dagoba (stupa) silhouette: hemispherical dome, drum and spire. */
function Stupa({ x, y, scale = 1, color }) {
  return (
    <g transform={`translate(${x} ${y}) scale(${scale})`} fill={color}>
      <rect x="-64" y="-16" width="128" height="16" rx="3" />
      <rect x="-52" y="-30" width="104" height="16" rx="3" />
      <path d="M-46 -28 A 46 46 0 0 1 46 -28 Z" />
      <rect x="-13" y="-104" width="26" height="30" rx="2" />
      <path d="M0 -156 L9 -104 h-18 Z" />
    </g>
  )
}

/**
 * Cultural triangle: a granite monolith with the ruined stairway (Sigiriya)
 * and a dagoba on the lake terrace (Kandy).
 */
export function HeritageScene({ palette }) {
  return (
    <SceneFrame palette={palette} sunX={300} sunY={230} sunR={128}>
      <g className="scene__far">
        <path
          d="M0 552 C 180 512, 340 528, 500 546 S 900 512, 1100 542 L1440 520 L1440 900 L0 900 Z"
          fill={palette.far}
          opacity="0.5"
        />
      </g>

      {/* The rock */}
      <g className="scene__mid">
        <path
          d="M742 604 L760 470 C 768 424, 806 396, 856 394 C 912 392, 952 420, 962 468 L986 604 Z"
          fill={palette.mid}
        />
        <path
          d="M856 394 C 906 394, 946 420, 958 466 L972 540 L900 540 L880 396 Z"
          fill={palette.near}
          opacity="0.35"
        />
        {/* Stairway cut into the west face */}
        <path d="M778 592 L800 486" stroke={palette.haze} strokeWidth="3" opacity="0.5" fill="none" />
        {[500, 520, 540, 560, 580].map((y, i) => (
          <rect key={y} x={782 - i * 2} y={y} width="16" height="3" fill={palette.haze} opacity="0.45" />
        ))}
      </g>

      {/* Terraces, water garden, dagoba */}
      <g className="scene__near">
        <path d="M0 640 C 300 618, 780 660, 1440 622 L1440 900 L0 900 Z" fill={palette.mid} opacity="0.75" />
        <Stupa x={380} y={648} scale={0.9} color={palette.near} />
        <path d="M0 704 C 340 682, 900 724, 1440 690 L1440 900 L0 900 Z" fill={palette.near} />

        {/* Reflecting pool */}
        <ellipse cx="720" cy="768" rx="290" ry="30" fill={palette.haze} opacity="0.3" />
        <ellipse cx="720" cy="768" rx="230" ry="20" fill={palette.sun} opacity="0.14" />

        {/* Canopy edge */}
        {[40, 150, 262, 1060, 1180, 1300, 1408].map((x, i) => (
          <g key={x} fill={palette.near}>
            <ellipse cx={x} cy={694 - (i % 2) * 12} rx={54} ry={30} />
            <rect x={x - 4} y={694} width="8" height="52" />
          </g>
        ))}
      </g>
    </SceneFrame>
  )
}
