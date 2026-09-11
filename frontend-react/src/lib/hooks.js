import { useEffect, useRef, useState } from 'react'

/** True once the user has scrolled past `offset` px. Drives the sticky header. */
export function useScrolled(offset = 24) {
  const [scrolled, setScrolled] = useState(false)

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > offset)
    onScroll()
    window.addEventListener('scroll', onScroll, { passive: true })
    return () => window.removeEventListener('scroll', onScroll)
  }, [offset])

  return scrolled
}

/** Tracks the prefers-reduced-motion media query. */
export function usePrefersReducedMotion() {
  const [reduced, setReduced] = useState(
    () => typeof window !== 'undefined' && window.matchMedia('(prefers-reduced-motion: reduce)').matches,
  )

  useEffect(() => {
    const mq = window.matchMedia('(prefers-reduced-motion: reduce)')
    const onChange = (e) => setReduced(e.matches)
    mq.addEventListener('change', onChange)
    return () => mq.removeEventListener('change', onChange)
  }, [])

  return reduced
}

/** Adds `.reveal--visible` the first time an element scrolls into view. */
export function useReveal(options = {}) {
  const ref = useRef(null)
  // No IntersectionObserver (old browser, jsdom): show everything immediately.
  const [visible, setVisible] = useState(
    () => typeof window === 'undefined' || !('IntersectionObserver' in window),
  )

  useEffect(() => {
    const el = ref.current
    if (!el || visible) return

    const io = new IntersectionObserver(
      (entries) => {
        if (entries.some((e) => e.isIntersecting)) {
          setVisible(true)
          io.disconnect()
        }
      },
      { rootMargin: options.rootMargin ?? '0px 0px -12% 0px', threshold: options.threshold ?? 0.15 },
    )

    io.observe(el)
    return () => io.disconnect()
  }, [visible, options.rootMargin, options.threshold])

  return [ref, visible]
}

/** Counts from 0 to `target` once the element is on screen. */
export function useCountUp(target, { duration = 1400, decimals = 0 } = {}) {
  const [ref, visible] = useReveal({ threshold: 0.4 })
  const reduced = usePrefersReducedMotion()
  const [value, setValue] = useState(0)

  useEffect(() => {
    if (!visible || reduced) return

    let raf = 0
    const start = performance.now()
    const tick = (now) => {
      const t = Math.min(1, (now - start) / duration)
      const eased = 1 - (1 - t) ** 3
      setValue(Number((target * eased).toFixed(decimals)))
      if (t < 1) raf = requestAnimationFrame(tick)
    }
    raf = requestAnimationFrame(tick)
    return () => cancelAnimationFrame(raf)
  }, [visible, reduced, target, duration, decimals])

  // Reduced motion skips the animation and just shows the final number.
  return [ref, reduced ? target : value]
}

/** Locks page scroll while a mobile drawer or modal is open. */
export function useScrollLock(active) {
  useEffect(() => {
    if (!active) return
    const previous = document.body.style.overflow
    document.body.style.overflow = 'hidden'
    return () => {
      document.body.style.overflow = previous
    }
  }, [active])
}

/** Sets document.title for the current page. */
export function usePageTitle(title) {
  useEffect(() => {
    document.title = title ? `${title} · Serendib Trails` : 'Serendib Trails'
  }, [title])
}
