import { useCountUp, useReveal } from '../../lib/hooks.js'
import { StarIcon } from './Icons.jsx'

/**
 * Wraps children in a scroll-triggered reveal.
 * `variant` picks the direction: up (default), left, right or zoom.
 */
export function Reveal({ children, as: Tag = 'div', variant, delay = 0, className = '' }) {
  const [ref, visible] = useReveal()

  return (
    <Tag
      ref={ref}
      data-variant={variant}
      className={`reveal${visible ? ' reveal--visible' : ''}${className ? ` ${className}` : ''}`}
      style={delay ? { '--reveal-delay': `${delay}ms` } : undefined}
    >
      {children}
    </Tag>
  )
}

/** Section heading block. Pass `action` to get the title/link split layout. */
export function SectionHead({ eyebrow, title, lede, align = 'start', onDark = false, action }) {
  const text = (
    <div className="stack">
      {eyebrow ? <span className="eyebrow">{eyebrow}</span> : null}
      <h2>{title}</h2>
      {lede ? <p className="lede">{lede}</p> : null}
    </div>
  )

  const modifiers = [
    action ? 'sec-head--split' : '',
    align === 'center' ? 'sec-head--center' : '',
    onDark ? 'sec-head--on-dark' : '',
  ]
    .filter(Boolean)
    .join(' ')

  return (
    <Reveal className={`sec-head ${modifiers}`.trim()}>
      {text}
      {action}
    </Reveal>
  )
}

/** Row of filled stars, 1-5. */
export function Stars({ count = 5 }) {
  return (
    <div className="quote__stars">
      <span className="sr-only">{count} out of 5</span>
      {Array.from({ length: count }, (_, i) => (
        <StarIcon key={i} />
      ))}
    </div>
  )
}

/** Animated counter tile used in the proof band. */
export function StatTile({ value, suffix = '', label, decimals = 0 }) {
  const [ref, current] = useCountUp(value, { decimals })

  return (
    <div className="stat" ref={ref}>
      <span className="stat__num">
        {decimals ? current.toFixed(decimals) : Math.round(current).toLocaleString()}
        {suffix}
      </span>
      <span className="stat__label">{label}</span>
    </div>
  )
}
