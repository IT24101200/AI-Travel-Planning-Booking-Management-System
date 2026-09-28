import { useState } from 'react'
import { Link, useLocation, useNavigate } from 'react-router-dom'
import { useAuth } from '../../lib/auth.jsx'
import { usePageTitle } from '../../lib/hooks.js'
import {
  MountainSnowIcon,
  ArrowRightIcon,
  CheckIcon
} from '../../components/ui/Icons.jsx'

/**
 * Serendib Trails — Staff Portal Login
 * Designed based on Figma Dev Mode Specifications (node-id: 2:26586)
 */
export default function Login() {
  const { login, logout } = useAuth()
  const navigate = useNavigate()
  const location = useLocation()
  const [email, setEmail] = useState('agent@colombo.lk')
  const [password, setPassword] = useState('Staff@123')
  const [showPassword, setShowPassword] = useState(false)
  const [rememberMe, setRememberMe] = useState(true)
  const [error, setError] = useState(() => {
    if (location.state?.error) return location.state.error
    if (typeof window !== 'undefined' && new URLSearchParams(window.location.search).get('expired')) {
      return 'Your staff session has expired. Please sign in again with your credentials.'
    }
    return ''
  })
  const [busy, setBusy] = useState(false)
  usePageTitle('Staff Sign In · Serendib Trails')

  async function onSubmit(e) {
    e.preventDefault()
    if (!email.includes('@')) {
      setError('Please use a valid email address.')
      return
    }
    if (password.length < 4) {
      setError('Password must contain at least 4 characters.')
      return
    }
    setError('')
    setBusy(true)
    try {
      const session = await login(email.trim(), password)
      if (!session || session.token === 'demo-token') {
        setError('Invalid staff credentials. Please check your email and password.')
        return
      }

      // Customers CANNOT log into the staff portal
      if (session.role === 'customer') {
        logout()
        setError('Access denied: Customer accounts cannot log in to the staff console. Please use staff credentials.')
        return
      }

      const from = location.state?.from
      if (from && from.startsWith('/staff')) {
        navigate(from, { replace: true })
      } else {
        navigate('/staff', { replace: true })
      }
    } catch {
      setError('Authentication failed. Server unreachable or invalid credentials.')
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="login-split-page">
      {/* ── Left Column: Brand Hero Backdrop matching Figma 2:26586 ── */}
      <div
        className="login-brand-col"
        style={{
          background: 'linear-gradient(135deg, #0b1418 0%, #17242a 50%, #1b332b 100%)',
          position: 'relative',
          overflow: 'hidden'
        }}
      >
        {/* Subtle decorative glowing mesh overlay */}
        <div
          style={{
            position: 'absolute',
            top: '-20%',
            left: '-10%',
            width: '600px',
            height: '600px',
            background: 'radial-gradient(circle, rgba(183, 121, 31, 0.18) 0%, transparent 70%)',
            pointerEvents: 'none'
          }}
        />

        {/* Top Brand Mark with return link */}
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', width: '100%', position: 'relative', zIndex: 2 }}>
          <Link to="/" style={{ display: 'flex', alignItems: 'center', gap: '0.875rem', textDecoration: 'none' }} title="Return to public website">
            <div className="staff__brand-box">
              <MountainSnowIcon size={24} />
            </div>
            <div>
              <span style={{ fontSize: '1.125rem', fontWeight: 700, color: '#f7faf9', display: 'block', lineHeight: 1.1 }}>
                Serendib Trails
              </span>
              <span style={{ fontSize: '0.6875rem', fontWeight: 600, color: '#aab7bb', letterSpacing: '0.05em', textTransform: 'uppercase' }}>
                Staff console
              </span>
            </div>
          </Link>
          <Link
            to="/"
            style={{
              color: '#cbd5e1',
              fontSize: '0.75rem',
              textDecoration: 'none',
              padding: '0.35rem 0.65rem',
              borderRadius: '6px',
              backgroundColor: 'rgba(255, 255, 255, 0.08)',
              border: '1px solid rgba(255, 255, 255, 0.15)',
              transition: 'background-color 0.15s ease'
            }}
          >
            ← Public site
          </Link>
        </div>

        {/* Hero Narrative Headline */}
        <div className="login-brand-col__hero" style={{ position: 'relative', zIndex: 2 }}>
          <p style={{ color: '#b7791f', fontSize: '0.75rem', fontWeight: 800, letterSpacing: '0.08em', textTransform: 'uppercase', margin: 0 }}>
            TRAVEL OPERATIONS, CONNECTED
          </p>
          <h1 className="login-brand-col__title">
            Every journey, carefully coordinated.
          </h1>
          <p className="login-brand-col__sub">
            Review bookings, keep partners aligned, and make every Sri Lankan itinerary exceptional—from one secure workspace.
          </p>

          <div className="login-brand-col__features" style={{ marginTop: '1rem' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
              <div style={{ width: '18px', height: '18px', borderRadius: '50%', background: '#b7791f', color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                <CheckIcon size={12} />
              </div>
              <span>Secure staff access</span>
            </div>
            <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
              <div style={{ width: '18px', height: '18px', borderRadius: '50%', background: '#b7791f', color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                <CheckIcon size={12} />
              </div>
              <span>Live operations data</span>
            </div>
            <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
              <div style={{ width: '18px', height: '18px', borderRadius: '50%', background: '#b7791f', color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                <CheckIcon size={12} />
              </div>
              <span>AI-assisted review</span>
            </div>
          </div>
        </div>

        {/* Bottom copyright notice */}
        <div style={{ fontSize: '0.75rem', color: '#8fa0a6', position: 'relative', zIndex: 2 }}>
          © {new Date().getFullYear()} Serendib Trails Ltd. All rights reserved.
        </div>
      </div>

      {/* ── Right Column: Sign-in Form Card matching Figma 2:26586 ── */}
      <div className="login-form-col">
        <form className="login-card" onSubmit={onSubmit}>
          <div style={{ display: 'flex', flexDirection: 'column', gap: '0.35rem' }}>
            <span style={{ color: '#b7791f', fontSize: '0.6875rem', fontWeight: 800, letterSpacing: '0.06em', textTransform: 'uppercase' }}>
              SECURE STAFF ACCESS
            </span>
            <h2 style={{ fontSize: '1.75rem', fontWeight: 700, color: '#182126', margin: 0, lineHeight: 1.2 }}>
              Welcome back
            </h2>
            <p style={{ fontSize: '0.8125rem', color: '#66747b', margin: 0 }}>
              Sign in with your approved Serendib Trails account.
            </p>
          </div>

          {/* Email field */}
          <div>
            <label htmlFor="staff-email" style={{ display: 'block', fontSize: '0.75rem', fontWeight: 700, color: '#182126', marginBottom: '0.35rem' }}>
              Staff email *
            </label>
            <input
              id="staff-email"
              type="email"
              required
              autoComplete="username"
              className="staff-search-box"
              style={{ maxWidth: '100%', width: '100%', height: '42px' }}
              value={email}
              onChange={(e) => setEmail(e.target.value)}
            />
          </div>

          {/* Password field */}
          <div>
            <label htmlFor="staff-password" style={{ display: 'block', fontSize: '0.75rem', fontWeight: 700, color: '#182126', marginBottom: '0.35rem' }}>
              Password *
            </label>
            <div style={{ position: 'relative', display: 'flex', alignItems: 'center' }}>
              <input
                id="staff-password"
                type={showPassword ? 'text' : 'password'}
                required
                autoComplete="current-password"
                className="staff-search-box"
                style={{ maxWidth: '100%', width: '100%', height: '42px', paddingRight: '2.5rem' }}
                value={password}
                onChange={(e) => setPassword(e.target.value)}
              />
              <button
                type="button"
                onClick={() => setShowPassword(!showPassword)}
                style={{
                  position: 'absolute',
                  right: '0.75rem',
                  background: 'none',
                  border: 'none',
                  color: '#66747b',
                  fontSize: '0.75rem',
                  cursor: 'pointer'
                }}
              >
                {showPassword ? 'Hide' : 'Show'}
              </button>
            </div>
          </div>

          {/* Remember me & Forgot Password */}
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', fontSize: '0.8125rem' }}>
            <label style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', cursor: 'pointer', color: '#182126' }}>
              <input
                type="checkbox"
                checked={rememberMe}
                onChange={(e) => setRememberMe(e.target.checked)}
                style={{ accentColor: '#b7791f' }}
              />
              <span>Remember this device</span>
            </label>
            <a
              href="#forgot"
              onClick={(e) => {
                e.preventDefault()
                alert('Contact internal IT operations at ops@serendib.lk to request password reset.')
              }}
              style={{ color: '#b7791f', textDecoration: 'none', fontWeight: 600 }}
            >
              Forgot password?
            </a>
          </div>

          {/* Error / Validation Alert Banner */}
          {error && (
            <div className="banner-danger" style={{ fontSize: '0.75rem' }}>
              <span style={{ fontSize: '1rem' }}>ⓘ</span>
              <span>{error}</span>
            </div>
          )}

          {/* Gold Submit Button */}
          <button
            type="submit"
            className="btn-gold"
            style={{ width: '100%', height: '42px', justifyContent: 'center', fontSize: '0.875rem' }}
            disabled={busy}
          >
            <span>{busy ? 'Verifying credentials…' : 'Sign in to staff console'}</span>
            <ArrowRightIcon size={16} />
          </button>

          {/* Customer return link */}
          <div style={{ textAlign: 'center', margin: '0.25rem 0' }}>
            <Link to="/" style={{ fontSize: '0.75rem', color: '#66747b', textDecoration: 'none', fontWeight: 500 }}>
              Not a staff member? <span style={{ color: '#b7791f', fontWeight: 600 }}>Return to customer site →</span>
            </Link>
          </div>

          {/* Security footnote */}
          <p style={{ margin: 0, fontSize: '0.6875rem', color: '#8fa0a6', textAlign: 'center', lineHeight: 1.4 }}>
            Protected by multi-factor authentication · Session activity is audited
          </p>
        </form>
      </div>
    </div>
  )
}
