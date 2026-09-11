import { useEffect, useState } from 'react'
import { Link, NavLink } from 'react-router-dom'
import { navLinks, brand } from '../../data/site.js'
import { useAuth } from '../../lib/auth.jsx'
import { useScrollLock, useScrolled } from '../../lib/hooks.js'
import { LeafIcon, SparkleIcon } from '../ui/Icons.jsx'

function Brand({ onClick }) {
  return (
    <Link to="/" className="brand" onClick={onClick}>
      <span className="brand__mark">
        <LeafIcon size={22} />
      </span>
      <span className="brand__name">
        <b>{brand.name}</b>
        <span>{brand.kicker}</span>
      </span>
    </Link>
  )
}

export function Navbar() {
  const scrolled = useScrolled(28)
  const [open, setOpen] = useState(false)
  const { user, logout } = useAuth() ?? {}
  const close = () => setOpen(false)

  useScrollLock(open)

  useEffect(() => {
    if (!open) return
    const onKey = (e) => e.key === 'Escape' && setOpen(false)
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [open])

  const staffPath = user && user.role !== 'customer' ? '/staff' : '/login'

  return (
    <header className={`header${scrolled || open ? ' header--pinned' : ''}`}>
      <div className="shell header__inner">
        <Brand onClick={close} />

        <nav className="nav" aria-label="Primary">
          {navLinks.map((link) => (
            <NavLink
              key={link.to}
              to={link.to}
              end={link.to === '/'}
              className={({ isActive }) => `nav__link${isActive ? ' is-active' : ''}`}
            >
              {link.label}
            </NavLink>
          ))}
          <NavLink
            to={staffPath}
            className={({ isActive }) => `nav__link${isActive ? ' is-active' : ''}`}
          >
            Staff
          </NavLink>
        </nav>

        <div className="header__actions">
          {user ? (
            <button type="button" className="btn btn--sm btn--on-dark" onClick={logout} title={user.email}>
              Sign out
            </button>
          ) : (
            <Link className="btn btn--sm btn--nav-outline" to="/login" onClick={close}>
              Sign in
            </Link>
          )}
          <Link className="btn btn--sm btn--nav-primary" to="/planner" onClick={close}>
            <SparkleIcon size={16} /> Plan my trip
          </Link>

          <button
            type="button"
            className="burger"
            aria-expanded={open}
            aria-controls="mobile-nav"
            aria-label={open ? 'Close menu' : 'Open menu'}
            onClick={() => setOpen((v) => !v)}
          >
            <span className="burger__bars" />
          </button>
        </div>
      </div>

      {open ? (
        <nav id="mobile-nav" className="drawer" aria-label="Mobile">
          {navLinks.map((link) => (
            <NavLink
              key={link.to}
              to={link.to}
              end={link.to === '/'}
              onClick={close}
              className={({ isActive }) => `drawer__link${isActive ? ' is-active' : ''}`}
            >
              {link.label}
            </NavLink>
          ))}
          <NavLink
            to={staffPath}
            onClick={close}
            className={({ isActive }) => `drawer__link${isActive ? ' is-active' : ''}`}
          >
            Staff console
          </NavLink>
          {user ? (
            <button
              type="button"
              className="btn btn--block"
              onClick={() => {
                logout()
                close()
              }}
            >
              Sign out ({user.email})
            </button>
          ) : (
            <Link className="btn btn--block" to="/login" onClick={close}>
              Sign in
            </Link>
          )}
          <Link className="btn btn--block" to="/planner" onClick={close}>
            <SparkleIcon size={16} /> Plan my trip
          </Link>
        </nav>
      ) : null}
    </header>
  )
}
