import { createContext, useCallback, useContext, useMemo, useState } from 'react'
import { normalizeRole } from './roles.js'

const AuthContext = createContext(null)

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
      const parsed = raw ? JSON.parse(raw) : null
      // Clear out obsolete demo-tokens so they do not trigger 401s on backend calls
      if (parsed?.token === 'demo-token') {
        localStorage.removeItem('st_session')
        localStorage.removeItem('accessToken')
        return null
      }
      return parsed
    } catch {
      return null
    }
  })

  const login = useCallback(async (email, password) => {
    const base = import.meta.env.VITE_API_BASE_URL || (import.meta.env.DEV ? 'http://localhost:5138/api' : '')
    try {
      const res = await fetch(`${base}/Auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password }),
      })
      if (res.ok) {
        const data = await res.json()
        const normalizedRole = normalizeRole(data.role)
        const next = {
          email,
          userId: data.userId || null,
          fullName: data.fullName || null,
          token: data.token || data.accessToken,
          role: normalizedRole,
        }
        localStorage.setItem('st_session', JSON.stringify(next))
        localStorage.setItem('accessToken', next.token)
        setSession(next)
        return next
      }
      return null
    } catch {
      return null
    }
  }, [])

  const register = useCallback(async (fullName, email, password, phone = '') => {
    const base = import.meta.env.VITE_API_BASE_URL || (import.meta.env.DEV ? 'http://localhost:5138/api' : '')
    const res = await fetch(`${base}/Auth/register`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ fullName, email, password, phone }),
    })
    const data = await res.json().catch(() => ({}))
    if (!res.ok) {
      const error = new Error(data.message || 'Registration failed.')
      error.status = res.status
      throw error
    }

    const next = {
      email,
      userId: data.userId || null,
      fullName: data.fullName || fullName,
      token: data.token || data.accessToken,
      role: 'customer',
    }
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
    () => ({ user: session, role: session?.role ?? null, login, register, logout }),
    [session, login, register, logout],
  )

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}

// The provider and hook intentionally share this module as one auth boundary.
// eslint-disable-next-line react-refresh/only-export-components
export function useAuth() {
  return useContext(AuthContext)
}
