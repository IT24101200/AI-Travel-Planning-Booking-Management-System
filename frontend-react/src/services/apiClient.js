import axios from 'axios'
export { notificationErrorMessage } from './notificationErrors.js'

/**
 * Thin axios wrapper for the ASP.NET backend.
 *
 * Note: /api/destination and /api/tour are [Authorize]-protected, so the public
 * marketing site renders from src/data/*. Only the planner talks to the API,
 * and it degrades gracefully when the backend is not running.
 */
const viteEnv = import.meta.env || {}
const baseURL = viteEnv.VITE_API_BASE_URL
  || (viteEnv.DEV
    ? 'http://localhost:5138/api'
    : 'https://ai-travel-planning-booking-backend.onrender.com/api')

export const api = axios.create({
  baseURL,
  timeout: 12000,
})

api.interceptors.request.use((config) => {
  // Set by the agent/admin console after login; absent for anonymous visitors.
  const token = localStorage.getItem('accessToken')
  if (token) config.headers.Authorization = `Bearer ${token}`
  return config
})

// Auto-handle expired or invalid JWT tokens gracefully
api.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) {
      // Clear expired credentials
      localStorage.removeItem('accessToken')
      localStorage.removeItem('st_session')
      // If inside staff portal, redirect to login with expiry notice
      if (typeof window !== 'undefined' && window.location.pathname.startsWith('/staff')) {
        window.location.href = '/login?expired=1'
      }
    }
    return Promise.reject(error)
  }
)

/** Shapes the form state into the backend's TripRequestCreateDto. */
export function toTripRequestDto(form) {
  // The site's destination ids are slugs, not database keys, so only send a real
  // integer through; otherwise the place is carried in rawRequestText instead.
  const destinationId = Number.parseInt(form.destinationId, 10)

  return {
    destinationId: Number.isNaN(destinationId) ? null : destinationId,
    rawRequestText: form.notes.trim(),
    startDate: new Date(form.startDate).toISOString(),
    endDate: new Date(form.endDate).toISOString(),
    travellerCount: Number(form.travellers),
    budgetCeiling: Number(form.budget),
    currency: form.currency,
  }
}

/** POST /api/TripRequest */
export async function submitTripRequest(form) {
  const { data } = await api.post('/TripRequest', toTripRequestDto(form))
  return data
}

/** GET /api/Destination - fetch destinations */
export async function fetchDestinations() {
  const { data } = await api.get('/Destination')
  return data
}

/** POST /api/Destination - create destination */
export async function createDestination(dest) {
  const { data } = await api.post('/Destination', dest)
  return data
}

/** PUT /api/Destination/{id} - update destination */
export async function updateDestination(id, dest) {
  const { data } = await api.put(`/Destination/${id}`, dest)
  return data
}

/** DELETE /api/Destination/{id} - delete destination */
export async function deleteDestination(id) {
  const { data } = await api.delete(`/Destination/${id}`)
  return data
}

// ─────────────────────────────────────────────────────────────
// Student A — Customer & Notification API endpoints
// ─────────────────────────────────────────────────────────────

export async function fetchCustomers(params = {}) {
  const { data } = await api.get('/Customer', { params: { pageSize: 50, ...params } })
  return data
}

/** Fetch every directory page while preserving the backend's count contract. */
export async function fetchAllCustomers(params = {}) {
  const pageSize = Math.min(50, Math.max(1, Number(params.pageSize) || 50))
  const records = []
  let page = 1
  let totalCount

  while (true) {
    const response = await fetchCustomers({ ...params, page, pageSize })
    const current = Array.isArray(response) ? response : (response?.data || [])
    records.push(...current)
    totalCount = Number(response?.totalCount) || totalCount || records.length
    const totalPages = Array.isArray(response) ? 1 : Math.max(1, Number(response?.totalPages) || 1)
    if (Array.isArray(response) || page >= totalPages) break
    page += 1
  }

  return { data: records, totalCount }
}

