/** Line icons, 24x24 grid, inheriting `currentColor`. */

function Svg({ children, size = 20, fill = 'none', ...rest }) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill={fill}
      stroke="currentColor"
      strokeWidth="1.7"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
      focusable="false"
      {...rest}
    >
      {children}
    </svg>
  )
}

export function LeafIcon(props) {
  return (
    <Svg {...props}>
      <path d="M4 20c0-8 5-14 16-15 0 11-6 16-13 16H4Z" />
      <path d="M4 20c4-5 7-7 11-8.5" />
    </Svg>
  )
}

export function ArrowRightIcon(props) {
  return (
    <Svg size={16} {...props}>
      <path d="M4 12h15" />
      <path d="m13 6 6 6-6 6" />
    </Svg>
  )
}

export function CheckIcon(props) {
  return (
    <Svg size={16} {...props}>
      <path d="m4 12.5 5 5L20 6.5" />
    </Svg>
  )
}

export function StarIcon(props) {
  return (
    <Svg size={15} fill="currentColor" stroke="none" {...props}>
      <path d="m12 2.6 2.9 5.9 6.5.9-4.7 4.6 1.1 6.5-5.8-3-5.8 3 1.1-6.5L2.6 9.4l6.5-.9L12 2.6Z" />
    </Svg>
  )
}

export function MapPinIcon(props) {
  return (
    <Svg size={16} {...props}>
      <path d="M12 21s7-5.6 7-11a7 7 0 1 0-14 0c0 5.4 7 11 7 11Z" />
      <circle cx="12" cy="10" r="2.6" />
    </Svg>
  )
}

export function ClockIcon(props) {
  return (
    <Svg size={16} {...props}>
      <circle cx="12" cy="12" r="8.5" />
      <path d="M12 7.5V12l3.2 2" />
    </Svg>
  )
}

export function CalendarIcon(props) {
  return (
    <Svg size={16} {...props}>
      <rect x="3.5" y="5" width="17" height="15.5" rx="2.5" />
      <path d="M3.5 10h17M8.5 3.5V7M15.5 3.5V7" />
    </Svg>
  )
}

export function SparkleIcon(props) {
  return (
    <Svg {...props}>
      <path d="M12 3.2l1.9 4.9 4.9 1.9-4.9 1.9L12 16.8l-1.9-4.9L5.2 10l4.9-1.9L12 3.2Z" />
      <path d="M18.5 15.5l.8 2 2 .8-2 .8-.8 2-.8-2-2-.8 2-.8.8-2Z" />
    </Svg>
  )
}

export function CompassIcon(props) {
  return (
    <Svg {...props}>
      <circle cx="12" cy="12" r="9" />
      <path d="m15.5 8.5-2 5-5 2 2-5 5-2Z" />
    </Svg>
  )
}

export function UsersIcon(props) {
  return (
    <Svg size={16} {...props}>
      <circle cx="9.5" cy="8.5" r="3.2" />
      <path d="M3.5 20c0-3.3 2.7-5.5 6-5.5s6 2.2 6 5.5" />
      <path d="M16 5.6a3.2 3.2 0 0 1 0 6.1M17.5 14.9c1.9.6 3 2.4 3 5.1" />
    </Svg>
  )
}

export function PhoneIcon(props) {
  return (
    <Svg size={16} {...props}>
      <path d="M5 3.8h3.3l1.6 4-2 1.4a10.6 10.6 0 0 0 5.9 5.9l1.4-2 4 1.6V18a2.2 2.2 0 0 1-2.4 2.2A16.5 16.5 0 0 1 2.8 6.2 2.2 2.2 0 0 1 5 3.8Z" />
    </Svg>
  )
}

export function MailIcon(props) {
  return (
    <Svg size={16} {...props}>
      <rect x="2.8" y="5" width="18.4" height="14" rx="2.5" />
      <path d="m3.5 7 8.5 6 8.5-6" />
    </Svg>
  )
}

export function SlidersIcon(props) {
  return (
    <Svg size={16} {...props}>
      <line x1="4" x2="20" y1="21" y2="14" />
      <line x1="4" x2="20" y1="10" y2="3" />
      <line x1="12" x2="12" y1="21" y2="12" />
      <line x1="12" x2="12" y1="8" y2="3" />
    </Svg>
  )
}

export function SparklesIcon(props) {
  return (
    <Svg size={16} {...props}>
      <path d="m12 3-1.912 5.813a2 2 0 0 1-1.275 1.275L3 12l5.813 1.912a2 2 0 0 1 1.275 1.275L12 21l1.912-5.813a2 2 0 0 1 1.275-1.275L21 12l-5.813-1.912a2 2 0 0 1-1.275-1.275L12 3Z"/>
      <path d="M5 3v4M3 5h4"/>
    </Svg>
  )
}

