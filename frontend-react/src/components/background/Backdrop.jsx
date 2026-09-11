import { useEffect, useRef } from 'react'
import { createBackdrop } from '../../lib/backdrop.js'
import { usePrefersReducedMotion } from '../../lib/hooks.js'
import { destinations } from '../../data/destinations.js'
import { SkyCelestial } from './SkyCelestial.jsx'

/** One stacked image layer: `state` is 'in' for the current, 'out' for the last. */
function ImageLayer({ destination, state, eager = false }) {
  return (
    <div className={`scene scene--${state}`}>
      <img
        src={destination.image}
        srcSet={destination.thumb ? `${destination.thumb} 500w, ${destination.image} 1280w` : undefined}
        sizes="100vw"
        alt=""
        aria-hidden="true"
        className="scene__img"
        loading={eager ? 'eager' : 'lazy'}
        decoding="async"
        style={{ objectPosition: destination.imagePosition || 'center' }}
      />
    </div>
  )
}

/**
 * Fixed backdrop shared by every page.
 *
 * - a real photo cross-fades whenever `activeId` changes (clicking a place)
 * - a canvas above it draws drifting motes and a burst wherever the user clicks
 *
 * The canvas is pointer-events:none, so clicks still reach the real UI; we
 * listen on window instead and mirror the coordinates into the particle engine.
 */
export function Backdrop({
  activeId,
  leavingId = null,
  calm = false,
  weather = null,
  timeOfDay = 'morning',
}) {
  const canvasRef = useRef(null)
  const engineRef = useRef(null)
  const reduced = usePrefersReducedMotion()

  const weatherClass = weather ? ` backdrop--${weather}` : ''

  const active = destinations.find((d) => d.id === activeId) ?? destinations[0]
  // The place we just left stays mounted at opacity 0 so the two layers can
  // cross-fade; App remembers it when the active id changes.
  const leaving =
    leavingId && leavingId !== active.id ? destinations.find((d) => d.id === leavingId) : null

  useEffect(() => {
    const canvas = canvasRef.current
    if (!canvas) return

    const engine = createBackdrop(canvas, { reducedMotion: reduced })
    engineRef.current = engine

    const onPointerDown = (event) => {
      if (event.button !== 0) return
      const interactive = event.target?.closest?.('a, button, input, select, textarea')
      engine.burst(event.clientX, event.clientY, interactive ? 1.3 : 1)
    }

    // Keyboard activation gets the same feedback, centred on the focused element.
    const onKeyDown = (event) => {
      if (event.key !== 'Enter' && event.key !== ' ') return
      const el = document.activeElement
      if (!el || el === document.body) return
      const box = el.getBoundingClientRect()
      engine.burst(box.left + box.width / 2, box.top + box.height / 2, 1.15)
    }

    window.addEventListener('pointerdown', onPointerDown)
    window.addEventListener('keydown', onKeyDown)

    return () => {
      window.removeEventListener('pointerdown', onPointerDown)
      window.removeEventListener('keydown', onKeyDown)
      engine.destroy()
      engineRef.current = null
    }
  }, [reduced])

  useEffect(() => {
    engineRef.current?.setPalette(active.palette)
  }, [active.palette])

  return (
    <div className={`backdrop${calm ? ' backdrop--calm' : ''}${weatherClass}`} aria-hidden="true">
      {leaving ? <ImageLayer key={leaving.id} destination={leaving} state="out" /> : null}
      <ImageLayer key={active.id} destination={active} state="in" eager />
      <canvas ref={canvasRef} className="backdrop__canvas" />
      <div className="backdrop__veil" />
      <SkyCelestial timeOfDay={timeOfDay} weather={weather || 'clear'} />
    </div>
  )
}
