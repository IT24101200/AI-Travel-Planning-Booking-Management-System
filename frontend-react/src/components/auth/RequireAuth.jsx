import { Navigate, useLocation } from 'react-router-dom'
import { useAuth } from '../../lib/auth.jsx'
import { normalizeRole } from '../../lib/roles.js'

/** Guards a route while allowing the caller to choose its sign-in destination. */
export function RequireAuth({ children, roles = ['TravelAgent', 'Admin'], loginPath = '/login' }) {
  const auth = useAuth()
  const location = useLocation()

  if (!auth?.user) {
    return <Navigate to={loginPath} replace state={{ from: location.pathname }} />
  }

  const role = normalizeRole(auth.role)
  const allowed = roles.map((value) => normalizeRole(value))
  const isStaff = allowed.includes(role)

  if (!isStaff) {
    return (
      <Navigate
        to={loginPath}
        replace
        state={{ error: 'Access denied: Customer accounts cannot access the staff management console.' }}
      />
    )
  }

  return children
}