export function RotateCcwIcon(props) {
  return (
    <Svg size={16} {...props}>
      <path d="M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8"/>
      <path d="M3 3v5h5"/>
    </Svg>
  )
}

export function CarIcon(props) {
  return (
    <Svg size={16} {...props}>
      <path d="M19 17h2c.6 0 1-.4 1-1v-3c0-.9-.7-1.7-1.5-1.9C18.7 10.6 16 10 16 10s-1.3-1.4-2.2-2.3c-.5-.4-1.1-.7-1.8-.7H5c-.6 0-1.1.4-1.4.9l-1.4 2.9A3.7 3.7 0 0 0 2 12v4c0 .6.4 1 1 1h2"/>
      <circle cx="7" cy="17" r="2"/>
      <path d="M9 17h6"/>
      <circle cx="17" cy="17" r="2"/>
    </Svg>
  )
}

export function TrainIcon(props) {
  return (
    <Svg size={16} {...props}>
      <rect x="4" y="3" width="16" height="16" rx="2"/>
      <path d="M4 11h16"/>
      <path d="M12 3v8"/>
      <path d="m8 19-2 3"/>
      <path d="m16 19 2 3"/>
      <path d="M2 14h20"/>
    </Svg>
  )
}

export function BusFrontIcon(props) {
  return (
    <Svg size={16} {...props}>
      <path d="M4 6 2 7"/>
      <path d="M10 6h4"/>
      <path d="m22 7-2-1"/>
      <rect x="4" y="3" width="16" height="18" rx="2"/>
      <path d="M4 11h16"/>
      <path d="M8 15h.01"/>
      <path d="M16 15h.01"/>
      <path d="M6 19v2"/>
      <path d="M18 19v2"/>
    </Svg>
  )
}

export function PlaneIcon(props) {
  return (
    <Svg size={16} {...props}>
      <path d="M17.8 19.2 16 11l3.5-3.5C21 6 21.5 4 21 3c-1-.5-3 0-4.5 1.5L13 8 4.8 6.2c-.5-.1-.9.2-1.1.6l-1 2.3 8.3 3.5-3.3 3.3-3.6-.9c-.4-.1-.8.1-1 .5l-1 1.2 5 1.5 1.5 5 1.2-1c.4-.2.6-.6.5-1l-.9-3.6 3.3-3.3 3.5 8.3 2.3-1c.4-.2.7-.6.6-1.1Z"/>
    </Svg>
  )
}


export function SearchIcon(props) {
  return (
    <Svg size={16} {...props}>
      <circle cx="11" cy="11" r="8"/>
      <path d="m21 21-4.3-4.3"/>
    </Svg>
  )
}

export function PlusIcon(props) {
  return (
    <Svg size={16} {...props}>
      <path d="M5 12h14"/>
      <path d="M12 5v14"/>
    </Svg>
  )
}

export function RefreshIcon(props) {
  return (
    <Svg size={16} {...props}>
      <path d="M21 2v6h-6"/>
      <path d="M3 12a9 9 0 1 0 2.1-5.7L9 8"/>
    </Svg>
  )
}

export function EditIcon(props) {
  return (
    <Svg size={16} {...props}>
      <path d="M12 20h9"/>
      <path d="M16.5 3.5a2.121 2.121 0 0 1 3 3L7 19l-4 1 1-4L16.5 3.5z"/>
    </Svg>
  )
}

export function TrashIcon(props) {
  return (
    <Svg size={16} {...props}>
      <path d="M3 6h18"/>
      <path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/>
    </Svg>
  )
}

export function CloseIcon(props) {
  return (
    <Svg size={16} {...props}>
      <path d="M18 6 6 18"/>
      <path d="m6 6 12 12"/>
    </Svg>
  )
}

export function ImageIcon(props) {
  return (
    <Svg size={16} {...props}>
      <rect width="18" height="18" x="3" y="3" rx="2" ry="2"/>
      <circle cx="9" cy="9" r="2"/>
      <path d="m21 15-3.086-3.086a2 2 0 0 0-2.828 0L6 21"/>
    </Svg>
  )
}

export function UploadIcon(props) {
  return (
    <Svg size={16} {...props}>
      <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/>
      <polyline points="17 8 12 3 7 8"/>
      <line x1="12" y1="3" x2="12" y2="15"/>
    </Svg>
  )
}
