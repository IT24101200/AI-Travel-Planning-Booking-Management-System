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

export function MountainSnowIcon(props) {
  return (
    <Svg size={20} {...props}>
      <path d="m8 3 4 8 5-5 5 15H2L8 3z" />
      <path d="M4.14 15h4.86l2-2 3.5 3.5 2.5-2.5h3.9" />
    </Svg>
  )
}

export function ClipboardCheckIcon(props) {
  return (
    <Svg size={18} {...props}>
      <rect width="8" height="4" x="8" y="2" rx="1" ry="1" />
      <path d="M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2" />
      <path d="m9 14 2 2 4-4" />
    </Svg>
  )
}

export function ChartTrendingIcon(props) {
  return (
    <Svg size={18} {...props}>
      <path d="M3 3v18h18" />
      <path d="m19 9-5 5-4-4-3 3" />
    </Svg>
  )
}

export function BellIcon(props) {
  return (
    <Svg size={18} {...props}>
      <path d="M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9" />
      <path d="M10.3 21a1.94 1.94 0 0 0 3.4 0" />
    </Svg>
  )
}

export function MapIcon(props) {
  return (
    <Svg size={18} {...props}>
      <path d="M14.106 5.553a2 2 0 0 0 1.788 0l3.659-1.83A1 1 0 0 1 21 4.619v12.764a1 1 0 0 1-.553.894l-4.553 2.277a2 2 0 0 1-1.788 0l-4.212-2.106a2 2 0 0 0-1.788 0l-3.659 1.83A1 1 0 0 1 3 19.381V6.618a1 1 0 0 1 .553-.894l4.553-2.277a2 2 0 0 1 1.788 0z" />
      <path d="M15 5.764v15M9 3.236v15" />
    </Svg>
  )
}

export function RouteIcon(props) {
  return (
    <Svg size={18} {...props}>
      <circle cx="6" cy="19" r="3" />
      <path d="M9 19h8.5a3.5 3.5 0 0 0 0-7h-11a3.5 3.5 0 0 1 0-7H15" />
      <circle cx="18" cy="5" r="3" />
    </Svg>
  )
}

export function BuildingIcon(props) {
  return (
    <Svg size={18} {...props}>
      <path d="M6 22V4a2 2 0 0 1 2-2h8a2 2 0 0 1 2 2v18Z" />
      <path d="M6 12H4a2 2 0 0 0-2 2v8h20v-8a2 2 0 0 0-2-2h-2" />
      <path d="M10 6h4M10 10h4M10 14h4M10 18h4" />
    </Svg>
  )
}

export function BusFrontIcon(props) {
  return (
    <Svg size={18} {...props}>
      <path d="M4 6 2 7M10 6h4M2 15h20M4 11h16M19 19v2M5 19v2" />
      <rect width="18" height="14" x="3" y="5" rx="2" />
      <circle cx="7.5" cy="15.5" r="1.5" />
      <circle cx="16.5" cy="15.5" r="1.5" />
    </Svg>
  )
}

export function LogOutIcon(props) {
  return (
    <Svg size={16} {...props}>
      <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4" />
      <polyline points="16 17 21 12 16 7" />
      <line x1="21" x2="9" y1="12" y2="12" />
    </Svg>
  )
}

export function DownloadIcon(props) {
  return (
    <Svg size={16} {...props}>
      <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
      <polyline points="7 10 12 15 17 10" />
      <line x1="12" x2="12" y1="15" y2="3" />
    </Svg>
  )
}

export function RefreshIcon(props) {
  return (
    <Svg size={16} {...props}>
      <path d="M3 12a9 9 0 0 1 9-9 9.75 9.75 0 0 1 6.74 2.74L21 8" />
      <path d="M21 3v5h-5" />
      <path d="M21 12a9 9 0 0 1-9 9 9.75 9.75 0 0 1-6.74-2.74L3 16" />
      <path d="M8 16H3v5" />
    </Svg>
  )
}

export function PlusIcon(props) {
  return (
    <Svg size={16} {...props}>
      <path d="M5 12h14M12 5v14" />
    </Svg>
  )
}

export function SearchIcon(props) {
  return (
    <Svg size={16} {...props}>
      <circle cx="11" cy="11" r="8" />
      <path d="m21 21-4.3-4.3" />
    </Svg>
  )
}

export function RotateCcwIcon(props) {
  return (
    <Svg size={16} {...props}>
      <path d="M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8" />
      <path d="M3 3v5h5" />
    </Svg>
  )
}

