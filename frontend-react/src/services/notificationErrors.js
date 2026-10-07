/**
 * Convert notification API failures to safe user-facing text.
 *
 * Notification pages must not render arbitrary backend response bodies or
 * Axios/network exception text because those values can contain implementation
 * details, HTML, or infrastructure errors.
 */
export function notificationErrorMessage(error, fallback = 'Unable to load notifications. Please retry.') {
  const status = error?.response?.status
  if (status === 401) return 'Your session has expired. Please sign in again.'
  if (status === 403) return 'You do not have permission to manage notifications.'
  if (status === 404) return 'The requested notification was not found.'
  if (status === 408 || status === 504 || error?.code === 'ECONNABORTED') {
    return 'The notification service took too long to respond. Please retry.'
  }
  if (status >= 500 || error?.code === 'ERR_NETWORK' || !error?.response) {
    return 'The notification service is temporarily unavailable. Please retry.'
  }
  return fallback
}
