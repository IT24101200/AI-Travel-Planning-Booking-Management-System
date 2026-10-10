import { useEffect, useState } from 'react'
import { Link, useLocation, useNavigate } from 'react-router-dom'
import { useAuth } from '../../lib/auth.jsx'
import { usePageTitle } from '../../lib/hooks.js'

export default function CustomerLogin() {
  const { user, login, register } = useAuth()
  const navigate = useNavigate()
  const location = useLocation()
  const [mode, setMode] = useState('login')
  const [form, setForm] = useState({ fullName: '', email: '', password: '', phone: '' })
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')
  usePageTitle('Customer sign in · Serendib Trails')

  useEffect(() => {
    if (user?.token) navigate(location.state?.from || '/planner', { replace: true })
  }, [location.state, navigate, user?.token])

  if (user?.token) {
    return null
  }

  const update = (key) => (event) => setForm((current) => ({ ...current, [key]: event.target.value }))

  async function onSubmit(event) {
    event.preventDefault()
    setError('')
    if (mode === 'register' && (!form.fullName.trim() || !form.phone.trim())) {
      setError('Please enter your full name and phone number.')
      return
    }
    if (!form.email.includes('@') || form.password.length < 6) {
      setError('Use a valid email and a password with at least 6 characters.')
      return
    }
    setBusy(true)
    try {
      const session = mode === 'register'
        ? await register(form.fullName.trim(), form.email.trim(), form.password, form.phone.trim())
        : await login(form.email.trim(), form.password)
      if (!session) {
        setError('Invalid email or password.')
        return
      }
      navigate(location.state?.from || '/planner', { replace: true })
    } catch (requestError) {
      setError(requestError.message || 'Authentication failed. Please try again.')
    } finally {
      setBusy(false)
    }
  }

  return (
    <section className="section customer-auth-page">
      <div className="shell customer-auth-card panel">
        <span className="eyebrow">Serendib Trails</span>
        <h1>{mode === 'login' ? 'Sign in to plan your trip' : 'Create your traveller account'}</h1>
        <p className="lede">Your account keeps trip requests, AI progress, and proposals connected to you.</p>
        <form className="form" onSubmit={onSubmit} noValidate>
          {mode === 'register' ? (
            <>
              <div className="field">
                <label className="field__label" htmlFor="customer-full-name">Full name</label>
                <input id="customer-full-name" className="input" value={form.fullName} onChange={update('fullName')} autoComplete="name" />
              </div>
              <div className="field">
                <label className="field__label" htmlFor="customer-phone">Phone</label>
                <input id="customer-phone" className="input" value={form.phone} onChange={update('phone')} autoComplete="tel" required />
              </div>
            </>
          ) : null}
          <div className="field">
            <label className="field__label" htmlFor="customer-email">Email</label>
            <input id="customer-email" type="email" className="input" value={form.email} onChange={update('email')} autoComplete="email" required />
          </div>
          <div className="field">
            <label className="field__label" htmlFor="customer-password">Password</label>
            <input id="customer-password" type="password" className="input" value={form.password} onChange={update('password')} autoComplete={mode === 'login' ? 'current-password' : 'new-password'} required />
          </div>
          {error ? <div className="notice notice--error" role="alert">{error}</div> : null}
          <button className="btn" type="submit" disabled={busy}>
            {busy ? 'Please wait…' : mode === 'login' ? 'Sign in and plan' : 'Create account and plan'}
          </button>
        </form>
        <p className="customer-auth-card__switch">
          {mode === 'login' ? 'New traveller?' : 'Already have an account?'}{' '}
          <button type="button" className="link-button" onClick={() => { setMode(mode === 'login' ? 'register' : 'login'); setError('') }}>
            {mode === 'login' ? 'Create an account' : 'Sign in'}
          </button>
        </p>
        <p className="field__hint"><Link to="/login">Staff member? Use the staff sign-in.</Link></p>
      </div>
    </section>
  )
}
