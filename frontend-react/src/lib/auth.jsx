import { createContext, useCallback, useContext, useMemo, useState } from 'react'

const AuthContext = createContext(null)

function roleFromEmail(email) {
  const e = (email || '').toLowerCase()
  if (e.includes('admin')) return 'admin'
  if (e.includes('agent') || e.includes('staff') || e.includes('colombo')) return 'agent'
  return 'customer'
}

/**
 * Minimal JWT-style auth for the assignment demo.
 * - Real backend: POST /api/Auth/login returns { token, role } — we store it.
 * - Offline/demo: any email + 4-char password creates a local session so the
 *   staff console is reviewable without the API running.
 */
export function AuthProvider({ children }) {
  const [session, setSession] = useState(() => {
    try {
      const raw = localStorage.getItem('st_session')
      return raw ? JSON.parse(raw) : null
    } catch {
      return null
    }
  })

  const login = useCallback(async (email, password) => {
    const base = import.meta.env.VITE_API_BASE_URL ?? 'http://localhost:5000/api'
    // Try the real API first; fall back to demo session on network failure.
    try {
      const res = await fetch(`${base}/Auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password }),
      })
      if (res.ok) {
        const data = await res.json()
        const next = {
          email,
          token: data.token || data.accessToken || 'api-token',
          role: (data.role || roleFromEmail(email)).toLowerCase(),
        }
        localStorage.setItem('st_session', JSON.stringify(next))
        localStorage.setItem('accessToken', next.token)
        setSession(next)
        return next
      }
    } catch {
      // offline — fall through to demo login
    }
    const next = { email, token: 'demo-token', role: roleFromEmail(email) }
    localStorage.setItem('st_session', JSON.stringify(next))
    localStorage.setItem('accessToken', next.token)
    setSession(next)
    return next
  }, [])

  const logout = useCallback(() => {
    localStorage.removeItem('st_session')
    localStorage.removeItem('accessToken')
    setSession(null)
  }, [])

  const value = useMemo(
    () => ({ user: session, role: session?.role ?? null, login, logout }),
    [session, login, logout],
  )

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}

export function useAuth() {
  return useContext(AuthContext)
}
