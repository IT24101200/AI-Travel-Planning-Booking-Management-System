const OFFSET_SUFFIX = /(?:Z|[+-]\d{2}:?\d{2})$/i

/**
 * Parses an API instant. New responses carry Z/offset; the no-offset fallback
 * is intentionally limited to instant fields backed by the legacy UTC storage
 * contract and must not be used for date-only or local-schedule values.
 */
export function parseInstant(value) {
  if (value instanceof Date) return Number.isNaN(value.getTime()) ? null : value
  if (value == null || String(value).trim() === '') return null
  const raw = String(value).trim()
  const date = new Date(OFFSET_SUFFIX.test(raw) ? raw : `${raw}Z`)
  return Number.isNaN(date.getTime()) ? null : date
}

export function formatLocalInstantDate(value) {
  const date = parseInstant(value)
  return date ? date.toLocaleDateString() : 'Date unavailable'
}

export function formatLocalInstantDateTime(value) {
  const date = parseInstant(value)
  return date ? date.toLocaleString() : 'Date unavailable'
}

export function formatNotificationInstant(value) {
  const date = parseInstant(value)
  if (!date) return 'Date unavailable'
  return `${date.getDate()} ${date.toLocaleString('default', { month: 'short' })} · ${String(date.getHours()).padStart(2, '0')}:${String(date.getMinutes()).padStart(2, '0')}`
}

/** Date-only formatter: reads the calendar components, never timezone-shifts them. */
export function formatDateOnly(value) {
  const match = String(value ?? '').match(/^(\d{4})-(\d{2})-(\d{2})/)
  if (!match) return 'Date unavailable'
  const date = new Date(Date.UTC(Number(match[1]), Number(match[2]) - 1, Number(match[3])))
  return date.toLocaleDateString(undefined, { timeZone: 'UTC' })
}

/**
 * Local-schedule formatter: preserves the wall-clock components from the
 * offset-less transport contract instead of interpreting them as an instant.
 */
export function formatLocalSchedule(value) {
  const match = String(value ?? '').match(/^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})/)
  if (!match) return 'Date unavailable'
  const date = new Date(Date.UTC(Number(match[1]), Number(match[2]) - 1, Number(match[3])))
  return `${date.getUTCDate()} ${date.toLocaleString('default', { month: 'short', timeZone: 'UTC' })} · ${match[4]}:${match[5]}`
}
