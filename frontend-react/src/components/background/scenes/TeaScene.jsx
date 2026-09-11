import { SceneFrame } from './SceneFrame.jsx'

/** Contour lines that read as picked tea rows following the hillside. */
function Contours({ baseY, color }) {
  return (
    <g stroke={color} strokeWidth="2" fill="none" opacity="0.35">
      {[0, 26, 52, 78, 104, 130, 156].map((offset) => (
        <path
          key={offset}
          d={`M-40 ${baseY + offset} C 260 ${baseY + offset - 46}, 560 ${baseY + offset + 34}, 860 ${
            baseY + offset - 22
          } S 1280 ${baseY + offset + 40}, 1480 ${baseY + offset - 10}`}
        />
      ))}
    </g>
  )
}

/** Tea country: terraced slopes stepping down to a misted valley floor. */
export function TeaScene({ palette }) {
  return (
    <SceneFrame palette={palette} sunX={340} sunY={200} sunR={100}>
      <g className="scene__far">
        <path
          d="M0 486 C 220 420, 420 470, 620 442 S 1040 400, 1240 452 L1440 430 L1440 900 L0 900 Z"
          fill={palette.far}
          opacity="0.5"
        />
      </g>

      <g className="scene__mid">
        <path
          d="M0 566 C 240 500, 480 560, 720 528 S 1180 486, 1440 540 L1440 900 L0 900 Z"
          fill={palette.mid}
          opacity="0.9"
        />
        <Contours baseY={580} color={palette.near} />
      </g>

      <g className="scene__near">
        <path
          d="M0 702 C 260 648, 520 706, 780 674 S 1220 632, 1440 690 L1440 900 L0 900 Z"
          fill={palette.near}
        />
        <Contours baseY={716} color={palette.haze} />

        {/* Estate bungalow roofline on the near ridge */}
        <g fill={palette.haze} opacity="0.75">
          <path d="M1108 676 l38 -26 38 26 z" />
          <rect x="1122" y="676" width="48" height="22" />
        </g>

        {/* Pluckers working the row */}
        <g fill={palette.accent} opacity="0.85">
          <circle cx="392" cy="690" r="6" />
          <circle cx="446" cy="700" r="6" />
          <circle cx="512" cy="694" r="6" />
        </g>
      </g>
    </SceneFrame>
  )
}
