import axios from 'axios'

/**
 * Thin axios wrapper for the ASP.NET backend.
 *
 * Note: /api/destination and /api/tour are [Authorize]-protected, so the public
 * marketing site renders from src/data/*. Only the planner talks to the API,
 * and it degrades gracefully when the backend is not running.
 */
const baseURL = import.meta.env.VITE_API_BASE_URL ?? 'http://localhost:5000/api'

export const api = axios.create({
  baseURL,
  timeout: 12000,
  headers: { 'Content-Type': 'application/json' },
})

api.interceptors.request.use((config) => {
  // Set by the agent/admin console after login; absent for anonymous visitors.
  const token = localStorage.getItem('accessToken')
  if (token) config.headers.Authorization = `Bearer ${token}`
  return config
})

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

/** GET /api/Destination - requires a signed-in agent. */
export async function fetchDestinations() {
  const { data } = await api.get('/Destination')
  return data
}

// ─────────────────────────────────────────────────────────────
// Student A — Customer & Notification API endpoints
// ─────────────────────────────────────────────────────────────

export async function fetchCustomers() {
  const { data } = await api.get('/Customer')
  return data
}

export async function fetchNotifications() {
  const { data } = await api.get('/Notification')
  return data
}

export async function resendNotification(id) {
  const { data } = await api.post(`/Notification/${id}/resend`)
  return data
}

// ─────────────────────────────────────────────────────────────
// Student B — Tours & Itineraries API endpoints
// ─────────────────────────────────────────────────────────────

export async function fetchTours() {
  const { data } = await api.get('/Tour')
  return data
}

export async function createTour(tour) {
  const { data } = await api.post('/Tour', tour)
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

// ─────────────────────────────────────────────────────────────
// Student C — Hotels & Transport API endpoints
// ─────────────────────────────────────────────────────────────

export async function fetchHotels(search) {
  const { data } = await api.get('/Hotel', { params: { search } })
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

export async function fetchTransport(type, search) {
  const { data } = await api.get('/Transport', { params: { type, search } })
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
  const { data } = await api.post(`/Approval/${bookingId}/decide`, {
    decision,
    comment,
  })
  return data
}

export async function fetchBookings() {
  const { data } = await api.get('/Booking')
  return data
}

export async function fetchPayments(status) {
  const { data } = await api.get('/Payment', { params: { status } })
  return data
}

export async function fetchRevenueSummary() {
  const { data } = await api.get('/Payment/revenue-summary')
  return data
}

