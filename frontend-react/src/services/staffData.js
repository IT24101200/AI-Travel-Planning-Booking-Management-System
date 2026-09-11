/**
 * Demo dataset for the staff console (mirrors the backend shapes in §4).
 * Live API is attempted by the pages; this keeps every table usable offline
 * for marking and viva walkthroughs.
 */
export const mockCustomers = [
  { id: 1, name: 'Priya Raghavan', email: 'priya@example.com', joinedAt: '2025-11-02', trips: 3, lastActive: '2026-09-02' },
  { id: 2, name: 'Tom Whitfield', email: 'tom@example.co.uk', joinedAt: '2025-08-14', trips: 2, lastActive: '2026-08-28' },
  { id: 3, name: 'Lena Brandt', email: 'lena@example.de', joinedAt: '2026-01-20', trips: 1, lastActive: '2026-09-05' },
  { id: 4, name: 'Amal Perera', email: 'amal@example.lk', joinedAt: '2026-03-11', trips: 4, lastActive: '2026-09-07' },
  { id: 5, name: 'Sofia Almeida', email: 'sofia@example.com', joinedAt: '2026-05-30', trips: 1, lastActive: '2026-08-15' },
  { id: 6, name: 'Daniel Kim', email: 'daniel@example.com', joinedAt: '2026-06-18', trips: 2, lastActive: '2026-09-01' },
]

export const mockNotifications = [
  { id: 101, recipient: 'priya@example.com', channel: 'Email', type: 'Itinerary ready', status: 'Sent', at: '2026-09-03 10:12' },
  { id: 102, recipient: 'tom@example.co.uk', channel: 'SMS', type: 'Payment link', status: 'Sent', at: '2026-09-02 16:40' },
  { id: 103, recipient: 'lena@example.de', channel: 'InApp', type: 'Approval update', status: 'Pending', at: '2026-09-05 09:02' },
  { id: 104, recipient: 'amal@example.lk', channel: 'Email', type: 'Invoice', status: 'Failed', at: '2026-09-04 11:25' },
  { id: 105, recipient: 'sofia@example.com', channel: 'Email', type: 'Trip reminder', status: 'Sent', at: '2026-09-01 08:00' },
]

export const mockTours = [
  { id: 1, name: 'Lion Rock sunrise climb', destination: 'Sigiriya', price: 45, duration: '4 hrs', category: 'Heritage', status: 'Active' },
  { id: 2, name: 'Kandy–Ella rail leg', destination: 'Ella', price: 34, duration: '7 hrs', category: 'Rail journey', status: 'Active' },
  { id: 3, name: 'Dawn leopard safari', destination: 'Yala', price: 78, duration: '5 hrs', category: 'Safari', status: 'Active' },
  { id: 4, name: 'Blue whale expedition', destination: 'Mirissa', price: 62, duration: '4 hrs', category: 'Marine', status: 'Active' },
  { id: 5, name: 'Pedro Estate tea morning', destination: 'Nuwara Eliya', price: 28, duration: '3 hrs', category: 'Tea', status: 'Inactive' },
  { id: 6, name: 'Pigeon Island snorkel', destination: 'Trincomalee', price: 40, duration: '3 hrs', category: 'Snorkelling', status: 'Active' },
]

export const mockItineraries = [
  {
    id: 'IT-2401',
    customer: 'Priya Raghavan',
    title: '5 days · Kandy → Ella → Mirissa',
    status: 'Proposed',
    days: [
      { day: 1, items: ['Temple of the Tooth evening puja', 'Kandy lake walk'] },
      { day: 2, items: ['Peradeniya gardens', 'Kandy–Ella rail leg'] },
      { day: 3, items: ['Nine Arches Bridge', 'Little Adam’s Peak'] },
      { day: 4, items: ['Drive to Mirissa', 'Coconut Tree Hill sunset'] },
      { day: 5, items: ['Blue whale expedition'] },
    ],
  },
  {
    id: 'IT-2402',
    customer: 'Tom Whitfield',
    title: '4 days · Sigiriya → Kandy',
    status: 'Draft',
    days: [
      { day: 1, items: ['Lion Rock sunrise climb', 'Village safari'] },
      { day: 2, items: ['Dambulla caves', 'Drive to Kandy'] },
    ],
  },
]

