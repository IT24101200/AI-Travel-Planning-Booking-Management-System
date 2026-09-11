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
