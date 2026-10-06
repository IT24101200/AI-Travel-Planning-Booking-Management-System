import { Navigate, useLocation } from 'react-router-dom'
import { useAuth } from '../../lib/auth.jsx'

/** Guards /staff/* — redirects anonymous users or customers to /login with access denied. */
export function RequireAuth({ roles = ['staff', 'admin', 'agent', 'travelagent'], children }) {
  const auth = useAuth()
  const location = useLocation()

  if (!auth?.user) {
    return <Navigate to="/login" replace state={{ from: location.pathname }} />
  }

  const role = (auth.role || '').toLowerCase()
  const isStaff = role === 'staff' || role === 'admin' || role === 'agent' || role === 'travelagent'

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
