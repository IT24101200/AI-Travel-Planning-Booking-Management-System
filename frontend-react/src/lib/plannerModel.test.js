import test from 'node:test'
import assert from 'node:assert/strict'
import {
  addDestination,
  buildTripRequestPayload,
  dateStringFromOffset,
  mergeAgentLogs,
  moveDestination,
  safePlannerError,
  validatePlannerForm,
} from './plannerModel.js'

const now = new Date(2026, 9, 10, 12)
const destinations = [
  { id: 1, name: 'Colombo' },
  { id: 2, name: 'Kandy' },
  { id: 3, name: 'Ella' },
]

function validForm(overrides = {}) {
  return {
    destinations,
    startDate: dateStringFromOffset(7, now),
    endDate: dateStringFromOffset(12, now),
    travellerCount: '2',
    budgetCeiling: '150000',
    currency: 'LKR',
    notes: 'Quiet stays and an easy-paced route.',
    airportPickup: false,
    airportCode: 'CMB',
    airportArrivalTime: '08:00',
    starterLocationId: '',
    ...overrides,
  }
}

test('canonical destinations load into an ordered selection without duplicates', () => {
  const selected = addDestination(addDestination([], destinations[0]), destinations[1])
  assert.deepEqual(selected.map((item) => item.name), ['Colombo', 'Kandy'])
  assert.equal(addDestination(selected, destinations[0]), selected)
})

test('reorder preserves the chosen order and payload order', () => {
  const selected = moveDestination(destinations, 2, 'up')
  assert.deepEqual(selected.map((item) => item.name), ['Colombo', 'Ella', 'Kandy'])
  const payload = buildTripRequestPayload({ ...validForm(), destinations: selected })
  assert.deepEqual(payload.destinationIds, [1, 3, 2])
  assert.deepEqual(payload.destinations.map((item) => item.order), [0, 1, 2])
})

test('client validation rejects invalid dates, travellers, budget, and airport fields', () => {
  const errors = validatePlannerForm(validForm({
    startDate: dateStringFromOffset(2, now),
    endDate: dateStringFromOffset(1, now),
    travellerCount: '0',
    budgetCeiling: '0',
    airportPickup: true,
    airportCode: 'XXX',
    airportArrivalTime: '25:00',
  }), now)
  assert.ok(errors.endDate)
  assert.ok(errors.travellerCount)
  assert.ok(errors.budgetCeiling)
  assert.ok(errors.airportCode)
  assert.ok(errors.airportArrivalTime)
})

test('the AI starter is optional and airport pickup becomes the origin', () => {
  const optimized = buildTripRequestPayload(validForm())
  assert.equal(optimized.starterLocationId, null)
  assert.match(optimized.rawRequestText, /AI optimized/)

  const airport = buildTripRequestPayload(validForm({ airportPickup: true, airportCode: 'HRI', airportArrivalTime: '09:30' }))
  assert.equal(airport.starterLocationId, null)
  assert.match(airport.rawRequestText, /HRI airport/)
  assert.equal(airport.airportArrivalTime, '09:30:00')
})

test('log merging deduplicates streamed entries and safe errors hide internals', () => {
  const log = { id: 'a', timestamp: '2026-10-10T08:00:00Z', agentName: 'CoordinatorAgent', stepName: 'Plan', status: 'Success' }
  assert.equal(mergeAgentLogs([log], [log]).length, 1)
  assert.match(safePlannerError({ response: { data: { message: 'The planning service is unavailable.' } } }), /unavailable/)
  assert.match(safePlannerError({ message: 'Traceback: secret SQL connection' }), /temporarily unavailable/i)
})
