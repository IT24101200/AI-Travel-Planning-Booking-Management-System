import test from 'node:test'
import assert from 'node:assert/strict'
import {
  formatDateOnly,
  formatLocalSchedule,
  parseInstant
} from './dateTime.js'

test('instant parser treats legacy no-offset UTC values as UTC', () => {
  assert.equal(parseInstant('2026-10-08T12:00:00').toISOString(), '2026-10-08T12:00:00.000Z')
  assert.equal(parseInstant('2026-10-08T12:00:00+05:30').toISOString(), '2026-10-08T06:30:00.000Z')
})

test('date-only formatter preserves the calendar date', () => {
  assert.notEqual(formatDateOnly('2026-10-15T00:00:00Z'), '10/14/2026')
})

test('local schedule formatter preserves offset-less wall-clock time', () => {
  assert.match(formatLocalSchedule('2026-10-15T08:00:00'), /08:00/)
})
