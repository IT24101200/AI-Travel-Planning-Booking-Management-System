import { Navigate, useLocation } from 'react-router-dom'
import { useAuth } from '../../lib/auth.jsx'

/** Guards /staff/* — redirects anonymous users to /login. */
export function RequireAuth({ roles = [], children }) {
  const auth = useAuth()
  const location = useLocation()

  if (!auth?.user) {
    return <Navigate to="/login" replace state={{ from: location.pathname }} />
  }
  if (roles.length && !roles.includes(auth.role) && auth.role !== 'admin') {
    return <Navigate to="/" replace />
  }
  return children
}
