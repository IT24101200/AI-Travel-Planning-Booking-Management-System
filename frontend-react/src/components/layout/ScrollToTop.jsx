import { useEffect } from 'react'
import { useLocation } from 'react-router-dom'
import { usePrefersReducedMotion } from '../../lib/hooks.js'

/**
 * Sends the window back to the top on navigation, but leaves in-page hash links
 * (#main from the skip link) alone.
 */
export function ScrollToTop() {
  const { pathname, hash } = useLocation()
  const reduced = usePrefersReducedMotion()

  useEffect(() => {
    if (hash) return
    window.scrollTo({ top: 0, left: 0, behavior: reduced ? 'auto' : 'smooth' })
  }, [pathname, hash, reduced])

  return null
}
