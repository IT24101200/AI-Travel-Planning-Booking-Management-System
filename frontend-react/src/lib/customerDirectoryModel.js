import { normalizeRole } from './roles.js'

export function isStaffRole(role) {
  return normalizeRole(role) !== 'customer'
}

export function filterDirectoryUsers(users, category = 'All', query = '') {
  const term = String(query || '').trim().toLowerCase()
  return users.filter((user) => {
    if (category === 'Customers' && user.isStaff) return false
    if (category === 'Staff' && !user.isStaff) return false
    if (!term) return true
    return [user.name, user.email, user.phone, user.role]
      .some((value) => String(value || '').toLowerCase().includes(term))
  })
}

function compareText(left, right) {
  return String(left || '').localeCompare(String(right || ''), undefined, { sensitivity: 'base' })
}

function compareDate(left, right) {
  const leftTime = Date.parse(left || '')
  const rightTime = Date.parse(right || '')
  if (Number.isFinite(leftTime) && Number.isFinite(rightTime)) return leftTime - rightTime
  if (Number.isFinite(leftTime)) return 1
  if (Number.isFinite(rightTime)) return -1
  return 0
}

function tieBreak(left, right) {
  return compareText(left.id, right.id)
}

export function sortDirectoryUsers(users, sort = 'name') {
  return [...users].sort((left, right) => {
    if (sort === 'nameDesc') return compareText(right.name, left.name) || tieBreak(left, right)
    if (sort === 'joined') return compareDate(right.joinedAtRaw, left.joinedAtRaw) || tieBreak(left, right)
    if (sort === 'lastActive') return compareDate(right.lastActiveAtRaw, left.lastActiveAtRaw) || tieBreak(left, right)
    if (sort === 'trips') return (Number(right.trips) || 0) - (Number(left.trips) || 0) || tieBreak(left, right)
    return compareText(left.name, right.name) || tieBreak(left, right)
  })
}

export function paginateDirectoryUsers(users, page, pageSize) {
  const safePageSize = Math.max(1, Number(pageSize) || 1)
  const totalPages = Math.max(1, Math.ceil(users.length / safePageSize))
  const currentPage = Math.min(Math.max(1, Number(page) || 1), totalPages)
  return {
    currentPage,
    totalPages,
    view: users.slice((currentPage - 1) * safePageSize, currentPage * safePageSize)
  }
}

export function customerDeleteError(error) {
  const status = error?.response?.status
  if (status === 409) {
    return error.response?.data?.message || 'This user cannot be deleted because booking or trip history must be retained.'
  }
  if (status === 403) return 'You are not authorized to delete directory accounts.'
  if (status === 404) return 'That directory account no longer exists. Refresh the directory.'
  return 'The account could not be deleted. Please try again.'
}
