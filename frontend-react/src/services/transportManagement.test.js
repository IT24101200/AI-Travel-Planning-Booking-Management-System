import assert from 'node:assert/strict'
import test from 'node:test'
import { api, buildTransportQuery, fetchTransport } from './apiClient.js'
import { transportErrorMessage } from './transportErrors.js'
import {
  buildTransportPayload,
  getCoveragePresentation,
  normalizeTransportResponse,
  transportPageRange,
  validateTransportForm
} from './transportManagement.js'

globalThis.localStorage = {
  getItem: () => null,
  removeItem: () => {}
}

test('fetchTransport uses supported server filters and can load page two', async () => {
  const captured = []
  const previousAdapter = api.defaults.adapter
  api.defaults.adapter = async (config) => {
    captured.push(config.params)
    return {
      data: { data: [{ id: 11 }], page: 2, pageSize: 10, totalCount: 21, totalPages: 3 },
      status: 200,
      statusText: 'OK',
      headers: {},
      config
    }
  }

  try {
    const result = await fetchTransport({
      page: 2,
      pageSize: 10,
      routeFrom: 'Batticaloa',
      routeTo: 'Colombo',
      type: 'Bus',
      status: 'Inactive'
    })
    assert.deepEqual(captured[0], {
      type: 'Bus',
      routeFrom: 'Batticaloa',
      routeTo: 'Colombo',
      status: 'Inactive',
      page: 2,
      pageSize: 10
    })
    assert.equal(result.totalPages, 3)
    assert.equal(result.page, 2)
  } finally {
    api.defaults.adapter = previousAdapter
  }
})

test('transport query omits unsupported generic search and preserves total page contract', () => {
  assert.deepEqual(
    buildTransportQuery({ search: 'Batticaloa', page: 2, pageSize: 10, status: 'All' }),
    { status: 'All', page: 2, pageSize: 10 }
  )
  assert.deepEqual(
    normalizeTransportResponse({ data: [1], page: 2, pageSize: 10, totalCount: 21, totalPages: 3 }),
    { data: [1], page: 2, pageSize: 10, totalCount: 21, totalPages: 3 }
  )
  assert.deepEqual(transportPageRange(3, 10, 21), { from: 21, to: 21 })
})

test('transport form blocks same routes and invalid schedules', () => {
  const valid = {
    type: 'Bus',
    provider: 'Approved Provider',
    from: 'Colombo',
    to: 'Ella',
    departureTime: '2026-10-15T08:00',
    arrivalTime: '2026-10-15T12:00',
    capacity: 40,
    price: 0,
    currency: 'LKR'
  }
  assert.equal(validateTransportForm(valid), null)
  assert.equal(validateTransportForm({ ...valid, to: ' colombo ' }), 'Route origin and destination must be different.')
  assert.equal(validateTransportForm({ ...valid, arrivalTime: '2026-10-15T07:00' }), 'Arrival must be later than departure.')
  assert.equal(validateTransportForm({ ...valid, capacity: 1001 }), 'Capacity must be a whole number between 1 and 1000.')
})

test('status updates preserve the complete transport schedule payload', () => {
  const payload = buildTransportPayload({
    type: 'Bus',
    provider: 'Approved Provider',
    from: 'Colombo',
    to: 'Ella',
    departureTime: '2026-10-15T08:00',
    arrivalTime: '2026-10-15T12:00',
    capacity: 40,
    price: 1250,
    currency: 'lkr',
    imageUrl: 'https://example.test/bus.jpg',
    status: 'Inactive'
  })

  assert.deepEqual(payload, {
    type: 'Bus',
    provider: 'Approved Provider',
    routeFrom: 'Colombo',
    routeTo: 'Ella',
    departureTime: '2026-10-15T08:00',
    arrivalTime: '2026-10-15T12:00',
    capacity: 40,
    price: 1250,
    currency: 'LKR',
    imageUrl: 'https://example.test/bus.jpg',
    status: 'Inactive'
  })
})

test('coverage result presentation uses safe actionable messages and counts', () => {
  assert.deepEqual(
    getCoveragePresentation({
      reasonCode: 'NO_DATE_MATCH',
      message: 'internal database detail',
      totalActive: 12,
      routeMatches: 2,
      dateMatches: 0,
      capacityMatches: 0,
      availableMatches: 0
    }),
    {
      reasonCode: 'NO_DATE_MATCH',
      message: 'Transport exists for this route, but not in the selected date range.',
      status: 'Unavailable',
      totalActive: 12,
      routeMatches: 2,
      dateMatches: 0,
      capacityMatches: 0,
      availableMatches: 0
    }
  )
})

test('transport errors never expose raw backend details', () => {
  assert.equal(
    transportErrorMessage({ response: { status: 500, data: { message: 'SQL connection string' } } }),
    'The transport service is temporarily unavailable. Please retry.'
  )
  assert.equal(
    transportErrorMessage({ response: { status: 409, data: { code: 'TRANSPORT_CAPACITY_CONFLICT' } } }),
    'Capacity cannot be reduced below seats already reserved.'
  )
})
