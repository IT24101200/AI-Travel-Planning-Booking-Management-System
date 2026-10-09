import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import {
  customerDeleteError,
  filterDirectoryUsers,
  isStaffRole,
  paginateDirectoryUsers,
  sortDirectoryUsers
} from './customerDirectoryModel.js'

const users = [
  { id: '2', name: 'Beta', email: 'beta@example.test', phone: '0772', role: 'Customer', isStaff: false, trips: 2, joinedAtRaw: '2026-10-02', lastActiveAtRaw: '2026-10-04' },
  { id: '1', name: 'Alpha', email: 'alpha@example.test', phone: '0771', role: 'TravelAgent', isStaff: true, trips: 0, joinedAtRaw: '2026-10-01', lastActiveAtRaw: '2026-10-05' },
  { id: '3', name: 'Gamma', email: 'gamma@example.test', phone: '0773', role: 'Customer', isStaff: false, trips: 2, joinedAtRaw: '2026-10-03', lastActiveAtRaw: '2026-10-03' }
]

const directorySource = readFileSync(new URL('../pages/customers/CustomerDirectory.jsx', import.meta.url), 'utf8')
const dialogSource = readFileSync(new URL('../components/ui/ConfirmDialog.jsx', import.meta.url), 'utf8')

test('directory role classification uses the backend role, not a name or email guess', () => {
  assert.equal(isStaffRole('TravelAgent'), true)
  assert.equal(isStaffRole('Admin'), true)
  assert.equal(isStaffRole('Customer'), false)
})

test('directory tabs and trimmed search filter the same loaded dataset', () => {
  assert.deepEqual(filterDirectoryUsers(users, 'Customers').map((user) => user.id), ['2', '3'])
  assert.deepEqual(filterDirectoryUsers(users, 'Staff').map((user) => user.id), ['1'])
  assert.deepEqual(filterDirectoryUsers(users, 'All', '  GAMMA  ').map((user) => user.id), ['3'])
  assert.deepEqual(filterDirectoryUsers(users, 'All', '0772').map((user) => user.id), ['2'])
})

test('directory sorting is deterministic and uses numeric trips', () => {
  assert.deepEqual(sortDirectoryUsers(users, 'name').map((user) => user.id), ['1', '2', '3'])
  assert.deepEqual(sortDirectoryUsers(users, 'nameDesc').map((user) => user.id), ['3', '2', '1'])
  assert.deepEqual(sortDirectoryUsers(users, 'trips').map((user) => user.id), ['2', '3', '1'])
  assert.deepEqual(sortDirectoryUsers(users, 'joined').map((user) => user.id), ['3', '2', '1'])
})

test('directory pagination clamps an out-of-range page after refresh', () => {
  const result = paginateDirectoryUsers(users, 4, 2)
  assert.equal(result.currentPage, 2)
  assert.equal(result.totalPages, 2)
  assert.deepEqual(result.view.map((user) => user.id), ['3'])
})

test('delete conflicts are converted to safe actionable messages', () => {
  assert.match(customerDeleteError({ response: { status: 409, data: { message: 'History retained.' } } }), /History retained/)
  assert.match(customerDeleteError({ response: { status: 403 } }), /not authorized/i)
  assert.match(customerDeleteError({ response: { status: 500, data: { message: 'raw SQL' } } }), /could not be deleted/i)
})

test('delete action is mounted as an accessible confirmation dialog', () => {
  assert.match(directorySource, /<ConfirmDialog/)
  assert.doesNotMatch(directorySource, /window\.confirm/)
  assert.match(dialogSource, /role="dialog"/)
  assert.match(dialogSource, /aria-modal="true"/)
  assert.match(dialogSource, /Delete account/)
})
