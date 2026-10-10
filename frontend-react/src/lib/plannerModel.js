export const SUPPORTED_CURRENCIES = ['LKR', 'USD']
export const MAX_NOTES = 2000
export const MAX_TRAVELLERS = 100
export const TRANSPORT_SCHEDULE_HORIZON_DAYS = 60

export const TERMINAL_TRIP_STATUSES = new Set([
  'AwaitingApproval',
  'Failed',
  'Cancelled',
  'Approved',
  'Rejected',
])

export function dateStringFromOffset(offset = 0, now = new Date()) {
  const date = new Date(now)
  date.setHours(12, 0, 0, 0)
  date.setDate(date.getDate() + offset)
  return [date.getFullYear(), String(date.getMonth() + 1).padStart(2, '0'), String(date.getDate()).padStart(2, '0')].join('-')
}

export function normalizeDestination(destination) {
  const id = Number(destination?.id)
  const name = String(destination?.name || '').trim()
  if (!Number.isInteger(id) || id <= 0 || !name) return null
  return { ...destination, id, name }
}

export function addDestination(selected, destination) {
  const normalized = normalizeDestination(destination)
  if (!normalized || selected.some((item) => Number(item.id) === normalized.id)) return selected
  return [...selected, normalized]
}

export function removeDestination(selected, destinationId) {
  const id = Number(destinationId)
  return selected.filter((item) => Number(item.id) !== id)
}

export function moveDestination(selected, index, direction) {
  const nextIndex = direction === 'up' ? index - 1 : index + 1
  if (index < 0 || index >= selected.length || nextIndex < 0 || nextIndex >= selected.length) return selected
  const next = [...selected]
  const [item] = next.splice(index, 1)
  next.splice(nextIndex, 0, item)
  return next
}

function parseDateOnly(value) {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(String(value || ''))) return null
  const [year, month, day] = value.split('-').map(Number)
  const parsed = new Date(year, month - 1, day, 12)
  return parsed.getFullYear() === year && parsed.getMonth() === month - 1 && parsed.getDate() === day
    ? parsed
    : null
}

export function validatePlannerForm(form, now = new Date()) {
  const errors = {}
  const selected = Array.isArray(form.destinations) ? form.destinations : []
  const start = parseDateOnly(form.startDate)
  const end = parseDateOnly(form.endDate)
  const today = parseDateOnly(dateStringFromOffset(0, now))
  const latestDate = parseDateOnly(dateStringFromOffset(TRANSPORT_SCHEDULE_HORIZON_DAYS, now))
  const travellerCount = Number(form.travellerCount)
  const budget = Number(form.budgetCeiling)
  const duplicateIds = selected.map((destination) => Number(destination.id))

  if (selected.length === 0) errors.destinations = 'Select at least one destination.'
  if (new Set(duplicateIds).size !== duplicateIds.length) errors.destinations = 'Choose each destination only once.'

  if (!start) errors.startDate = 'Choose a valid start date.'
  else if (start <= today) errors.startDate = 'Start date must be after today.'
  else if (start > latestDate) errors.startDate = 'Start date must be within the next 60 days.'

  if (!end) errors.endDate = 'Choose a valid end date.'
  else if (start && end <= start) errors.endDate = 'End date must be after the start date.'
  else if (end > latestDate) errors.endDate = 'End date must be within the next 60 days.'

  if (!Number.isInteger(travellerCount) || travellerCount < 1 || travellerCount > MAX_TRAVELLERS) {
    errors.travellerCount = `Travellers must be a whole number from 1 to ${MAX_TRAVELLERS}.`
  }
  if (!Number.isFinite(budget) || budget <= 0) errors.budgetCeiling = 'Budget ceiling must be greater than zero.'
  if (!SUPPORTED_CURRENCIES.includes(String(form.currency || '').toUpperCase())) {
    errors.currency = 'Choose LKR or USD.'
  }

  const notes = String(form.notes || '').trim()
  if (!notes) errors.notes = 'Add a few preferences so the agents can shape the plan.'
  else if (notes.length > MAX_NOTES) errors.notes = `Keep notes under ${MAX_NOTES} characters.`

  if (form.airportPickup) {
    if (!['CMB', 'HRI'].includes(String(form.airportCode || '').toUpperCase())) {
      errors.airportCode = 'Choose CMB or HRI.'
    }
    if (!/^([01]\d|2[0-3]):[0-5]\d$/.test(String(form.airportArrivalTime || ''))) {
      errors.airportArrivalTime = 'Enter an arrival time in 24-hour format.'
    }
  }

  if (!form.airportPickup && form.starterLocationId) {
    const starterId = Number(form.starterLocationId)
    if (!selected.some((destination) => Number(destination.id) === starterId)) {
      errors.starterLocationId = 'Starting location must be one of the selected destinations.'
    }
  }

  return errors
}

export function buildTripRequestPayload({ destinations, ...form }) {
  const ordered = destinations.map((destination, order) => ({
    id: Number(destination.id),
    name: destination.name,
    order,
  }))
  const destinationNames = ordered.map((destination) => destination.name).join(' → ')
  const origin = form.airportPickup
    ? `${form.airportCode} airport`
    : form.starterLocationId
      ? ordered.find((destination) => destination.id === Number(form.starterLocationId))?.name || 'AI optimized'
      : 'AI optimized'
  const requestText = [
    `Route origin: ${origin}.`,
    `Destinations: ${destinationNames}.`,
    `Preferences: ${String(form.notes || '').trim()}`,
  ].join(' ')

  return {
    destinationId: ordered[0]?.id ?? null,
    destinationIds: ordered.map((destination) => destination.id),
    destinations: ordered,
    starterLocationId: form.airportPickup || !form.starterLocationId ? null : Number(form.starterLocationId),
    rawRequestText: requestText.slice(0, MAX_NOTES),
    startDate: `${form.startDate}T00:00:00`,
    endDate: `${form.endDate}T00:00:00`,
    travellerCount: Number(form.travellerCount),
    budgetCeiling: Number(form.budgetCeiling),
    currency: String(form.currency || '').toUpperCase(),
    airportPickup: Boolean(form.airportPickup),
    airportCode: form.airportPickup ? String(form.airportCode || 'CMB').toUpperCase() : 'CMB',
    airportArrivalTime: form.airportPickup ? `${form.airportArrivalTime}:00` : '08:00:00',
  }
}

export function isTerminalTripStatus(status) {
  return TERMINAL_TRIP_STATUSES.has(String(status || ''))
}

export function safePlannerError(error, fallback = 'The planning service is temporarily unavailable. Please retry.') {
  const candidate = error?.response?.data?.message || error?.message
  const message = String(candidate || '').trim()
  if (!message || /stack trace|traceback|exception|apikey|api key|sql|httpclient/i.test(message)) return fallback
  return message
}

export function parsePlanJson(value) {
  if (!value) return null
  if (typeof value === 'object') return value
  if (typeof value !== 'string') return null
  try {
    const parsed = JSON.parse(value)
    return parsed && typeof parsed === 'object' ? parsed : null
  } catch {
    return null
  }
}

export function mergeAgentLogs(existing, incoming) {
  const logs = [...(Array.isArray(existing) ? existing : []), ...(Array.isArray(incoming) ? incoming : [])]
  const seen = new Set()
  return logs.filter((log, index) => {
    const key = log?.id || `${log?.timestamp || ''}-${log?.agentName || ''}-${log?.stepName || ''}-${index}`
    if (seen.has(key)) return false
    seen.add(key)
    return true
  }).sort((a, b) => String(a?.timestamp || '').localeCompare(String(b?.timestamp || '')))
}
