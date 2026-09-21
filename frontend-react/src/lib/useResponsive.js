import { useMediaQuery } from 'react-responsive'

/**
 * Standardized responsive hook wrapping react-responsive with application breakpoint tokens.
 * - isMobile: <= 768px (Phones, compact screens)
 * - isTablet: 769px - 1024px (Tablets, iPads)
 * - isDesktop: >= 1025px (Laptops, desktops)
 * - isCompact: <= 1024px (Any screen smaller than standard desktop)
 */
export function useResponsive() {
  const isMobile = useMediaQuery({ maxWidth: 768 })
  const isTablet = useMediaQuery({ minWidth: 769, maxWidth: 1024 })
  const isDesktop = useMediaQuery({ minWidth: 1025 })
  const isCompact = useMediaQuery({ maxWidth: 1024 })

  return {
    isMobile,
    isTablet,
    isDesktop,
    isCompact,
  }
}
