export const TRANSPORT_PAGE_SIZE = 10
export const SUPPORTED_TRANSPORT_CURRENCIES = ['LKR', 'USD']

const COVERAGE_MESSAGES = {
  COVERAGE_AVAILABLE: 'Matching active transport is available for this route and date range.',
  NO_ROUTE: 'No active transport exists for this route.',
  NO_DATE_MATCH: 'Transport exists for this route, but not in the selected date range.',
  NO_CAPACITY: 'Matching transport exists, but none supports this traveller count.',
  NO_AVAILABILITY: 'Matching departures exist but currently have insufficient available seats.'
}

export function normalizeTransportRouteName(value) {
  return String(value || '').trim().replace(/\s+/g, ' ').toLocaleLowerCase()
}

export function validateTransportForm(form) {
  if (!form.type || !String(form.provider || '').trim()) {
    return 'Transport type and provider are required.'
  }
  if (!String(form.from || '').trim() || !String(form.to || '').trim()) {
    return 'Route origin and destination are required.'
  }
  if (normalizeTransportRouteName(form.from) === normalizeTransportRouteName(form.to)) {
    return 'Route origin and destination must be different.'
  }
  if (!form.departureTime || !form.arrivalTime) {
    return 'Departure and arrival times are required.'
  }

  const departure = new Date(form.departureTime)
  const arrival = new Date(form.arrivalTime)
  if (Number.isNaN(departure.getTime()) || Number.isNaN(arrival.getTime()) || arrival <= departure) {
    return 'Arrival must be later than departure.'
  }
  if (!Number.isInteger(Number(form.capacity)) || Number(form.capacity) < 1 || Number(form.capacity) > 1000) {
    return 'Capacity must be a whole number between 1 and 1000.'
  }
  if (!Number.isFinite(Number(form.price)) || Number(form.price) < 0) {
    return 'Price must be zero or greater.'
  }
  if (!SUPPORTED_TRANSPORT_CURRENCIES.includes(String(form.currency || '').toUpperCase())) {
    return 'Currency must be LKR or USD.'
  }
  return null
}

export function buildTransportPayload(form) {
  return {
    type: form.type,
    provider: String(form.provider || '').trim(),
    routeFrom: String(form.from || '').trim(),
    routeTo: String(form.to || '').trim(),
    price: Number(form.price),
    capacity: Number(form.capacity),
    currency: String(form.currency || '').toUpperCase(),
    status: form.status,
    departureTime: form.departureTime,
    arrivalTime: form.arrivalTime,
    imageUrl: form.imageUrl || ''
  }
}

export function getCoveragePresentation(coverage) {
  const reasonCode = coverage?.reasonCode || 'NO_AVAILABILITY'
  return {
    reasonCode,
    message: COVERAGE_MESSAGES[reasonCode] || 'No matching active transport coverage was found.',
    status: Number(coverage?.availableMatches) > 0 ? 'Available' : 'Unavailable',
    totalActive: Number(coverage?.totalActive) || 0,
    routeMatches: Number(coverage?.routeMatches) || 0,
    dateMatches: Number(coverage?.dateMatches) || 0,
    capacityMatches: Number(coverage?.capacityMatches) || 0,
    availableMatches: Number(coverage?.availableMatches) || 0
  }
}

export function normalizeTransportResponse(payload) {
  if (Array.isArray(payload)) {
    return {
      data: payload,
      page: 1,
      pageSize: payload.length || TRANSPORT_PAGE_SIZE,
      totalCount: payload.length,
      totalPages: 1
    }
  }
  const data = Array.isArray(payload?.data) ? payload.data : []
  const page = Math.max(1, Number(payload?.page) || 1)
  const pageSize = Math.max(1, Number(payload?.pageSize) || TRANSPORT_PAGE_SIZE)
  const totalCount = Math.max(0, Number(payload?.totalCount) || 0)
  return {
    data,
    page,
    pageSize,
    totalCount,
    totalPages: Math.max(1, Number(payload?.totalPages) || Math.ceil(totalCount / pageSize) || 1)
  }
}

export function transportPageRange(page, pageSize, totalCount) {
  const total = Math.max(0, Number(totalCount) || 0)
  if (total === 0) return { from: 0, to: 0 }
  const currentPage = Math.max(1, Number(page) || 1)
  const size = Math.max(1, Number(pageSize) || TRANSPORT_PAGE_SIZE)
  return {
    from: (currentPage - 1) * size + 1,
    to: Math.min(currentPage * size, total)
  }
}
