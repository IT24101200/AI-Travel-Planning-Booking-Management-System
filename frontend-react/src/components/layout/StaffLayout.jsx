import { Link, NavLink, Outlet } from 'react-router-dom'
import { useAuth } from '../../lib/auth.jsx'

const links = [
  { to: '/staff/bookings', label: 'Approvals' },
  { to: '/staff/payments', label: 'Revenue' },
  { to: '/staff/customers', label: 'Customers' },
  { to: '/staff/notifications', label: 'Notifications' },
  { to: '/staff/tours', label: 'Tours' },
  { to: '/staff/itineraries', label: 'Itineraries' },
  { to: '/staff/hotels', label: 'Hotels' },
  { to: '/staff/transport', label: 'Transport' },
]

/** Staff console shell: sidebar + content. All tables live under /staff/*. */
export function StaffLayout() {
  const { user, logout } = useAuth()

  return (
    <div className="staff">
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
      <div className="staff__main">
        <Outlet />
      </div>
    </div>
  )
}
