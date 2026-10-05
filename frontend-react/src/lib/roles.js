export function normalizeRole(role) {
  const value = String(role || '').trim().toLowerCase()
  if (value === 'admin') return 'admin'
  if (value === 'travelagent') return 'travelagent'
  return 'customer'
}
