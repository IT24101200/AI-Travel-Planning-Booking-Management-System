/** Category glyph for an experience card (`icon` key in data/experiences.js). */
export function ExperienceIcon({ name, size = 20 }) {
  const common = {
    width: size,
    height: size,
    viewBox: '0 0 24 24',
    fill: 'none',
    stroke: 'currentColor',
    strokeWidth: 1.7,
    strokeLinecap: 'round',
    strokeLinejoin: 'round',
    'aria-hidden': true,
    focusable: 'false',
  }

  switch (name) {
    case 'train':
      return (
        <svg {...common}>
          <rect x="5" y="3.5" width="14" height="13" rx="3" />
          <path d="M5 10.5h14M9 20l-1.5 1.5M15 20l1.5 1.5M8 16.5v2h8v-2" />
          <circle cx="9" cy="13.5" r="0.9" fill="currentColor" stroke="none" />
          <circle cx="15" cy="13.5" r="0.9" fill="currentColor" stroke="none" />
        </svg>
      )
    case 'paw':
      return (
        <svg {...common}>
          <ellipse cx="12" cy="16" rx="4.2" ry="3.4" />
          <circle cx="6.6" cy="11.6" r="1.9" />
          <circle cx="10" cy="8.2" r="1.9" />
          <circle cx="14" cy="8.2" r="1.9" />
          <circle cx="17.4" cy="11.6" r="1.9" />
        </svg>
      )
    case 'wave':
      return (
        <svg {...common}>
          <path d="M2.5 9c2.4-2.6 4.8-2.6 7.2 0s4.8 2.6 7.2 0 3.2-2 4.6-1" />
          <path d="M2.5 14c2.4-2.6 4.8-2.6 7.2 0s4.8 2.6 7.2 0 3.2-2 4.6-1" />
          <path d="M2.5 19c2.4-2.6 4.8-2.6 7.2 0" />
        </svg>
      )
    case 'temple':
      return (
        <svg {...common}>
          <path d="M12 2.5 14 7h-4l2-4.5Z" />
          <path d="M10.5 7h3v3h-3z" />
          <path d="M6.5 13a5.5 5.5 0 0 1 11 0" />
          <path d="M4.5 13h15v3h-15zM6 16v5M18 16v5M3.5 21h17" />
        </svg>
      )
    case 'bowl':
      return (
        <svg {...common}>
          <path d="M3 11h18a9 9 0 0 1-18 0Z" />
          <path d="M2 21h20" />
          <path d="M9 7.5c0-1.6 3-1.9 3-4M14 8c0-1.2 1.8-1.6 1.8-3" />
        </svg>
      )
    case 'leaf':
    default:
      return (
        <svg {...common}>
          <path d="M4 20c0-8 5-14 16-15 0 11-6 16-13 16H4Z" />
          <path d="M4 20c4-5 7-7 11-8.5" />
        </svg>
      )
  }
}