export async function updateCustomer(id, data) {
  const { data: res } = await api.put(`/Customer/${id}`, data)
  return res
}

export async function registerStaff(staffData) {
  const { data } = await api.post('/auth/register-staff', staffData)
  return data
}

export async function deleteCustomer(id) {
  const { data } = await api.delete(`/Customer/${id}`)
  return data
}

export async function fetchNotifications() {
  const all = []
  let page = 1
  let responseData
  let hasMorePages

  do {
    const { data } = await api.get('/Notification', { params: { page, pageSize: 100 } })
    responseData = data
    const current = Array.isArray(data) ? data : (data?.data || [])
    all.push(...current)
    const totalPages = Math.max(1, Number(data?.totalPages) || page)
    page += 1
    hasMorePages = !Array.isArray(responseData) && page <= totalPages
  } while (hasMorePages)

  return Array.isArray(responseData) ? all : { ...responseData, data: all }
}

export async function resendNotification(id) {
  const { data } = await api.post(`/Notification/${id}/resend`)
  return data
}

export async function sendNotification(payload) {
  const { data } = await api.post('/Notification/send', payload)
  return data
}


// ─────────────────────────────────────────────────────────────
// Student B — Tours & Itineraries API endpoints
// ─────────────────────────────────────────────────────────────

export async function fetchTours(params) {
  const { data } = await api.get('/Tour', { params })
  return data
}

export async function createTour(tour, image) {
  const formData = new FormData()
  const { imageUrl, ...tourFields } = tour
  Object.entries(tourFields).forEach(([key, value]) => {
    if (value !== null && value !== undefined) formData.append(key, value)
  })
  // Set this explicitly after the other fields so a selected media-library
  // URL is always present in the multipart request sent to ASP.NET Core.
  if (typeof imageUrl === 'string' && imageUrl.trim()) {
    formData.set('imageUrl', imageUrl.trim())
  }
  if (image) formData.append('image', image)
  // Do not set Content-Type manually. The browser must add the multipart
  // boundary that ASP.NET Core uses to parse the form and uploaded file.
  const { data } = await api.post('/Tour', formData)
  return data
}

export async function fetchItinerariesForReview() {
  const { data } = await api.get('/Itinerary/review')
  return data
}

export async function updateItineraryStatus(id, status, notes) {
  const { data } = await api.patch(`/Itinerary/${id}/status`, { status, notes })
  return data
}

export async function removeItineraryItem(itineraryId, itemId) {
  const { data } = await api.delete(`/Itinerary/${itineraryId}/items/${itemId}`)
  return data
}

export async function addItineraryItem(itineraryId, item) {
  const { data } = await api.post(`/Itinerary/${itineraryId}/items`, item)
  return data
}

// ─────────────────────────────────────────────────────────────
// Student C — Hotels & Transport API endpoints
// ─────────────────────────────────────────────────────────────

export async function fetchHotels(search, status = 'All') {
  const { data } = await api.get('/Hotel', { params: { search, status, page: 1, pageSize: 50 } })
  return data
}

export async function createHotel(hotel) {
  const { data } = await api.post('/Hotel', hotel)
  return data
}

export async function deleteHotel(id) {
  const { data } = await api.delete(`/Hotel/${id}`)
  return data
}

export function buildTransportQuery(params = {}) {
  const query = {
    type: params.type && params.type !== 'All' ? params.type : undefined,
    routeFrom: params.routeFrom?.trim() || undefined,
    routeTo: params.routeTo?.trim() || undefined,
    minPrice: params.minPrice,
    maxPrice: params.maxPrice,
    status: params.status || 'All',
    sortBy: params.sortBy || undefined,
    descending: params.descending === true ? true : undefined,
    page: Math.max(1, Number(params.page) || 1),
    pageSize: Math.min(50, Math.max(1, Number(params.pageSize) || 10)),
    currency: params.currency || undefined
  }
  return Object.fromEntries(Object.entries(query).filter(([, value]) => value !== undefined && value !== ''))
}

