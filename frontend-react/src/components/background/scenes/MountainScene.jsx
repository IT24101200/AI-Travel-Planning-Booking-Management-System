import { SceneFrame } from './SceneFrame.jsx'

/**
 * Hill-country escarpment: layered ridges fading into cloud, used for Ella
 * and Horton Plains. The three <g> layers carry the parallax classes.
 */
export function MountainScene({ palette }) {
  return (
    <SceneFrame palette={palette} sunX={1120} sunY={190}>
      {/* Far ridge line */}
      <g className="scene__far">
        <path
          d="M0 520 L120 452 L210 486 L318 402 L432 470 L540 418 L648 478 L764 424 L880 486 L1000 440 L1116 498 L1232 452 L1340 500 L1440 466 L1440 900 L0 900 Z"
          fill={palette.far}
          opacity="0.55"
        />
      </g>

      {/* Cloud shelf caught on the ridge */}
      <g opacity="0.42">
        <ellipse cx="360" cy="540" rx="330" ry="34" fill={palette.haze} />
        <ellipse cx="980" cy="558" rx="380" ry="30" fill={palette.haze} />
        <ellipse cx="660" cy="586" rx="460" ry="26" fill={palette.haze} opacity="0.7" />
      </g>

      {/* Mid ridge */}
      <g className="scene__mid">
        <path
          d="M0 606 L150 548 L268 592 L392 512 L520 578 L654 526 L790 596 L930 540 L1064 600 L1200 548 L1330 604 L1440 566 L1440 900 L0 900 Z"
          fill={palette.mid}
          opacity="0.82"
        />
      </g>

      {/* Near ridge + treeline */}
      <g className="scene__near">
        <path
          d="M0 704 L130 662 L262 700 L400 648 L544 698 L690 654 L840 706 L986 660 L1130 708 L1274 666 L1440 712 L1440 900 L0 900 Z"
          fill={palette.near}
        />
        {[80, 220, 355, 500, 645, 790, 935, 1080, 1225, 1370].map((x, i) => (
          <path
            key={x}
            d={`M${x} ${712 + (i % 3) * 8} l-15 46 h30 z`}
            fill={palette.near}
            opacity="0.9"
          />
        ))}
        <rect y="760" width="1440" height="140" fill={palette.near} />
      </g>
    </SceneFrame>
  )
}
