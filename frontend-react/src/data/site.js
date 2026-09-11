/** Static site copy: navigation, proof points, process, reviews. */

export const brand = {
  name: 'Serendib Trails',
  kicker: 'Sri Lanka · Since 2016',
  phone: '+94 11 234 5678',
  email: 'hello@serendibtrails.lk',
  address: '18 Galle Face Terrace, Colombo 00300, Sri Lanka',
}

export const navLinks = [
  { to: '/', label: 'Home' },
  { to: '/destinations', label: 'Destinations' },
  { to: '/experiences', label: 'Experiences' },
  { to: '/planner', label: 'AI Planner' },
  { to: '/about', label: 'About' },
  { to: '/contact', label: 'Contact' },
]

export const stats = [
  { value: 12, suffix: 'k+', label: 'Itineraries planned' },
  { value: 48, suffix: '', label: 'Local guides on the ground' },
  { value: 9, suffix: '', label: 'Provinces covered' },
  { value: 4.9, suffix: '/5', label: 'Average traveller rating', decimals: 1 },
]

export const steps = [
  {
    title: 'Tell us the shape of it',
    body: 'Dates, budget ceiling, how many of you, and what you actually want out of the trip — in your own words.',
  },
  {
    title: 'Agents draft the route',
    body: 'Our planner reads the request, then itinerary, booking and validation agents work out a day-by-day route that survives real distances.',
  },
  {
    title: 'A human checks it',
    body: 'A Colombo-based travel agent reviews every plan for road time, monsoon timing and permit reality before it reaches you.',
  },
  {
    title: 'Confirm and go',
    body: 'Approve the plan and we hold the rooms, drivers and park permits. One invoice, one point of contact.',
  },
]

export const agents = [
  { name: 'Itinerary agent', role: 'Sequences days against real driving times and opening hours.' },
  { name: 'Booking agent', role: 'Checks live availability for rooms, drivers and park permits.' },
  { name: 'Validation agent', role: 'Flags monsoon clashes, budget overruns and impossible transfers.' },
  { name: 'Human agent', role: 'A Colombo travel agent signs off before anything is confirmed.' },
]

export const testimonials = [
  {
    quote:
      'We asked for “hill country, no early starts, good coffee” and got a plan that actually respected it. The validation notes about east-coast monsoon saved our second week.',
    name: 'Priya Raghavan',
    from: 'Bengaluru, India',
    rating: 5,
  },
  {
    quote:
      'Nine days, two kids, one driver who became part of the family. The day-by-day pacing was the thing — nobody was in a van for four hours.',
    name: 'Tom Whitfield',
    from: 'Manchester, UK',
    rating: 5,
  },
  {
    quote:
      'I have booked Sri Lanka three times and never seen leopard until this trip. The Block 5 suggestion came from the planner, not from me.',
    name: 'Lena Brandt',
    from: 'Hamburg, Germany',
    rating: 5,
  },
]

export const promises = [
  {
    title: 'Locally run, locally paid',
    body: 'Every guide, driver and cook on your route is on a Sri Lankan payroll at above-market rates.',
  },
  {
    title: 'Season-aware routing',
    body: 'Two monsoons, opposite coasts. We route around the wet side instead of apologising for it.',
  },
  {
    title: 'No hidden line items',
    body: 'Park fees, permits and service charges are quoted up front in your own currency.',
  },
  {
    title: 'Low-impact by default',
    body: 'Small groups, refill stations instead of bottled water, and no elephant riding on any itinerary.',
  },
]
