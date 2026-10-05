import { Navigate, useLocation } from 'react-router-dom'
import { useAuth } from '../../lib/auth.jsx'
import { normalizeRole } from '../../lib/roles.js'

/** Guards /staff/* — redirects anonymous users or customers to /login with access denied. */
export function RequireAuth({ children, roles = ['TravelAgent', 'Admin'] }) {
  const auth = useAuth()
  const location = useLocation()

  if (!auth?.user) {
    return <Navigate to="/login" replace state={{ from: location.pathname }} />
  }

  const role = normalizeRole(auth.role)
  const allowed = roles.map((value) => normalizeRole(value))
  const isStaff = allowed.includes(role)

  if (!isStaff) {
    return (
      <Navigate
        to="/login"
        replace
        state={{ error: 'Access denied: Customer accounts cannot access the staff management console.' }}
      />
    )
  }

  return children
}