export const mockHotels = [
  { id: 1, name: 'Tea Mist Bungalow', location: 'Nuwara Eliya', stars: 4, priceNight: 132, rooms: 18, status: 'Active' },
  { id: 2, name: 'Coconut Bay Resort', location: 'Mirissa', stars: 4, priceNight: 168, rooms: 42, status: 'Active' },
  { id: 3, name: 'Rock View Lodge', location: 'Sigiriya', stars: 3, priceNight: 96, rooms: 24, status: 'Active' },
  { id: 4, name: 'Highland Rest', location: 'Ella', stars: 3, priceNight: 88, rooms: 12, status: 'Inactive' },
]

export const mockTransport = [
  { id: 1, type: 'Train', provider: 'Sri Lanka Railways', from: 'Kandy', to: 'Ella', price: 34, capacity: 120 },
  { id: 2, type: 'Car', provider: 'Serendib Drivers', from: 'Colombo', to: 'Sigiriya', price: 90, capacity: 4 },
  { id: 3, type: 'Bus', provider: 'Southern Express', from: 'Colombo', to: 'Mirissa', price: 18, capacity: 45 },
  { id: 4, type: 'Flight', provider: 'Cinnamon Air', from: 'Colombo', to: 'Trincomalee', price: 140, capacity: 8 },
]

export const mockBookings = [
  {
    id: 'B-9001',
    reference: 'ST-2026-9001',
    customer: 'Priya Raghavan',
    summary: '5 days · 2 travellers · Kandy/Ella/Mirissa',
    total: 1480,
    requested: '2026-09-03',
    status: 'AwaitingApproval',
    trail: [
      { agent: 'Coordinator', text: 'Built plan: Kandy → Ella → Mirissa, 5 days, ceiling $1,600.' },
      { agent: 'Itinerary', text: 'Day-by-day assembled, no time overlaps.' },
      { agent: 'Booking', text: 'Rooms + rail seats available for exact dates.' },
      { agent: 'Validation', text: 'Total $1,480 ≤ $1,600 ceiling. Awaiting human sign-off.' },
    ],
  },
  {
    id: 'B-9002',
    reference: 'ST-2026-9002',
    customer: 'Tom Whitfield',
    summary: '4 days · 4 travellers · Sigiriya/Kandy',
    total: 1120,
    requested: '2026-09-02',
    status: 'AwaitingApproval',
    trail: [
      { agent: 'Coordinator', text: 'Built plan: Sigiriya → Kandy, 4 days.' },
      { agent: 'Itinerary', text: 'Climb moved to sunrise to avoid heat.' },
      { agent: 'Booking', text: 'Villa rooms held, driver assigned.' },
      { agent: 'Validation', text: 'Total $1,120 within budget. Awaiting human sign-off.' },
    ],
  },
  {
    id: 'B-8990',
    reference: 'ST-2026-8990',
    customer: 'Amal Perera',
    summary: '3 days · 2 travellers · Yala/Mirissa',
    total: 860,
    requested: '2026-08-27',
    status: 'Confirmed',
    trail: [{ agent: 'Validation', text: 'Approved by agent K. Fernando on 2026-08-28.' }],
  },
]

export const mockPayments = [
  { id: 'P-5001', reference: 'ST-2026-8990', customer: 'Amal Perera', amount: 860, status: 'Paid', date: '2026-08-28' },
  { id: 'P-5002', reference: 'ST-2026-9001', customer: 'Priya Raghavan', amount: 1480, status: 'Pending', date: '2026-09-03' },
  { id: 'P-5003', reference: 'ST-2026-9002', customer: 'Tom Whitfield', amount: 1120, status: 'Pending', date: '2026-09-02' },
  { id: 'P-4990', reference: 'ST-2026-8970', customer: 'Lena Brandt', amount: 640, status: 'Refunded', date: '2026-08-20' },
]

/** Tiny local-storage-backed store so staff CRUD survives refresh in demos. */
export function loadStore(key, fallback) {
  try {
    const raw = localStorage.getItem(`st_store_${key}`)
    if (raw) return JSON.parse(raw)
  } catch {
    // ignore
  }
  return fallback
}

export function saveStore(key, value) {
  try {
    localStorage.setItem(`st_store_${key}`, JSON.stringify(value))
  } catch {
    // ignore
  }
}