export function CloseIcon(props) {
  return (
    <Svg size={16} {...props}>
      <path d="M18 6 6 18M6 6l12 12" />
    </Svg>
  )
}

export function EditIcon(props) {
  return (
    <Svg size={16} {...props}>
      <path d="M17 3a2.85 2.83 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5Z" />
      <path d="m15 5 4 4" />
    </Svg>
  )
}

export function TrashIcon(props) {
  return (
    <Svg size={16} {...props}>
      <path d="M3 6h18M19 6v14c0 1-1 2-2 2H7c-1 0-2-1-2-2V6M8 6V4c0-1 1-2 2-2h4c1 0 2 1 2 2v2" />
    </Svg>
  )
}

export function PlaneIcon(props) {
  return (
    <Svg size={18} {...props}>
      <path d="M17.8 19.2 16 11l3.5-3.5C21 6 21.5 4 21 3c-1-.5-3 0-4.5 1.5L13 8 4.8 6.2c-.5-.1-.9.1-1.1.5l-.3.5c-.2.5-.1 1 .3 1.3L9 12l-2 3H4l-1 1 3 2 2 3 1-1v-3l3-2 3.5 5.2c.3.4.8.5 1.3.3l.5-.2c.4-.3.6-.7.5-1.3z" />
    </Svg>
  )
}

export function TrainIcon(props) {
  return (
    <Svg size={18} {...props}>
      <rect width="16" height="16" x="4" y="3" rx="2" />
      <path d="M4 11h16M12 3v8M8 19l-2 3M16 19l2 3" />
      <circle cx="8" cy="15" r="1" />
      <circle cx="16" cy="15" r="1" />
    </Svg>
  )
}

export function CarIcon(props) {
  return (
    <Svg size={18} {...props}>
      <path d="M19 17h2c.6 0 1-.4 1-1v-3c0-.9-.7-1.7-1.5-1.9C18.7 10.6 16 10 16 10s-1.3-1.4-2.2-2.3c-.5-.4-1.1-.7-1.8-.7H5c-.6 0-1.1.4-1.4.9l-1.5 2.8C1.4 11.2 1 12 1 13v3c0 .6.4 1 1 1h2" />
      <circle cx="7" cy="17" r="2" />
      <path d="M9 17h6" />
      <circle cx="17" cy="17" r="2" />
    </Svg>
  )
}

export function DollarIcon(props) {
  return (
    <Svg size={18} {...props}>
      <line x1="12" x2="12" y1="2" y2="22" />
      <path d="M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6" />
    </Svg>
  )
}

export function BankIcon(props) {
  return (
    <Svg size={18} {...props}>
      <path d="m3 9 9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z" />
      <path d="M9 22V12h6v10" />
    </Svg>
  )
}

export function UserPlusIcon(props) {
  return (
    <Svg size={16} {...props}>
      <path d="M16 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" />
      <circle cx="8.5" cy="7" r="4" />
      <line x1="20" y1="8" x2="20" y2="14" />
      <line x1="23" y1="11" x2="17" y2="11" />
    </Svg>
  )
}

export function SlidersIcon(props) {
  return (
    <Svg size={16} {...props}>
      <line x1="4" y1="21" x2="4" y2="14" />
      <line x1="4" y1="10" x2="4" y2="3" />
      <line x1="12" y1="21" x2="12" y2="12" />
      <line x1="12" y1="8" x2="12" y2="3" />
      <line x1="20" y1="21" x2="20" y2="16" />
      <line x1="20" y1="12" x2="20" y2="3" />
      <line x1="1" y1="14" x2="7" y2="14" />
      <line x1="9" y1="8" x2="15" y2="8" />
      <line x1="17" y1="16" x2="23" y2="16" />
    </Svg>
  )
}

export function SparklesIcon(props) {
  return (
    <Svg size={16} {...props}>
      <path d="m12 3-1.9 5.8a2 2 0 0 1-1.3 1.3L3 12l5.8 1.9a2 2 0 0 1 1.3 1.3L12 21l1.9-5.8a2 2 0 0 1 1.3-1.3L21 12l-5.8-1.9a2 2 0 0 1-1.3-1.3Z" />
    </Svg>
  )
}

export function SendIcon(props) {
  return (
    <Svg size={16} {...props}>
      <line x1="22" y1="2" x2="11" y2="13" />
      <polygon points="22 2 15 22 11 13 2 9 22 2" />
    </Svg>
  )
}

