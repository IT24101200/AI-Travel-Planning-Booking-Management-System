/** Convert transport-management failures to safe staff-facing messages. */
export function transportErrorMessage(error, fallback = 'Unable to load transport data. Please retry.') {
  const status = error?.response?.status
  const code = error?.response?.data?.code

  if (status === 401) return 'Your staff session has expired. Please sign in again.'
  if (status === 403) return 'You do not have permission to manage transport catalogue data.'
  if (status === 404) return 'The requested transport option was not found.'
  if (status === 409) {
    if (code === 'TRANSPORT_CAPACITY_CONFLICT') {
      return 'Capacity cannot be reduced below seats already reserved.'
    }
    return 'This transport option is used by existing bookings and cannot be deleted.'
  }
  if (status === 400) return error?.response?.data?.message || 'Please check the transport details and try again.'
  if (status === 408 || status === 504 || error?.code === 'ECONNABORTED') {
    return 'The transport service took too long to respond. Please retry.'
  }
  if (status >= 500 || error?.code === 'ERR_NETWORK' || !error?.response) {
    return 'The transport service is temporarily unavailable. Please retry.'
  }
  return fallback
}
