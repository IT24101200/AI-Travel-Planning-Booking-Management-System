import { useState, useEffect } from 'react'
import { Link, NavLink, Outlet, useLocation } from 'react-router-dom'
import { useAuth } from '../../lib/auth.jsx'
import { useResponsive } from '../../lib/useResponsive.js'

const links = [
  { to: '/staff/bookings', label: 'Approvals' },
  { to: '/staff/payments', label: 'Revenue' },
  { to: '/staff/customers', label: 'Customers' },
  { to: '/staff/notifications', label: 'Notifications' },
  { to: '/staff/tours', label: 'Tours' },
  { to: '/staff/destinations', label: 'Destinations' },
  { to: '/staff/itineraries', label: 'Itineraries' },
  { to: '/staff/hotels', label: 'Hotels' },
  { to: '/staff/transport', label: 'Transport' },
]

/** Staff console shell: responsive sidebar on desktop, collapsible drawer on mobile. */
export function StaffLayout() {
  const { user, logout } = useAuth()
  const { isMobile } = useResponsive()
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false)
  const location = useLocation()

  // Automatically close mobile menu when navigating
  useEffect(() => {
    setMobileMenuOpen(false)
  }, [location.pathname])

  const activeLink = links.find((l) => location.pathname.startsWith(l.to)) || links[0]

  return (
    <div className="staff">
      {/* Mobile Top Bar */}
      {isMobile && (
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            padding: '0.75rem 1rem',
            backgroundColor: '#1E293B',
            color: '#FFFFFF',
            borderBottom: '1px solid #334155',
          }}
        >
          <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
            <Link to="/" style={{ color: '#94A3B8', textDecoration: 'none', fontSize: '0.8125rem' }}>
              Serendib Trails
            </Link>
            <span style={{ color: '#475569' }}>/</span>
            <span style={{ fontWeight: 600, fontSize: '0.875rem' }}>{activeLink.label}</span>
          </div>
          <button
            type="button"
            onClick={() => setMobileMenuOpen((prev) => !prev)}
            style={{
              backgroundColor: '#334155',
              color: '#F8FAFC',
              border: 'none',
              borderRadius: '6px',
              padding: '0.35rem 0.75rem',
              fontSize: '0.8125rem',
              fontWeight: 500,
              cursor: 'pointer',
            }}
          >
            {mobileMenuOpen ? 'Close ✕' : 'Staff Menu ☰'}
          </button>
        </div>
      )}

      {/* Staff Sidebar / Navigation */}
      {(!isMobile || mobileMenuOpen) && (
        <aside className="staff__side">
          <Link to="/" className="staff__brand">
            <b>Serendib Trails</b>
            <span>Staff console</span>
          </Link>
          <nav className="staff__nav" aria-label="Staff">
            {links.map((l) => (
              <NavLink
                key={l.to}
                to={l.to}
                className={({ isActive }) => `staff__link${isActive ? ' is-active' : ''}`}
              >
                {l.label}
              </NavLink>
            ))}
          </nav>
          <div className="staff__foot">
            <span className="staff__user">{user?.email}</span>
            <Link to="/" className="staff__ghost" onClick={logout}>
              Sign out
            </Link>
          </div>
        </aside>
      )}

      <div className="staff__main">
        <Outlet />
      </div>
    </div>
  )
}
