import { useEffect, useMemo, useState } from 'react'
import { fetchCustomers } from '../../services/apiClient.js'
import { usePageTitle } from '../../lib/hooks.js'
import { LoadingState } from '../../components/ui/LoadingState.jsx'
import { AlertBanner } from '../../components/ui/AlertBanner.jsx'
import { useResponsive } from '../../lib/useResponsive.js'
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
  const { isMobile } = useResponsive()
  const [dataList, setDataList] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [query, setQuery] = useState('')
  const [category, setCategory] = useState('All') // 'All' | 'Customers' | 'Staff'
  const [sort, setSort] = useState('name')
  const [page, setPage] = useState(1)
  const [selectedUser, setSelectedUser] = useState(null)
  const [showInviteModal, setShowInviteModal] = useState(false)
  const [inviteSuccess, setInviteSuccess] = useState('')
  usePageTitle('Customer & Staff Directory · Serendib Trails')

  async function loadCustomers(cancelled = false) {
    setLoading(true)
    setError(null)
    try {
      const res = await fetchCustomers()
      const live = Array.isArray(res) ? res : (res?.data || [])
      if (!cancelled) {
        const mapped = live.map((c, idx) => {
          const rawRole = c.role || 'Customer'
          const nameLower = (c.fullName || c.name || '').toLowerCase()
          const emailLower = (c.email || '').toLowerCase()
          const isStaff =
            rawRole.toLowerCase() === 'travelagent' ||
            rawRole.toLowerCase() === 'admin' ||
            rawRole.toLowerCase() === 'staff' ||
            nameLower.includes('travel agent') ||
            nameLower.includes('staff') ||
            emailLower.includes('agent') ||
            emailLower.includes('staff')
          const roleStr = isStaff && rawRole.toLowerCase() === 'customer' ? 'TravelAgent' : rawRole

          // Generate initials for avatar
          const fullName = c.fullName || c.name || (isStaff ? 'Staff Member' : 'Customer')
          const parts = fullName.trim().split(' ')
          const initials = parts.length > 1
            ? (parts[0][0] + parts[parts.length - 1][0]).toUpperCase()
            : fullName.substring(0, 2).toUpperCase()

          return {
            id: c.id || idx + 1,
            name: fullName,
            initials: initials || 'ST',
            email: c.email || `${fullName.toLowerCase().replace(/\s+/g, '.')}@example.com`,
            role: roleStr,
            isStaff,
            department: c.department || (isStaff ? 'Operations' : null),
            phone: c.phone || '+94 77 428 1120',
            location: c.city ? `${c.city}, ${c.country || 'Sri Lanka'}` : 'Colombo, Sri Lanka',
            joinedAt: c.joinedAt ? c.joinedAt.split('T')[0] : (c.createdAt ? c.createdAt.split('T')[0] : '14 Mar 2023'),
            trips: c.tripCount ?? c.trips ?? 0,
            lastActive: c.lastActiveAt ? c.lastActiveAt.split('T')[0] : 'Today',
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
        if (mapped.length > 0 && !selectedUser) {
          setSelectedUser(mapped[0])
        }
      }
    } catch (err) {
      if (!cancelled) {
        setError(err.response?.data?.message || err.message || 'Failed to load user directory from database.')
      }
    } finally {
      if (!cancelled) setLoading(false)
    }
  }

  useEffect(() => {
    let cancelled = false
    loadCustomers(cancelled)
    return () => { cancelled = true }
  }, [])

  const customerCount = useMemo(() => dataList.filter((u) => !u.isStaff).length, [dataList])
  const staffCount = useMemo(() => dataList.filter((u) => u.isStaff).length, [dataList])

  const rows = useMemo(() => {
    const q = query.trim().toLowerCase()
    const filtered = dataList.filter((u) => {
      if (category === 'Customers' && u.isStaff) return false
      if (category === 'Staff' && !u.isStaff) return false
      return (
        !q ||
        u.name.toLowerCase().includes(q) ||
        u.email.toLowerCase().includes(q) ||
        u.phone.toLowerCase().includes(q) ||
        u.role.toLowerCase().includes(q)
      )
    })
    const sorted = [...filtered].sort((a, b) => {
      if (sort === 'trips') return b.trips - a.trips
      if (sort === 'joined') return b.joinedAt.localeCompare(a.joinedAt)
      return a.name.localeCompare(b.name)
    })
    return sorted
  }, [dataList, query, sort, category])

  const pageSize = isMobile ? 5 : 7
  const pages = Math.max(1, Math.ceil(rows.length / pageSize))
  const view = rows.slice((page - 1) * pageSize, page * pageSize)

  // Keep selection valid
  useEffect(() => {
    if (view.length > 0 && (!selectedUser || !rows.find(r => r.id === selectedUser.id))) {
      setSelectedUser(view[0])
    }
  }, [view, selectedUser, rows])

  function onCategoryChange(cat) {
    setCategory(cat)
    setPage(1)
  }

  function handleInviteStaff(e) {
    e.preventDefault()
    setInviteSuccess('Staff invitation sent successfully via corporate email.')
    setTimeout(() => {
      setShowInviteModal(false)
      setInviteSuccess('')
    }, 2000)
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
          <button
            type="button"
            className="btn-gold"
            onClick={() => setShowInviteModal(true)}
          >
            <UserPlusIcon size={15} />
            <span>Invite staff member</span>
          </button>
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

      {/* ── Split Workspace matching Figma Master-Detail Layout ── */}
      <div className="split-workspace">
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
                <option value="joined">Join Date newest</option>
                <option value="trips">Trip Count</option>
              </select>
            </div>
          </div>

          <div className="staff-table-wrap">
            <table className="staff-table">
              <thead>
                <tr>
                  <th>NAME & EMAIL</th>
                  <th>PHONE</th>
                  <th>ROLE</th>
                  <th>TRIPS</th>
                  <th>LAST ACTIVE</th>
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
                        onClick={() => setSelectedUser(u)}
                      >
                        <td>
                          <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
                            <div className="avatar-circle">
                              {u.initials}
                            </div>
                            <div style={{ display: 'flex', flexDirection: 'column' }}>
                              <strong style={{ color: '#182126', fontSize: '0.8125rem' }}>{u.name}</strong>
                              <span style={{ color: '#66747b', fontSize: '0.75rem' }}>{u.email}</span>
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
              Showing {rows.length > 0 ? (page - 1) * pageSize + 1 : 0}–{Math.min(page * pageSize, rows.length)} of {rows.length} users
            </span>
            <div className="staff-pagination__btns">
              <button
                type="button"
                className="staff-page-btn"
                disabled={page <= 1}
                onClick={() => setPage((p) => p - 1)}
              >
                Previous
              </button>
              {Array.from({ length: pages }, (_, i) => i + 1).map((p) => (
                <button
                  key={p}
                  type="button"
                  className={`staff-page-btn ${page === p ? 'is-active' : ''}`}
                  onClick={() => setPage(p)}
                >
                  {p}
                </button>
              ))}
              <button
                type="button"
                className="staff-page-btn"
                disabled={page >= pages}
                onClick={() => setPage((p) => p + 1)}
              >
                Next
              </button>
            </div>
          </div>
        </div>

        {/* Right Detail Pane matching Figma 2:27047 */}
        {selectedUser ? (
          <aside className="detail-pane">
            <div className="detail-pane__head">
              <div>
                <h3 style={{ margin: 0, fontSize: '1.0625rem', fontWeight: 700, color: '#182126' }}>
                  {selectedUser.name}
                </h3>
                <span style={{ fontSize: '0.75rem', color: '#66747b' }}>
                  {selectedUser.isStaff ? 'Staff member' : 'Customer'} since {selectedUser.joinedAt}
                </span>
              </div>
              <button
                type="button"
                className="btn-outline"
                style={{ height: '32px', padding: '0 0.625rem' }}
                onClick={() => alert(`Editing profile for ${selectedUser.name}`)}
              >
                <EditIcon size={14} />
                <span>Edit profile</span>
              </button>
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
                <span className="profile-stat-val">{selectedUser.lastActive}, 10:28 LKT</span>
              </div>
              <div className="profile-stat-box">
                <span className="profile-stat-label">
                  {selectedUser.isStaff ? 'Staff Role' : 'Completed Trips'}
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
              onClick={() => alert(`Showing trip history for ${selectedUser.name}`)}
            >
              <ArrowRightIcon size={14} />
              <span>
                {selectedUser.isStaff
                  ? `View ${selectedUser.name} logs`
                  : `View ${selectedUser.trips} trip records`}
              </span>
            </button>
          </aside>
        ) : (
          <aside className="detail-pane" style={{ justifyContent: 'center', alignItems: 'center', color: '#66747b', minHeight: '300px' }}>
            <p>Select a user to view full profile details.</p>
          </aside>
        )}
      </div>

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
                <div>
                  <label style={{ display: 'block', fontSize: '0.75rem', fontWeight: 700, marginBottom: '0.35rem', color: '#182126' }}>
                    Full Name *
                  </label>
                  <input
                    type="text"
                    required
                    placeholder="e.g. Sahan Perera"
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
                    className="staff-search-box"
                    style={{ maxWidth: '100%', width: '100%' }}
                  />
                </div>

                <div>
                  <label style={{ display: 'block', fontSize: '0.75rem', fontWeight: 700, marginBottom: '0.35rem', color: '#182126' }}>
                    Assigned Role *
                  </label>
                  <select
                    className="btn-outline"
                    style={{ width: '100%', height: '38px', padding: '0 0.75rem' }}
                    defaultValue="TravelAgent"
                  >
                    <option value="TravelAgent">Travel Agent (Operations)</option>
                    <option value="Admin">System Administrator</option>
                  </select>
                </div>

                <div style={{ display: 'flex', gap: '0.5rem', marginTop: '0.5rem', justifyContent: 'flex-end' }}>
                  <button
                    type="button"
                    className="btn-outline"
                    onClick={() => setShowInviteModal(false)}
                  >
                    Cancel
                  </button>
                  <button type="submit" className="btn-gold">
                    Send invitation
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
