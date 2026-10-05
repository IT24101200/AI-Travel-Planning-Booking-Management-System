import { useState, useEffect } from 'react'
import { Link, NavLink, Outlet, useLocation } from 'react-router-dom'
import { useAuth } from '../../lib/auth.jsx'
import { useResponsive } from '../../lib/useResponsive.js'
import {
  LeafIcon,
  ClipboardCheckIcon,
  ChartTrendingIcon,
  UsersIcon,
  BellIcon,
  MapIcon,
  MapPinIcon,
  RouteIcon,
  BuildingIcon,
  BusFrontIcon,
  ImageIcon,
  LogOutIcon,
} from '../ui/Icons.jsx'

const links = [
  { to: '/staff/bookings', label: 'Approvals', icon: ClipboardCheckIcon },
  { to: '/staff/payments', label: 'Revenue', icon: ChartTrendingIcon },
  { to: '/staff/customers', label: 'Customers', icon: UsersIcon },
  { to: '/staff/notifications', label: 'Notifications', icon: BellIcon },
  { to: '/staff/tours', label: 'Tours', icon: MapIcon },
  { to: '/staff/destinations', label: 'Destinations', icon: MapPinIcon },
  { to: '/staff/itineraries', label: 'Itineraries', icon: RouteIcon },
  { to: '/staff/hotels', label: 'Hotels', icon: BuildingIcon },
  { to: '/staff/transport', label: 'Transport', icon: BusFrontIcon },
  { to: '/staff/media', label: 'Media Library', icon: ImageIcon },
]

/**
 * Staff console shell designed according to Figma Dev Mode specifications:
 * - Fixed 240px dark slate sidebar (#17242a)
 * - Brand mark with gold rounded icon container (#b7791f)
 * - Icon-based navigation with active indicator marker
 * - User identity block with avatar initials and sign-out
 * - Responsive collapsible drawer on mobile screens
 */
export function StaffLayout() {
  const { user, logout } = useAuth()
  const { isMobile } = useResponsive()
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false)
  const location = useLocation()

  // Automatically close mobile menu when navigating
  useEffect(() => {
    // Navigation invalidates the drawer state; this is intentional UI synchronization.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    setMobileMenuOpen(false)
  }, [location.pathname])

  const activeLink = links.find((l) => location.pathname.startsWith(l.to)) || links[0]

  // Compute initials for user avatar
  const initials = (() => {
    if (user?.name) {
      const parts = user.name.trim().split(/\s+/)
      if (parts.length >= 2) return `${parts[0][0]}${parts[1][0]}`.toUpperCase()
      return user.name.substring(0, 2).toUpperCase()
    }
    if (user?.email) {
      return user.email.substring(0, 2).toUpperCase()
    }
    return 'NK'
  })()

  const roleTitle = (() => {
    if (!user?.role) return 'Operations lead'
    if (user.role.toLowerCase() === 'admin') return 'System administrator'
    if (user.role.toLowerCase() === 'travelagent') return 'Travel operations agent'
    return user.role
  })()

  return (
    <div className="staff">
      {/* Mobile Top Bar */}
      {isMobile && (
        <div className="staff__mobile-bar">
          <div className="staff__mobile-brand">
            <span className="staff__brand-box" style={{ width: '34px', height: '34px', borderRadius: '10px' }}>
              <LeafIcon size={18} />
            </span>
            <div className="staff__mobile-crumbs">
              <Link to="/" className="staff__mobile-crumb-home">
                Serendib Trails
              </Link>
              <span className="staff__mobile-sep">/</span>
              <span className="staff__mobile-current">{activeLink.label}</span>
            </div>
          </div>
          <button
            type="button"
            onClick={() => setMobileMenuOpen((prev) => !prev)}
            className="staff__mobile-toggle"
            aria-label="Toggle navigation menu"
          >
            {mobileMenuOpen ? 'Close ✕' : 'Menu ☰'}
          </button>
        </div>
      )}

      {/* Staff Sidebar */}
      {(!isMobile || mobileMenuOpen) && (
        <aside className={`staff__side${isMobile && mobileMenuOpen ? ' is-mobile-open' : ''}`}>
          <Link to="/" className="staff__brand" title="Serendib Trails — Home">
            <span className="staff__brand-box">
              <LeafIcon size={22} />
            </span>
            <div className="staff__brand-text">
              <b className="staff__brand-name">Serendib Trails</b>
              <span className="staff__brand-sub">Sri Lanka · Since 2016</span>
            </div>
          </Link>

          <div className="staff__divider" />

          <nav className="staff__nav" aria-label="Staff Navigation">
            {links.map((item) => {
              const IconComponent = item.icon
              const isActive = location.pathname.startsWith(item.to) || (item.to === '/staff/bookings' && location.pathname === '/staff')

              return (
                <NavLink
                  key={item.to}
                  to={item.to}
                  className={`staff__link${isActive ? ' is-active' : ''}`}
                >
                  <span className="staff__link-icon">
                    <IconComponent size={17} />
                  </span>
                  <span className="staff__link-label">{item.label}</span>
                  {isActive && <span className="staff__link-marker" />}
                </NavLink>
              )
            })}
          </nav>

          <div className="staff__side-spacer" />

          {/* Account & Profile Footer */}
          <div className="staff__account">
            <div className="staff__user-card">
              <div className="staff__avatar">{initials}</div>
              <div className="staff__identity">
                <span className="staff__role-label">{roleTitle}</span>
                <span className="staff__email-label" title={user?.email || 'n.kapoor@serendib.lk'}>
                  {user?.email || 'n.kapoor@serendib.lk'}
                </span>
              </div>
            </div>
            <Link to="/" className="staff__signout" style={{ color: '#8fa0a6' }}>
              <span>← View customer website</span>
            </Link>
            <Link to="/" className="staff__signout" onClick={logout}>
              <LogOutIcon size={14} />
              <span>Sign out</span>
            </Link>
          </div>
        </aside>
      )}

      {/* Main Content Workspace */}
      <main className="staff__main" id="staff-workspace">
        <Outlet />
      </main>
    </div>
  )
}
