import { useEffect, useMemo, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import {
  fetchAllCustomers,
  fetchBookings,
  fetchCustomerTrips,
  updateCustomer,
  registerStaff,
  deleteCustomer
} from '../../services/apiClient.js'
import { usePageTitle } from '../../lib/hooks.js'
import { LoadingState } from '../../components/ui/LoadingState.jsx'
import { AlertBanner } from '../../components/ui/AlertBanner.jsx'
import { useResponsive } from '../../lib/useResponsive.js'
import { useAuth } from '../../lib/auth.jsx'
import { formatLocalInstantDate, formatLocalInstantDateTime } from '../../lib/dateTime.js'
import { formatPrice } from '../../lib/formatPrice.js'
import {
  customerDeleteError,
  filterDirectoryUsers,
  isStaffRole,
  paginateDirectoryUsers,
  sortDirectoryUsers
} from '../../lib/customerDirectoryModel.js'
import { ConfirmDialog } from '../../components/ui/ConfirmDialog.jsx'
import {
  SearchIcon,
  UserPlusIcon,
  EditIcon,
  ArrowRightIcon,
  RefreshIcon
} from '../../components/ui/Icons.jsx'

/**
 * Serendib Trails — Customer & Staff Directory
 * Designed based on Figma Dev Mode Specifications (node-id: 2:27047)
 */
export default function CustomerDirectory() {
  const navigate = useNavigate()
  const { user: currentUser } = useAuth()
  const isAdmin = currentUser?.role?.toLowerCase() === 'admin'

  // Check if a directory user record matches the currently logged-in account
  const isSelfAccount = (u) => {
    if (!u) return false
    const matchEmail = Boolean(
      currentUser?.email &&
      u.email &&
      currentUser.email.trim().toLowerCase() === u.email.trim().toLowerCase()
    )
    const matchId = Boolean(currentUser?.userId && u.id && currentUser.userId === u.id)
    return matchEmail || matchId
  }

  const { isMobile } = useResponsive()
  const [dataList, setDataList] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [query, setQuery] = useState('')
  const [category, setCategory] = useState('All') // 'All' | 'Customers' | 'Staff'
  const [sort, setSort] = useState('name')
  const [page, setPage] = useState(1)
  const [selectedUser, setSelectedUser] = useState(null)
  const isSelectedSelf = isSelfAccount(selectedUser)
  const [showInviteModal, setShowInviteModal] = useState(false)
  const [inviteSuccess, setInviteSuccess] = useState('')
  const [inviteLoading, setInviteLoading] = useState(false)
  const [inviteError, setInviteError] = useState(null)
  const [inviteFormData, setInviteFormData] = useState({
    fullName: '',
    email: '',
    phone: '',
    password: '',
    role: 'TravelAgent',
    department: 'Tour Operations'
  })

  // Account deletion state
  const [deleteLoading, setDeleteLoading] = useState(false)
  const [deleteTarget, setDeleteTarget] = useState(null)
  const [deleteError, setDeleteError] = useState(null)

  // Trip Records Modal State
  const [showTripsModal, setShowTripsModal] = useState(false)
  const [tripsModalLoading, setTripsModalLoading] = useState(false)
  const [tripsModalError, setTripsModalError] = useState(null)
  const [tripsRecords, setTripsRecords] = useState([])

  // Edit Profile Modal State
  const [showEditModal, setShowEditModal] = useState(false)
  const [editFormData, setEditFormData] = useState({ fullName: '', phone: '', role: 'Customer', department: 'Tour Operations' })
  const [editLoading, setEditLoading] = useState(false)
  const [editSuccess, setEditSuccess] = useState('')
  const [editError, setEditError] = useState(null)
  usePageTitle('Customer & Staff Directory · Serendib Trails')

  async function loadCustomers(isCancelled = () => false) {
    setLoading(true)
    setError(null)
    try {
      const res = await fetchAllCustomers()
      const live = Array.isArray(res) ? res : (res?.data || [])
      if (!isCancelled()) {
        const mapped = live.map((c, idx) => {
          const roleStr = String(c.role || 'Customer').trim() || 'Customer'
          const isStaff = isStaffRole(roleStr)

          // Generate initials for avatar
          const fullName = c.fullName || c.name || 'Unnamed user'
          const parts = fullName.trim().split(' ')
          const initials = parts.length > 1
            ? (parts[0][0] + parts[parts.length - 1][0]).toUpperCase()
            : fullName.substring(0, 2).toUpperCase()

          return {
            id: c.id || idx + 1,
            name: fullName,
            initials: initials || 'ST',
            email: c.email || 'Email unavailable',
            role: roleStr,
            isStaff,
            department: c.department || (isStaff ? 'Operations' : null),
            phone: c.phone || 'Phone unavailable',
            location: c.city ? `${c.city}, ${c.country || 'Sri Lanka'}` : 'Location unavailable',
            joinedAtRaw: c.joinedAt || c.createdAt || null,
            joinedAt: c.joinedAt ? formatLocalInstantDate(c.joinedAt) : (c.createdAt ? formatLocalInstantDate(c.createdAt) : 'Date unavailable'),
            trips: c.tripCount ?? c.trips ?? 0,
            lastActiveAtRaw: c.lastActiveAt || null,
            lastActive: c.lastActiveAt ? formatLocalInstantDateTime(c.lastActiveAt) : 'Date unavailable',
            hasPreference: c.hasPreference || !!(c.budgetMin || c.preferredActivities || c.preference),
            // Dynamic travel profile from database preference records
            travelProfile: {
              budgetRange: (c.budgetMin != null && c.budgetMax != null)
                ? `$${Number(c.budgetMin).toLocaleString()}–$${Number(c.budgetMax).toLocaleString()} ${c.currency || 'USD'}`
                : (c.preference?.budgetMin != null && c.preference?.budgetMax != null)
                  ? `$${Number(c.preference.budgetMin).toLocaleString()}–$${Number(c.preference.budgetMax).toLocaleString()} ${c.preference.currency || 'USD'}`
                  : (c.budgetRange || (isStaff ? 'N/A (Staff member)' : 'Not specified yet')),
              preferredActivities: c.preferredActivities || c.preference?.preferredActivities || (isStaff ? 'Internal operations' : 'Not specified yet'),
              dietaryNotes: c.dietaryNotes || c.preference?.dietaryNotes || (isStaff ? 'N/A' : 'None specified'),
              accessibility: c.accessibilityNotes || c.preference?.accessibilityNotes || c.accessibility || (isStaff ? 'N/A' : 'Standard accommodations')
            }
          }
        })
        setDataList(mapped)
      }
    } catch (err) {
      if (!isCancelled()) {
        setError(err.response?.data?.message || err.message || 'Failed to load user directory from database.')
      }
    } finally {
      if (!isCancelled()) setLoading(false)
    }
  }

  useEffect(() => {
    let cancelled = false
    // This starts an async API load; its state updates occur after the request.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    loadCustomers(() => cancelled)
    return () => { cancelled = true }
  }, [])

  const customerCount = useMemo(() => dataList.filter((u) => !u.isStaff).length, [dataList])
  const staffCount = useMemo(() => dataList.filter((u) => u.isStaff).length, [dataList])

  const rows = useMemo(
    () => sortDirectoryUsers(filterDirectoryUsers(dataList, category, query), sort),
    [dataList, query, sort, category]
  )

  const pageSize = isMobile ? 5 : 7
  const { currentPage, totalPages: pages, view } = useMemo(
    () => paginateDirectoryUsers(rows, page, pageSize),
    [rows, page, pageSize]
  )

  // Clear selection if the selected user is filtered out or removed
  useEffect(() => {
    if (selectedUser && !rows.find((r) => r.id === selectedUser.id)) {
      // The selection must be cleared when filtering removes its row.
      // eslint-disable-next-line react-hooks/set-state-in-effect
      setSelectedUser(null)
    }
  }, [rows, selectedUser])

  function onCategoryChange(cat) {
    setCategory(cat)
    setPage(1)
  }

  async function handleInviteStaff(e) {
    e.preventDefault()
    setInviteLoading(true)
    setInviteError(null)
    setInviteSuccess('')
    try {
      await registerStaff({
        fullName: inviteFormData.fullName.trim(),
        email: inviteFormData.email.trim(),
        password: inviteFormData.password,
        phone: inviteFormData.phone.trim(),
        role: inviteFormData.role,
        department: inviteFormData.department
      })
      setInviteSuccess(`Staff account created for ${inviteFormData.fullName} (${inviteFormData.role}).`)
      await loadCustomers()
      setInviteFormData({
        fullName: '',
        email: '',
        phone: '',
        password: '',
        role: 'TravelAgent',
        department: 'Tour Operations'
      })
      setTimeout(() => {
        setShowInviteModal(false)
        setInviteSuccess('')
      }, 1500)
    } catch (err) {
      const msg = err.response?.data?.message || err.response?.data?.errors?.join(', ') || err.message || 'Failed to create staff account.'
      setInviteError(msg)
    } finally {
      setInviteLoading(false)
    }
  }

  async function handleOpenTrips(user) {
    if (!user) return
    setShowTripsModal(true)
    setTripsModalLoading(true)
    setTripsModalError(null)
    setTripsRecords([])

    if (user.isStaff) {
      setTripsModalLoading(false)
      return
    }

    try {
      const [bookingsRes, tripsRes] = await Promise.allSettled([
        fetchBookings({ customerId: user.id }),
        fetchCustomerTrips(user.id)
      ])

      const bookings = bookingsRes.status === 'fulfilled'
        ? (Array.isArray(bookingsRes.value) ? bookingsRes.value : (bookingsRes.value?.data || []))
        : []
      const trips = tripsRes.status === 'fulfilled'
        ? (Array.isArray(tripsRes.value) ? tripsRes.value : (tripsRes.value?.data || []))
        : []

      const matchedBookings = bookings.filter(
        (b) => b.customerId === user.id || (b.customerName && b.customerName.toLowerCase() === user.name.toLowerCase())
      )
      const matchedTrips = trips.filter((t) => t.customerId === user.id)

      const formatted = [
        ...matchedBookings.map((b) => {
          const statusNames = ['Draft', 'Awaiting Approval', 'Confirmed', 'Rejected', 'Cancelled', 'Completed']
          const statusStr = typeof b.status === 'number' ? (statusNames[b.status] || 'Active') : String(b.status || 'Active')
          return {
            type: 'Booking',
            id: b.id,
            reference: b.bookingReference || `ST-BK-${b.id}`,
            title: b.bookingItems?.length > 0
              ? b.bookingItems.map((i) => i.tourName || 'Serendib Tour').filter(Boolean).join(', ')
              : 'Custom Tailored Tour Package',
            date: b.createdAt ? b.createdAt.split('T')[0] : 'Recent',
            amount: b.totalCost != null ? formatPrice(b.totalCost, b.currency || 'LKR') : 'Amount unavailable',
            status: statusStr,
            itineraryId: b.itineraryId
          }
        }),
        ...matchedTrips.map((t) => ({
          type: 'Trip Request',
          id: t.id,
          reference: `TRIP-REQ-${t.id}`,
          title: t.rawRequestText || (t.destinationId ? `Destination Visit #${t.destinationId}` : 'Bespoke Tour Request'),
          date: t.startDate ? t.startDate.split('T')[0] : 'Upcoming',
          amount: t.budgetCeiling != null ? formatPrice(t.budgetCeiling, t.currency || 'LKR') : 'Budget unavailable',
          status: t.status || 'Planned',
          itineraryId: null
        }))
      ]

      setTripsRecords(formatted)
    } catch (err) {
      setTripsModalError(err.message || 'Failed to load trip records from database.')
    } finally {
      setTripsModalLoading(false)
    }
  }

  function handleDeleteAccount(user) {
    if (!user || isSelfAccount(user)) return
    setDeleteError(null)
    setDeleteTarget(user)
  }

  async function confirmDeleteAccount() {
    if (!deleteTarget) return
    setDeleteLoading(true)
    setDeleteError(null)
    try {
      await deleteCustomer(deleteTarget.id)
      setPage(1)
      setSelectedUser(null)
      setDeleteTarget(null)
      await loadCustomers()
    } catch (err) {
      setDeleteError(customerDeleteError(err))
    } finally {
      setDeleteLoading(false)
    }
  }

  // Helper to format/sanitize phone numbers
  function cleanPhone(raw) {
    if (!raw) return ''
    let cleaned = raw.trim().replace(/[\s\-()]/g, '')
    if (cleaned.startsWith('+94')) {
      cleaned = '0' + cleaned.substring(3)
    }
    return cleaned
  }

  function handleOpenEdit(user) {
    if (!user) return
    setEditFormData({
      fullName: user.name || '',
      phone: cleanPhone(user.phone) || user.phone || '',
      role: user.role || (user.isStaff ? 'TravelAgent' : 'Customer'),
      department: user.department || 'Tour Operations'
    })
    setEditSuccess('')
    setEditError(null)
    setShowEditModal(true)
  }

  async function handleSaveEdit(e) {
    e.preventDefault()
    if (!selectedUser) return
    setEditLoading(true)
    setEditError(null)
    try {
      // If editing self, preserve current role so admin privileges are not accidentally lost
      const targetRole = isSelectedSelf ? (selectedUser.role || 'Admin') : editFormData.role
      const targetPhone = cleanPhone(editFormData.phone)

      await updateCustomer(selectedUser.id, {
        fullName: editFormData.fullName.trim(),
        phone: targetPhone,
        role: targetRole,
        department: editFormData.department
      })
      await loadCustomers()
      setSelectedUser((prev) => ({
        ...prev,
        name: editFormData.fullName.trim(),
        phone: targetPhone,
        role: targetRole,
        department: editFormData.department,
        isStaff: targetRole === 'TravelAgent' || targetRole === 'Admin'
      }))
      setEditSuccess('User profile updated successfully.')
      setTimeout(() => {
        setShowEditModal(false)
        setEditSuccess('')
      }, 1200)
    } catch (err) {
      const apiErrors = err.response?.data?.errors
      const errorMsg = Array.isArray(apiErrors) && apiErrors.length > 0
        ? apiErrors.join(' ')
        : apiErrors && typeof apiErrors === 'object'
          ? Object.values(apiErrors).flat().join(' ')
          : err.response?.data?.message || err.message || 'Failed to update customer profile.'
      setEditError(errorMsg)
    } finally {
      setEditLoading(false)
    }
  }

  return (
    <div className="staff-page">
      {/* ── Page Header matching Figma 2:27047 ── */}
      <header className="staff-page__head">
        <div className="staff-page__title-block">
          <p className="staff-page__eyebrow">PEOPLE / DIRECTORY</p>
          <h1 className="staff-page__title">Customer & staff directory</h1>
          <p className="staff-page__subtitle">
            Search traveller profiles and administer internal staff access.
          </p>
        </div>
        <div className="staff-page__actions">
          <button
            type="button"
            className="btn-outline"
            onClick={() => loadCustomers(false)}
            disabled={loading}
            title="Refresh database records"
          >
            <RefreshIcon size={15} />
            <span>{loading ? 'Refreshing…' : 'Refresh'}</span>
          </button>
          {isAdmin && (
            <button
              type="button"
              className="btn-gold"
              onClick={() => setShowInviteModal(true)}
            >
              <UserPlusIcon size={15} />
              <span>Invite staff member</span>
            </button>
          )}
        </div>
      </header>

      {error && (
        <AlertBanner
          type="error"
          message={error}
          onRetry={() => loadCustomers(false)}
          onDismiss={() => setError(null)}
        />
      )}

      {/* ── Category Tabs matching Figma ── */}
      <div className="staff-tabs">
        <button
          type="button"
          className={`staff-tab ${category === 'All' ? 'is-active' : ''}`}
          onClick={() => onCategoryChange('All')}
        >
          <span>All Users</span>
          <span className="staff-tab__count">{dataList.length}</span>
        </button>
        <button
          type="button"
          className={`staff-tab ${category === 'Customers' ? 'is-active' : ''}`}
          onClick={() => onCategoryChange('Customers')}
        >
          <span>Customers</span>
          <span className="staff-tab__count">{customerCount}</span>
        </button>
        <button
          type="button"
          className={`staff-tab ${category === 'Staff' ? 'is-active' : ''}`}
          onClick={() => onCategoryChange('Staff')}
        >
          <span>Staff Members</span>
          <span className="staff-tab__count">{staffCount}</span>
        </button>
      </div>

      {/* ── Dynamic Layout: Full width when no user is selected, Split Master-Detail when clicked ── */}
      <div
        className="split-workspace"
        style={{
          gridTemplateColumns: selectedUser ? 'minmax(0, 1fr) 420px' : '1fr',
          transition: 'grid-template-columns 0.2s ease'
        }}
      >
        {/* Left Table Card */}
        <div className="staff-card">
          <div className="staff-card__head">
            <div className="staff-search-box">
              <SearchIcon size={16} />
              <input
                type="text"
                placeholder="Search name, email, or phone…"
                value={query}
                onChange={(e) => {
                  setQuery(e.target.value)
                  setPage(1)
                }}
              />
            </div>
            <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
              <select
                className="btn-outline"
                style={{ height: '38px', padding: '0 0.75rem', cursor: 'pointer', fontSize: '0.75rem' }}
                value={sort}
                onChange={(e) => setSort(e.target.value)}
              >
                <option value="name">Name A–Z</option>
                <option value="nameDesc">Name Z-A</option>
                <option value="joined">Join Date newest</option>
                <option value="lastActive">Last active newest</option>
                <option value="trips">Trip Count</option>
              </select>
            </div>
          </div>

          <div className="staff-table-wrap">
            <table className="staff-table">
              <thead>
                <tr>
                  <th scope="col">NAME & EMAIL</th>
                  <th scope="col">PHONE</th>
                  <th scope="col">ROLE</th>
                  <th scope="col">TRIP REQUESTS</th>
                  <th scope="col">LAST ACTIVE</th>
                </tr>
              </thead>
              <tbody>
                {loading ? (
                  <tr>
                    <td colSpan={5} style={{ textAlign: 'center', padding: '2.5rem' }}>
                      <LoadingState message="Loading directory from database…" />
                    </td>
                  </tr>
                ) : view.length > 0 ? (
                  view.map((u) => {
                    const isSelected = selectedUser?.id === u.id
                    return (
                      <tr
                        key={u.id}
                        className={isSelected ? 'is-selected' : ''}
                        style={{ cursor: 'pointer' }}
                        onClick={() => setSelectedUser((prev) => (prev?.id === u.id ? null : u))}
                      >
                        <td>
                          <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
                            <div className="avatar-circle">
                              {u.initials}
                            </div>
                            <div style={{ display: 'flex', flexDirection: 'column' }}>
                              <button
                                type="button"
                                style={{
                                  background: 'none',
                                  border: 'none',
                                  padding: 0,
                                  font: 'inherit',
                                  textAlign: 'left',
                                  color: isSelected ? '#1b4d3e' : '#182126',
                                  fontWeight: 700,
                                  fontSize: '0.8125rem',
                                  cursor: 'pointer'
                                }}
                                onMouseEnter={(e) => {
                                  e.currentTarget.style.color = '#1b4d3e'
                                  e.currentTarget.style.textDecoration = 'underline'
                                }}
                                onMouseLeave={(e) => {
                                  e.currentTarget.style.color = isSelected ? '#1b4d3e' : '#182126'
                                  e.currentTarget.style.textDecoration = 'none'
                                }}
                                onClick={(e) => {
                                  e.stopPropagation()
                                  setSelectedUser((prev) => (prev?.id === u.id ? null : u))
                                }}
                                title="Click to view customer details"
                              >
                                {u.name}
                              </button>
                              <div style={{ display: 'flex', alignItems: 'center', gap: '0.4rem', marginTop: '2px' }}>
                                <span style={{ color: '#66747b', fontSize: '0.75rem' }}>{u.email}</span>
                                {isSelfAccount(u) && (
                                  <span
                                    style={{
                                      fontSize: '0.625rem',
                                      fontWeight: 700,
                                      color: '#0f766e',
                                      backgroundColor: '#ccfbf1',
                                      padding: '1px 5px',
                                      borderRadius: '4px',
                                      lineHeight: 1.2
                                    }}
                                  >
                                    You
                                  </span>
                                )}
                              </div>
                            </div>
                          </div>
                        </td>
                        <td style={{ color: '#475569', fontSize: '0.75rem' }}>{u.phone}</td>
                        <td>
                          {u.role.toLowerCase() === 'admin' ? (
                            <span className="badge-pill badge-purple">
                              <span className="badge-dot" /> Admin
                            </span>
                          ) : u.isStaff ? (
                            <span className="badge-pill badge-blue">
                              <span className="badge-dot" /> TravelAgent
                            </span>
                          ) : (
                            <span className="badge-pill badge-gray">
                              <span className="badge-dot" /> Customer
                            </span>
                          )}
                        </td>
                        <td style={{ fontWeight: 600, color: '#182126' }}>
                          {u.isStaff ? '—' : u.trips}
                        </td>
                        <td style={{ color: '#66747b', fontSize: '0.75rem' }}>{u.lastActive}</td>
                      </tr>
                    )
                  })
                ) : (
                  <tr>
                    <td colSpan={5} style={{ textAlign: 'center', padding: '2rem', color: '#66747b' }}>
                      {query ? `No matching users for “${query}”.` : 'No users found in directory.'}
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>

          {/* Pagination matching Figma */}
          <div className="staff-pagination">
            <span>
              Showing {rows.length > 0 ? (currentPage - 1) * pageSize + 1 : 0}–{Math.min(currentPage * pageSize, rows.length)} of {rows.length} users
            </span>
            <div className="staff-pagination__btns">
              <button
                type="button"
                className="staff-page-btn"
                disabled={currentPage <= 1}
                onClick={() => setPage(currentPage - 1)}
              >
                Previous
              </button>
              {Array.from({ length: pages }, (_, i) => i + 1).map((p) => (
                <button
                  key={p}
                  type="button"
                  className={`staff-page-btn ${currentPage === p ? 'is-active' : ''}`}
                  onClick={() => setPage(p)}
                >
                  {p}
                </button>
              ))}
              <button
                type="button"
                className="staff-page-btn"
                disabled={currentPage >= pages}
                onClick={() => setPage(currentPage + 1)}
              >
                Next
              </button>
            </div>
          </div>
        </div>

        {/* Right Detail Pane: Shown only when a customer is clicked */}
        {selectedUser && (
          <aside className="detail-pane">
            <div className="detail-pane__head">
              <div>
                <h3 style={{ margin: 0, fontSize: '1.0625rem', fontWeight: 700, color: '#182126', display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                  <span>{selectedUser.name}</span>
                  {isSelectedSelf && (
                    <span
                      style={{
                        fontSize: '0.6875rem',
                        fontWeight: 700,
                        color: '#0f766e',
                        backgroundColor: '#ccfbf1',
                        padding: '2px 8px',
                        borderRadius: '9999px',
                        border: '1px solid #99f6e4'
                      }}
                    >
                      Your Account
                    </span>
                  )}
                </h3>
                <span style={{ fontSize: '0.75rem', color: '#66747b' }}>
                  {selectedUser.isStaff ? 'Staff member' : 'Customer'} since {selectedUser.joinedAt}
                </span>
              </div>
              <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                <button
                  type="button"
                  className="btn-outline"
                  style={{ height: '32px', padding: '0 0.625rem' }}
                  onClick={() => handleOpenEdit(selectedUser)}
                >
                  <EditIcon size={14} />
                  <span>Edit profile</span>
                </button>
                {isAdmin && !isSelectedSelf && (
                  <button
                    type="button"
                    className="btn-outline"
                    style={{ height: '32px', padding: '0 0.625rem', color: '#dc2626', borderColor: '#fca5a5' }}
                    disabled={deleteLoading}
                    onClick={() => handleDeleteAccount(selectedUser)}
                    title="Remove this user account"
                  >
                    <span>{deleteLoading ? 'Removing…' : 'Remove'}</span>
                  </button>
                )}
                <button
                  type="button"
                  className="btn-outline"
                  style={{
                    height: '32px',
                    width: '32px',
                    padding: 0,
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    fontSize: '0.875rem',
                    fontWeight: 600,
                    color: '#66747b',
                    cursor: 'pointer'
                  }}
                  onClick={() => setSelectedUser(null)}
                  title="Close customer details"
                  aria-label="Close customer details"
                >
                  ✕
                </button>
              </div>
            </div>

            {/* Profile Identity Card */}
            <div className="profile-card-header">
              <div className="avatar-circle avatar-circle--lg">
                {selectedUser.initials}
              </div>
              <div style={{ flex: 1, minWidth: 0 }}>
                <strong style={{ display: 'block', fontSize: '0.875rem', color: '#182126', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                  {selectedUser.email}
                </strong>
                <span style={{ fontSize: '0.75rem', color: '#66747b' }}>
                  {selectedUser.phone} · {selectedUser.location}
                </span>
              </div>
              <span className="badge-pill badge-green">
                <span className="badge-dot" /> Active
              </span>
            </div>

            {/* 3 Stats Columns */}
            <div className="profile-stats-grid">
              <div className="profile-stat-box">
                <span className="profile-stat-label">Registration Date</span>
                <span className="profile-stat-val">{selectedUser.joinedAt}</span>
              </div>
              <div className="profile-stat-box">
                  <span className="profile-stat-label">Last Active</span>
                  <span className="profile-stat-val">{selectedUser.lastActive}</span>
              </div>
              <div className="profile-stat-box">
                <span className="profile-stat-label">
                    {selectedUser.isStaff ? 'Staff Role' : 'Trip Requests'}
                </span>
                <span className="profile-stat-val">
                  {selectedUser.isStaff ? selectedUser.role : selectedUser.trips}
                </span>
              </div>
            </div>

            {/* Travel Profile Section for Customers, or Operational Profile for Staff */}
            {selectedUser.isStaff ? (
              <div>
                <p className="profile-section-title">Staff / Operations profile</p>

                <div className="profile-pref-item">
                  <span className="profile-pref-label">Department</span>
                  <span className="profile-pref-val">{selectedUser.department || 'Operations'}</span>
                </div>

                <div className="profile-pref-item">
                  <span className="profile-pref-label">Access Level</span>
                  <span className="profile-pref-val">{selectedUser.role} (Internal Management Portal)</span>
                </div>

                <div className="profile-pref-item">
                  <span className="profile-pref-label">Corporate Email</span>
                  <span className="profile-pref-val">{selectedUser.email}</span>
                </div>

                <div className="profile-pref-item">
                  <span className="profile-pref-label">Internal Responsibilities</span>
                  <span className="profile-pref-val">Tour catalog management, booking approvals, itinerary reviews</span>
                </div>
              </div>
            ) : (
              <div>
                <p className="profile-section-title">Travel profile</p>

                <div className="profile-pref-item">
                  <span className="profile-pref-label">Budget Range</span>
                  <span className="profile-pref-val">{selectedUser.travelProfile.budgetRange}</span>
                </div>

                <div className="profile-pref-item">
                  <span className="profile-pref-label">Preferred Activities</span>
                  <span className="profile-pref-val">{selectedUser.travelProfile.preferredActivities}</span>
                </div>

                <div className="profile-pref-item">
                  <span className="profile-pref-label">Dietary Notes</span>
                  <span className="profile-pref-val">{selectedUser.travelProfile.dietaryNotes}</span>
                </div>

                <div className="profile-pref-item">
                  <span className="profile-pref-label">Accessibility Accommodations</span>
                  <span className="profile-pref-val">{selectedUser.travelProfile.accessibility}</span>
                </div>
              </div>
            )}

            {/* Bottom Action Button */}
            <button
              type="button"
              className="btn-outline"
              style={{ width: '100%', justifyContent: 'center', marginTop: '0.5rem' }}
              onClick={() => handleOpenTrips(selectedUser)}
            >
              <ArrowRightIcon size={14} />
              <span>
                {selectedUser.isStaff
                  ? `View ${selectedUser.name} activity`
                  : `View ${selectedUser.trips} trip records`}
              </span>
            </button>
          </aside>
        )}
      </div>

      <ConfirmDialog
        open={Boolean(deleteTarget)}
        title="Delete directory account?"
        user={deleteTarget}
        loading={deleteLoading}
        error={deleteError}
        onCancel={() => {
          if (!deleteLoading) {
            setDeleteTarget(null)
            setDeleteError(null)
          }
        }}
        onConfirm={confirmDeleteAccount}
      />

      {/* ── Invite Staff Member Modal ── */}
      {showInviteModal && (
        <div
          style={{
            position: 'fixed',
            inset: 0,
            backgroundColor: 'rgba(15, 23, 27, 0.6)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            zIndex: 100,
            padding: '1rem'
          }}
        >
          <div className="staff-card" style={{ width: '100%', maxWidth: '440px', padding: '1.75rem' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1.25rem' }}>
              <h3 style={{ margin: 0, fontSize: '1.125rem', fontWeight: 700, color: '#182126' }}>
                Invite staff member
              </h3>
              <button
                type="button"
                className="btn-outline"
                style={{ height: '30px', padding: '0 0.5rem' }}
                onClick={() => setShowInviteModal(false)}
              >
                ✕
              </button>
            </div>

            {inviteSuccess ? (
              <div className="banner-success" style={{ marginBottom: '1rem' }}>
                {inviteSuccess}
              </div>
            ) : (
              <form onSubmit={handleInviteStaff} style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
                {inviteError && (
                  <AlertBanner
                    type="error"
                    message={inviteError}
                    onDismiss={() => setInviteError(null)}
                  />
                )}

                <div>
                  <label style={{ display: 'block', fontSize: '0.75rem', fontWeight: 700, marginBottom: '0.35rem', color: '#182126' }}>
                    Full Name *
                  </label>
                  <input
                    type="text"
                    required
                    placeholder="e.g. Sahan Perera"
                    value={inviteFormData.fullName}
                    onChange={(e) => setInviteFormData(prev => ({ ...prev, fullName: e.target.value }))}
                    className="staff-search-box"
                    style={{ maxWidth: '100%', width: '100%' }}
                  />
                </div>

                <div>
                  <label style={{ display: 'block', fontSize: '0.75rem', fontWeight: 700, marginBottom: '0.35rem', color: '#182126' }}>
                    Corporate Email *
                  </label>
                  <input
                    type="email"
                    required
                    placeholder="s.perera@serendib.lk"
                    value={inviteFormData.email}
                    onChange={(e) => setInviteFormData(prev => ({ ...prev, email: e.target.value }))}
                    className="staff-search-box"
                    style={{ maxWidth: '100%', width: '100%' }}
                  />
                </div>

                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '0.75rem' }}>
                  <div>
                    <label style={{ display: 'block', fontSize: '0.75rem', fontWeight: 700, marginBottom: '0.35rem', color: '#182126' }}>
                      Phone Number *
                    </label>
                    <input
                      type="text"
                      required
                      placeholder="0771234567"
                      value={inviteFormData.phone}
                      onChange={(e) => setInviteFormData(prev => ({ ...prev, phone: e.target.value }))}
                      className="staff-search-box"
                      style={{ maxWidth: '100%', width: '100%' }}
                    />
                  </div>

                  <div>
                    <label style={{ display: 'block', fontSize: '0.75rem', fontWeight: 700, marginBottom: '0.35rem', color: '#182126' }}>
                      Initial Password *
                    </label>
                    <input
                      type="password"
                      required
                      placeholder="Staff@123"
                      value={inviteFormData.password}
                      onChange={(e) => setInviteFormData(prev => ({ ...prev, password: e.target.value }))}
                      className="staff-search-box"
                      style={{ maxWidth: '100%', width: '100%' }}
                    />
                  </div>
                </div>

                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '0.75rem' }}>
                  <div>
                    <label style={{ display: 'block', fontSize: '0.75rem', fontWeight: 700, marginBottom: '0.35rem', color: '#182126' }}>
                      Assigned Role *
                    </label>
                    <select
                      className="btn-outline"
                      style={{ width: '100%', height: '38px', padding: '0 0.75rem' }}
                      value={inviteFormData.role}
                      onChange={(e) => setInviteFormData(prev => ({ ...prev, role: e.target.value }))}
                    >
                      <option value="TravelAgent">Travel Agent (Operations)</option>
                      <option value="Admin">System Administrator</option>
                    </select>
                  </div>

                  <div>
                    <label style={{ display: 'block', fontSize: '0.75rem', fontWeight: 700, marginBottom: '0.35rem', color: '#182126' }}>
                      Department
                    </label>
                    <input
                      type="text"
                      placeholder="Tour Operations"
                      value={inviteFormData.department}
                      onChange={(e) => setInviteFormData(prev => ({ ...prev, department: e.target.value }))}
                      className="staff-search-box"
                      style={{ maxWidth: '100%', width: '100%' }}
                    />
                  </div>
                </div>

                <div style={{ display: 'flex', gap: '0.5rem', marginTop: '0.5rem', justifyContent: 'flex-end' }}>
                  <button
                    type="button"
                    className="btn-outline"
                    onClick={() => setShowInviteModal(false)}
                    disabled={inviteLoading}
                  >
                    Cancel
                  </button>
                  <button type="submit" className="btn-gold" disabled={inviteLoading}>
                    {inviteLoading ? 'Creating account…' : 'Create staff account'}
                  </button>
                </div>
              </form>
            )}
          </div>
        </div>
      )}

      {/* ── Trip Records Modal ── */}
      {showTripsModal && selectedUser && (
        <div
          style={{
            position: 'fixed',
            inset: 0,
            backgroundColor: 'rgba(15, 23, 27, 0.6)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            zIndex: 100,
            padding: '1rem'
          }}
          onClick={(e) => {
            if (e.target === e.currentTarget) setShowTripsModal(false)
          }}
        >
          <div className="staff-card" style={{ width: '100%', maxWidth: '640px', maxHeight: '85vh', overflowY: 'auto', padding: '1.75rem' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '1.25rem', borderBottom: '1px solid #eef2f5', paddingBottom: '1rem' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
                <div className="avatar-circle">
                  {selectedUser.initials}
                </div>
                <div>
                  <h3 style={{ margin: 0, fontSize: '1.125rem', fontWeight: 700, color: '#182126' }}>
                    {selectedUser.isStaff ? `${selectedUser.name} · Staff Activity` : `Trip records · ${selectedUser.name}`}
                  </h3>
                  <span style={{ fontSize: '0.75rem', color: '#66747b' }}>
                    {selectedUser.email} · {selectedUser.phone}
                  </span>
                </div>
              </div>
              <button
                type="button"
                className="btn-outline"
                style={{ height: '30px', padding: '0 0.5rem' }}
                onClick={() => setShowTripsModal(false)}
              >
                ✕
              </button>
            </div>

            {selectedUser.isStaff ? (
              <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
                <div style={{ padding: '1rem', background: '#f8fafc', borderRadius: '8px', border: '1px solid #e2e8f0' }}>
                  <strong style={{ display: 'block', color: '#182126', fontSize: '0.875rem', marginBottom: '0.25rem' }}>
                    Staff Operational Role
                  </strong>
                  <p style={{ margin: 0, fontSize: '0.75rem', color: '#64748b', lineHeight: 1.5 }}>
                    {selectedUser.name} is an active <strong>{selectedUser.role}</strong> in the <strong>{selectedUser.department || 'Tour Operations'}</strong> department.
                    Staff accounts manage booking approvals, itinerary reviews, and catalog items.
                  </p>
                </div>
                <div style={{ display: 'flex', gap: '0.75rem', justifyContent: 'flex-end', marginTop: '0.5rem' }}>
                  <button
                    type="button"
                    className="btn-outline"
                    onClick={() => {
                      setShowTripsModal(false)
                      navigate('/staff/itineraries')
                    }}
                  >
                    Review Itineraries
                  </button>
                  <button
                    type="button"
                    className="btn-gold"
                    onClick={() => {
                      setShowTripsModal(false)
                      navigate('/staff/bookings')
                    }}
                  >
                    Open Booking Approvals
                  </button>
                </div>
              </div>
            ) : tripsModalLoading ? (
              <div style={{ padding: '2.5rem', textAlign: 'center' }}>
                <LoadingState message="Fetching live trip records from database…" />
              </div>
            ) : tripsModalError ? (
              <AlertBanner
                type="error"
                message={tripsModalError}
                onRetry={() => handleOpenTrips(selectedUser)}
                onDismiss={() => setTripsModalError(null)}
              />
            ) : tripsRecords.length > 0 ? (
              <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <span style={{ fontSize: '0.75rem', color: '#66747b', fontWeight: 600 }}>
                    {tripsRecords.length} RECORDED {tripsRecords.length === 1 ? 'TRIP / BOOKING' : 'TRIPS & BOOKINGS'}
                  </span>
                  <span className="badge-pill badge-green">
                    <span className="badge-dot" /> Database synced
                  </span>
                </div>

                <div style={{ display: 'flex', flexDirection: 'column', gap: '0.75rem' }}>
                  {tripsRecords.map((item) => (
                    <div
                      key={`${item.type}-${item.id}`}
                      style={{
                        padding: '1rem',
                        background: '#ffffff',
                        border: '1px solid #e2e8f0',
                        borderRadius: '8px',
                        display: 'flex',
                        flexDirection: 'column',
                        gap: '0.5rem'
                      }}
                    >
                      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                        <div>
                          <strong style={{ color: '#182126', fontSize: '0.875rem' }}>{item.reference}</strong>
                          <span style={{ fontSize: '0.75rem', color: '#64748b', marginLeft: '0.5rem' }}>
                            ({item.type})
                          </span>
                        </div>
                        <span
                          className={`badge-pill ${
                            item.status.toLowerCase().includes('confirm') || item.status.toLowerCase().includes('complet')
                              ? 'badge-green'
                              : item.status.toLowerCase().includes('await') || item.status.toLowerCase().includes('pend')
                              ? 'badge-yellow'
                              : item.status.toLowerCase().includes('reject') || item.status.toLowerCase().includes('cancel')
                              ? 'badge-red'
                              : 'badge-blue'
                          }`}
                        >
                          <span className="badge-dot" /> {item.status}
                        </span>
                      </div>

                      <p style={{ margin: 0, fontSize: '0.8125rem', color: '#334155', fontWeight: 500 }}>
                        {item.title}
                      </p>

                      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', fontSize: '0.75rem', color: '#64748b', paddingTop: '0.25rem', borderTop: '1px dashed #e2e8f0' }}>
                        <span>Date: <strong>{item.date}</strong></span>
                        <span>Amount: <strong style={{ color: '#0f172a' }}>{item.amount}</strong></span>
                      </div>

                      <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '0.5rem', marginTop: '0.25rem' }}>
                        {item.type === 'Booking' ? (
                          <button
                            type="button"
                            className="btn-outline"
                            style={{ height: '28px', fontSize: '0.75rem', padding: '0 0.5rem' }}
                            onClick={() => {
                              setShowTripsModal(false)
                              navigate('/staff/bookings')
                            }}
                          >
                            Inspect in Bookings →
                          </button>
                        ) : (
                          <button
                            type="button"
                            className="btn-outline"
                            style={{ height: '28px', fontSize: '0.75rem', padding: '0 0.5rem' }}
                            onClick={() => {
                              setShowTripsModal(false)
                              navigate('/staff/itineraries')
                            }}
                          >
                            Review Itinerary →
                          </button>
                        )}
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            ) : (
              <div style={{ textAlign: 'center', padding: '2.5rem 1rem' }}>
                <div style={{ fontSize: '2.5rem', marginBottom: '0.75rem' }}>🧳</div>
                <h4 style={{ margin: '0 0 0.5rem 0', color: '#182126', fontSize: '1rem', fontWeight: 700 }}>
                  No trip records found
                </h4>
                <p style={{ margin: '0 0 1.25rem 0', fontSize: '0.8125rem', color: '#64748b', maxWidth: '360px', marginLeft: 'auto', marginRight: 'auto' }}>
                  {selectedUser.name} currently has no active trip requests or tour bookings recorded in the system.
                </p>
                <div style={{ display: 'flex', gap: '0.75rem', justifyContent: 'center' }}>
                  <button
                    type="button"
                    className="btn-outline"
                    onClick={() => setShowTripsModal(false)}
                  >
                    Close
                  </button>
                  <button
                    type="button"
                    className="btn-gold"
                    onClick={() => {
                      setShowTripsModal(false)
                      navigate('/planner')
                    }}
                  >
                    Plan a tour for customer
                  </button>
                </div>
              </div>
            )}
          </div>
        </div>
      )}

      {/* ── Edit Customer Profile Modal ── */}
      {showEditModal && selectedUser && (
        <div
          style={{
            position: 'fixed',
            inset: 0,
            backgroundColor: 'rgba(15, 23, 27, 0.6)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            zIndex: 100,
            padding: '1rem'
          }}
          onClick={(e) => {
            if (e.target === e.currentTarget) setShowEditModal(false)
          }}
        >
          <div className="staff-card" style={{ width: '100%', maxWidth: '440px', padding: '1.75rem' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1.25rem' }}>
              <h3 style={{ margin: 0, fontSize: '1.125rem', fontWeight: 700, color: '#182126' }}>
                Edit profile · {selectedUser.name}
              </h3>
              <button
                type="button"
                className="btn-outline"
                style={{ height: '30px', padding: '0 0.5rem' }}
                onClick={() => setShowEditModal(false)}
              >
                ✕
              </button>
            </div>

            {editSuccess ? (
              <div className="banner-success" style={{ marginBottom: '1rem' }}>
                {editSuccess}
              </div>
            ) : (
              <form onSubmit={handleSaveEdit} style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
                {editError && (
                  <AlertBanner
                    type="error"
                    message={editError}
                    onDismiss={() => setEditError(null)}
                  />
                )}

                <div>
                  <label style={{ display: 'block', fontSize: '0.75rem', fontWeight: 700, marginBottom: '0.35rem', color: '#182126' }}>
                    Full Name *
                  </label>
                  <input
                    type="text"
                    required
                    value={editFormData.fullName}
                    onChange={(e) => setEditFormData(prev => ({ ...prev, fullName: e.target.value }))}
                    className="staff-search-box"
                    style={{ maxWidth: '100%', width: '100%' }}
                  />
                </div>

                <div>
                  <label style={{ display: 'block', fontSize: '0.75rem', fontWeight: 700, marginBottom: '0.35rem', color: '#182126' }}>
                    Phone Number
                  </label>
                  <input
                    type="text"
                    value={editFormData.phone}
                    onChange={(e) => setEditFormData(prev => ({ ...prev, phone: e.target.value }))}
                    className="staff-search-box"
                    style={{ maxWidth: '100%', width: '100%' }}
                  />
                </div>

                {isAdmin ? (
                  <>
                    <div>
                      <label style={{ display: 'block', fontSize: '0.75rem', fontWeight: 700, marginBottom: '0.35rem', color: '#182126' }}>
                        Role {isSelectedSelf && <span style={{ color: '#0f766e', fontWeight: 500 }}>(Locked for your active account)</span>}
                      </label>
                      <select
                        className="btn-outline"
                        style={{
                          width: '100%',
                          height: '38px',
                          padding: '0 0.75rem',
                          backgroundColor: isSelectedSelf ? '#f8fafc' : 'white',
                          cursor: isSelectedSelf ? 'not-allowed' : 'pointer',
                          color: isSelectedSelf ? '#64748b' : 'inherit'
                        }}
                        value={editFormData.role}
                        disabled={isSelectedSelf}
                        onChange={(e) => setEditFormData(prev => ({ ...prev, role: e.target.value }))}
                      >
                        <option value="Customer">Customer</option>
                        <option value="TravelAgent">Travel Agent</option>
                        <option value="Admin">Administrator</option>
                      </select>
                    </div>

                    {(editFormData.role === 'TravelAgent' || editFormData.role === 'Admin') && (
                      <div>
                        <label style={{ display: 'block', fontSize: '0.75rem', fontWeight: 700, marginBottom: '0.35rem', color: '#182126' }}>
                          Staff Department
                        </label>
                        <input
                          type="text"
                          placeholder="Tour Operations"
                          value={editFormData.department}
                          onChange={(e) => setEditFormData(prev => ({ ...prev, department: e.target.value }))}
                          className="staff-search-box"
                          style={{ maxWidth: '100%', width: '100%' }}
                        />
                      </div>
                    )}
                  </>
                ) : (
                  <div>
                    <label style={{ display: 'block', fontSize: '0.75rem', fontWeight: 700, marginBottom: '0.35rem', color: '#64748b' }}>
                      Assigned Role
                    </label>
                    <span className="badge-pill badge-gray" style={{ display: 'inline-block', marginTop: '0.25rem' }}>
                      {editFormData.role} {selectedUser.department ? `· ${selectedUser.department}` : ''}
                    </span>
                  </div>
                )}

                <div style={{ display: 'flex', gap: '0.5rem', marginTop: '0.5rem', justifyContent: 'flex-end' }}>
                  <button
                    type="button"
                    className="btn-outline"
                    onClick={() => setShowEditModal(false)}
                    disabled={editLoading}
                  >
                    Cancel
                  </button>
                  <button type="submit" className="btn-gold" disabled={editLoading}>
                    {editLoading ? 'Saving…' : 'Save Changes'}
                  </button>
                </div>
              </form>
            )}
          </div>
        </div>
      )}
    </div>
  )
}
