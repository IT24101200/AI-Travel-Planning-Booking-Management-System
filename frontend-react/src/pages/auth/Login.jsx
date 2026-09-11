import { useState } from 'react'
import { Link, useLocation, useNavigate } from 'react-router-dom'
import { Masthead } from '../../components/layout/Masthead.jsx'
import { useAuth } from '../../lib/auth.jsx'
import { usePageTitle } from '../../lib/hooks.js'

/** Staff + customer sign-in. Demo-ready: works offline, tries the API first. */
export default function Login() {
  const { login } = useAuth()
  const navigate = useNavigate()
  const location = useLocation()
  const [email, setEmail] = useState('agent@serendibtrails.lk')
  const [password, setPassword] = useState('agent123')
  const [error, setError] = useState('')
  const [busy, setBusy] = useState(false)
  usePageTitle('Sign in')

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
      const from = location.state?.from
      if (from && from.startsWith('/staff')) {
        navigate(from, { replace: true })
      } else if (session.role === 'customer') {
        navigate('/planner', { replace: true })
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
        lede="Agents and admins sign in here. Tip: agent@serendibtrails.lk opens the approval console."
        crumbs={[{ label: 'Sign in' }]}
      />
      <section className="section" style={{ paddingTop: 0 }}>
        <div className="shell" style={{ maxWidth: '34rem' }}>
          <form className="panel panel--solid form" style={{ padding: '1.75rem' }} onSubmit={onSubmit}>
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
              <input
                id="password"
                className="input"
                type="password"
                autoComplete="current-password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
              />
              <span className="field__hint">Demo: anything 4+ chars works offline.</span>
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