export async function fetchTransport(params = {}) {
  const { data } = await api.get('/Transport', { params: buildTransportQuery(params) })
  return data
}

export async function fetchTransportCoverage(params = {}) {
  const { data } = await api.get('/Transport/coverage', {
    params: {
      routeFrom: params.routeFrom?.trim(),
      routeTo: params.routeTo?.trim(),
      startDate: params.startDate,
      endDate: params.endDate,
      travellers: params.travellers
    }
  })
  return data
}

export async function createTransport(transport) {
  const { data } = await api.post('/Transport', transport)
  return data
}

export async function deleteTransport(id) {
  const { data } = await api.delete(`/Transport/${id}`)
  return data
}

// ─────────────────────────────────────────────────────────────
// Student D — Bookings, Approvals & Payments API endpoints
// ─────────────────────────────────────────────────────────────

export async function fetchPendingApprovals() {
  const { data } = await api.get('/Approval/pending')
  return data
}

export async function decideApproval(bookingId, decision, comment) {
  const DECISION_MAP = {
    Approved: 0,
    Rejected: 1,
    RevisionRequested: 2,
  }
  const numericDecision = typeof decision === 'string' && decision in DECISION_MAP
    ? DECISION_MAP[decision]
    : decision

  const { data } = await api.post('/Approval', {
    bookingId: Number(bookingId),
    decision: numericDecision,
    comment: comment || '',
  })
  return data
}

export async function fetchBookings(params = {}) {
  const { data } = await api.get('/Booking', { params })
  return data
}

export async function fetchCustomerTrips(customerId) {
  try {
    const { data } = await api.get('/TripRequest/search', { params: { customerId } })
    return data
  } catch {
    return []
  }
}

export async function fetchPayments(status) {
  const { data } = await api.get('/Payment', { params: { status } })
  return data
}

export async function fetchRevenueSummary() {
  const { data } = await api.get('/Payment/revenue-report')
  return data
}

// ─────────────────────────────────────────────────────────────
// Update endpoints — needed for Edit functionality (spec §5)
// ─────────────────────────────────────────────────────────────

export async function updateTour(id, tour) {
  const payload = tour.defaultStartTime?.length === 5
    ? { ...tour, defaultStartTime: `${tour.defaultStartTime}:00` }
    : tour
  const { data } = await api.put(`/Tour/${id}`, payload)
  return data
}

export async function deleteTour(id) {
  const { data } = await api.delete(`/Tour/${id}`)
  return data
}

export async function updateHotel(id, hotel) {
  const { data } = await api.put(`/Hotel/${id}`, hotel)
  return data
}

export async function updateHotelStatus(id, status) {
  const { data } = await api.patch(`/Hotel/${id}/status`, { status })
  return data
}

export async function updateTransport(id, transport) {
  const { data } = await api.put(`/Transport/${id}`, transport)
  return data
}

// Agent log trail — shown alongside bookings in the approval dashboard
export async function fetchAgentLogs(tripRequestId) {
  const { data } = await api.get(`/TripRequest/${tripRequestId}/logs`)
  return data
}

// ─────────────────────────────────────────────────────────────
// Staff Media Management API endpoints
// Note: Strictly manages catalog images (Tours, Destinations, Hotels, Fleet).
// User profile images are not managed or retrieved here.
// ─────────────────────────────────────────────────────────────

export async function uploadMedia(file, category = 'general') {
  const formData = new FormData()
  formData.append('file', file)
  const { data } = await api.post(`/Media/upload?category=${encodeURIComponent(category)}`, formData)
  return data
}

export async function fetchMedia(category, search) {
  const params = {}
  if (category && category !== 'all') params.category = category
  if (search) params.search = search
  const { data } = await api.get('/Media', { params })
  return data
}

export async function deleteMedia(url) {
  const { data } = await api.delete('/Media', { params: { url } })
  return data
}

