import assert from 'node:assert/strict'
import test from 'node:test'
import { notificationErrorMessage } from './notificationErrors.js'

test('notification errors never expose raw network or backend details', () => {
  const message = notificationErrorMessage(new Error('SQL exception with stack trace'))

  assert.equal(message, 'The notification service is temporarily unavailable. Please retry.')
  assert.doesNotMatch(message, /SQL|stack trace|exception/i)
})

test('notification error statuses map to safe actionable messages', () => {
  assert.equal(
    notificationErrorMessage({ response: { status: 403 }, message: 'forbidden internals' }),
    'You do not have permission to manage notifications.'
  )
  assert.equal(
    notificationErrorMessage({ response: { status: 500 }, message: 'database details' }),
    'The notification service is temporarily unavailable. Please retry.'
  )
})
