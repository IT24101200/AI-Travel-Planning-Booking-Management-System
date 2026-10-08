import test from 'node:test'
import assert from 'node:assert/strict'
import { orderedTransportBookingItems } from './bookingItemOrdering.js'

test('orders indexed transport legs and keeps legacy null indexes last', () => {
  const result = orderedTransportBookingItems([
    { id: 12, itemType: 'Transport', transportLegIndex: 1 },
    { id: 13, itemType: 'Transport', transportLegIndex: null },
    { id: 11, itemType: 2, transportLegIndex: 0 },
  ])

  assert.deepEqual(result.map((item) => item.id), [11, 12, 13])
})
