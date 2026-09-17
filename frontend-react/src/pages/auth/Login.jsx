import { useState } from 'react'
import { Link, useLocation, useNavigate } from 'react-router-dom'
import { Masthead } from '../../components/layout/Masthead.jsx'
import { useAuth } from '../../lib/auth.jsx'
import { usePageTitle } from '../../lib/hooks.js'

/** Staff + customer sign-in. Demo-ready: works offline, tries the API first. */
export default function Login() {
  const { login, logout } = useAuth()
  const navigate = useNavigate()
  const location = useLocation()
  const [email, setEmail] = useState('agent@colombo.lk')
  const [password, setPassword] = useState('Staff@123')
  const [showPassword, setShowPassword] = useState(false)
  const [error, setError] = useState(location.state?.error || '')
  const [busy, setBusy] = useState(false)
  usePageTitle('Staff Sign in')

  async function onSubmit(e) {
    e.preventDefault()
    if (!email.includes('@')) {
      setError('Use a valid email address.')
      return
    }
    if (password.length < 4) {
      setError('Password needs at least 4 characters.')
      return
    }
    setError('')
    setBusy(true)
    try {
      const session = await login(email.trim(), password)
      if (!session || session.token === 'demo-token') {
        setError('Invalid email or password. Please check your staff credentials.')
        return
      }

      // Customers CANNOT log into the staff portal
      if (session.role === 'customer') {
        logout()
        setError('Access denied: Customer accounts cannot log in to the staff portal. Please use staff credentials.')
        return
      }

      const from = location.state?.from
      if (from && from.startsWith('/staff')) {
        navigate(from, { replace: true })
      } else {
        navigate('/staff', { replace: true })
      }
    } catch {
      setError('Sign-in failed. Try again.')
    } finally {
      setBusy(false)
    }
  }

  return (
    <>
      <Masthead
        eyebrow="Staff sign in"
        title="Welcome back."
        lede="Agents and admins sign in here. Use your staff credentials to access the console."
        crumbs={[{ label: 'Sign in' }]}
      />
      <section className="section section--overlap">
        <div className="shell" style={{ maxWidth: '34rem' }}>
          {/* Frosted-glass login card floats over scenic backdrop */}
          <form
            className="panel form"
            style={{
              position: 'relative',
              overflow: 'hidden',
              padding: '2.25rem',
              background: 'rgba(255, 255, 255, 0.94)',
              border: '1px solid rgba(255, 255, 255, 0.85)',
              borderRadius: 'var(--r-xl)',
              backdropFilter: 'blur(20px) saturate(140%)',
              WebkitBackdropFilter: 'blur(20px) saturate(140%)',
              boxShadow: '0 0 0 1px rgba(53, 177, 131, 0.18), 0 24px 54px -16px rgba(8, 32, 26, 0.16), 0 8px 24px -6px rgba(224, 166, 63, 0.12)',
            }}
            onSubmit={onSubmit}
          >
            {/* Top colorful accent stripe */}
            <div
              style={{
                position: 'absolute',
                top: 0,
                left: 0,
                right: 0,
                height: '4px',
                background: 'linear-gradient(90deg, var(--sand-500, #e0a63f) 0%, var(--leaf-400, #35b183) 35%, var(--ocean-400, #29aebd) 70%, var(--coral-500, #e4694a) 100%)',
              }}
              aria-hidden="true"
            />
            <div className="field">
              <label className="field__label" htmlFor="email">
                Email
              </label>
              <input
                id="email"
                className="input"
                type="email"
                autoComplete="username"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
              />
            </div>
            <div className="field">
              <label className="field__label" htmlFor="password">
                Password
              </label>
              <div style={{ position: 'relative', display: 'flex', alignItems: 'center' }}>
                <input
                  id="password"
                  className="input"
                  type={showPassword ? 'text' : 'password'}
                  autoComplete="current-password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  style={{ paddingRight: '2.5rem' }}
                />
                <button
                  type="button"
                  onClick={() => setShowPassword((v) => !v)}
                  style={{
                    position: 'absolute',
                    right: '0.65rem',
                    background: 'none',
                    border: 'none',
                    cursor: 'pointer',
                    padding: '0.25rem',
                    display: 'inline-flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    color: showPassword ? 'var(--forest-600, #0d9488)' : 'var(--text-muted, #64748b)',
                    transition: 'color 0.15s ease',
                  }}
                  aria-label={showPassword ? 'Hide password' : 'Show password'}
                  title={showPassword ? 'Hide password' : 'Show password'}
                >
                  {showPassword ? (
                    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                      <path d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19m-6.72-1.07a3 3 0 1 1-4.24-4.24" />
                      <line x1="1" y1="1" x2="23" y2="23" />
                    </svg>
                  ) : (
                    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                      <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z" />
                      <circle cx="12" cy="12" r="3" />
                    </svg>
                  )}
                </button>
              </div>
              <span className="field__hint">Staff login: agent@colombo.lk / Staff@123</span>
            </div>
            {error ? <div className="notice notice--error">{error}</div> : null}
            <button className="btn btn--block" type="submit" disabled={busy}>
              {busy ? 'Signing in…' : 'Sign in'}
            </button>
            <p className="field__hint" style={{ textAlign: 'center' }}>
              Customer? <Link to="/planner">Continue to the AI planner</Link>
            </p>
          </form>
        </div>
      </section>
    </>
  )
}
