import { useEffect, useMemo, useState } from 'react'
import { fetchCustomers } from '../../services/apiClient.js'
import { usePageTitle } from '../../lib/hooks.js'

const PAGE_SIZE = 6

/** Student A — staff user directory dividing customers and staff members with separate filters, role badges & pagination. */
export default function CustomerDirectory() {
  const [dataList, setDataList] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [query, setQuery] = useState('')
  const [category, setCategory] = useState('All') // 'All' | 'Customers' | 'Staff'
  const [sort, setSort] = useState('name')
  const [page, setPage] = useState(1)
  const [selected, setSelected] = useState(null)
  usePageTitle('Directory · Staff')

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

          return {
            id: c.id || idx + 1,
            name: c.fullName || c.name || (isStaff ? 'Staff Member' : 'Customer'),
            email: c.email || c.id,
            role: roleStr,
            isStaff,
            department: c.department || (isStaff ? 'Operations' : null),
            phone: c.phone || 'N/A',
            hasPreference: !!c.hasPreference,
            joinedAt: c.joinedAt ? c.joinedAt.split('T')[0] : (c.createdAt ? c.createdAt.split('T')[0] : 'N/A'),
            trips: c.tripCount ?? c.trips ?? 0,
            lastActive: c.lastActiveAt ? c.lastActiveAt.split('T')[0] : (c.updatedAt ? c.updatedAt.split('T')[0] : 'Active'),
          }
        })
        setDataList(mapped)
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

  const pages = Math.max(1, Math.ceil(rows.length / PAGE_SIZE))
  const view = rows.slice((page - 1) * PAGE_SIZE, page * PAGE_SIZE)

  function onCategoryChange(cat) {
    setCategory(cat)
    setPage(1)
  }

  return (
    <div className="staff-page">
      <header className="staff-page__head">
        <div>
          <p className="eyebrow">Component A · Profiles & Directory</p>
          <h1>User & Customer directory</h1>
        </div>
        <div className="staff-toolbar">
          <input
            className="input"
            placeholder="Search name, email, or role…"
            value={query}
            onChange={(e) => {
              setQuery(e.target.value)
              setPage(1)
            }}
          />
          <select className="select" value={sort} onChange={(e) => setSort(e.target.value)} aria-label="Sort">
            <option value="name">Sort · Name</option>
            <option value="trips">Sort · Most trips</option>
            <option value="joined">Sort · Newest</option>
          </select>
          <button type="button" className="btn btn--sm" onClick={() => loadCustomers(false)} disabled={loading}>
            {loading ? 'Refreshing…' : 'Refresh'}
          </button>
        </div>
      </header>

      {error && (
        <div className="notice notice--error" style={{ color: '#ff6b6b' }}>
          {error}
        </div>
      )}

      {/* Directory division tabs: All Users vs Customers vs Staff Members */}
      <div style={{ display: 'flex', gap: '0.5rem', marginBottom: '1.25rem', flexWrap: 'wrap' }}>
        <button
          type="button"
          className="seg__btn"
          aria-pressed={category === 'All'}
          onClick={() => onCategoryChange('All')}
        >
          All Users ({dataList.length})
        </button>
        <button
          type="button"
          className="seg__btn"
          aria-pressed={category === 'Customers'}
          onClick={() => onCategoryChange('Customers')}
        >
          👤 Customers ({customerCount})
        </button>
        <button
          type="button"
          className="seg__btn"
          aria-pressed={category === 'Staff'}
          onClick={() => onCategoryChange('Staff')}
        >
          🛡️ Staff Members ({staffCount})
        </button>
      </div>

      <div className="panel panel--solid staff-table-wrap">
        <table className="staff-table">
          <thead>
            <tr>
              <th>Name</th>
              <th>Account Type</th>
              <th>Email</th>
              <th>Joined</th>
              <th>{category === 'Staff' ? 'Department' : 'Activity / Info'}</th>
              <th>Last active</th>
              <th />
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <tr>
                <td colSpan={7} className="staff-empty">Loading directory from database…</td>
              </tr>
            ) : view.length > 0 ? (
              view.map((c) => (
                <tr key={c.id}>
                  <td><b>{c.name}</b></td>
                  <td>
                    {c.isStaff ? (
                      <span
                        className="staff-pill"
                        style={{
                          background: 'rgba(59, 130, 246, 0.2)',
                          color: '#60a5fa',
                          border: '1px solid rgba(59, 130, 246, 0.4)',
                        }}
                      >
                        Staff · {c.role === 'TravelAgent' ? 'Travel Agent' : c.role}
                      </span>
                    ) : (
                      <span className="staff-pill staff-pill--confirmed">
                        Customer
                      </span>
                    )}
                  </td>
                  <td>{c.email}</td>
                  <td>{c.joinedAt}</td>
                  <td>
                    {c.isStaff ? (
                      <span className="staff-sub">{c.department || 'Operations Team'}</span>
                    ) : (
                      <span>{c.trips} trips</span>
                    )}
                  </td>
                  <td>{c.lastActive}</td>
                  <td>
                    <button type="button" className="staff-mini" onClick={() => setSelected(c)}>
                      View
                    </button>
                  </td>
                </tr>
              ))
            ) : (
              <tr>
                <td colSpan={7} className="staff-empty">
                  {query
                    ? `No ${category.toLowerCase()} match “${query}”.`
                    : `No ${category.toLowerCase()} found in database.`}
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>

      <div className="staff-pager">
        <button type="button" disabled={page <= 1} onClick={() => setPage((p) => p - 1)}>← Prev</button>
        <span>
          Page {page} of {pages} · {rows.length} {category === 'All' ? 'users' : category.toLowerCase()}
        </span>
        <button type="button" disabled={page >= pages} onClick={() => setPage((p) => p + 1)}>Next →</button>
      </div>

      {selected && (
        <div className="panel panel--solid staff-detail" style={{ marginTop: '1.25rem' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '0.75rem' }}>
            <div>
              <b style={{ fontSize: '1.1rem' }}>{selected.name}</b>
              <div style={{ marginTop: '0.25rem' }}>
                {selected.isStaff ? (
                  <span
                    className="staff-pill"
                    style={{
                      background: 'rgba(59, 130, 246, 0.2)',
                      color: '#60a5fa',
                      border: '1px solid rgba(59, 130, 246, 0.4)',
                    }}
                  >
                    Staff Member · {selected.role === 'TravelAgent' ? 'Travel Agent' : selected.role}
                  </span>
                ) : (
                  <span className="staff-pill staff-pill--confirmed">Customer Account</span>
                )}
              </div>
            </div>
            <button type="button" className="staff-mini" onClick={() => setSelected(null)}>Close</button>
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '0.75rem', fontSize: '0.9rem' }}>
            <div>
              <span className="staff-sub">Email:</span> <b>{selected.email}</b>
            </div>
            <div>
              <span className="staff-sub">Phone:</span> <b>{selected.phone}</b>
            </div>
            <div>
              <span className="staff-sub">Joined Date:</span> <b>{selected.joinedAt}</b>
            </div>
            <div>
              <span className="staff-sub">Last Active:</span> <b>{selected.lastActive}</b>
            </div>
            {selected.isStaff ? (
              <div>
                <span className="staff-sub">Department:</span> <b>{selected.department || 'Operations Team'}</b>
              </div>
            ) : (
              <>
                <div>
                  <span className="staff-sub">Trips Booked:</span> <b>{selected.trips}</b>
                </div>
                <div>
                  <span className="staff-sub">Travel Preferences:</span> <b>{selected.hasPreference ? 'Configured' : 'None yet'}</b>
                </div>
              </>
            )}
          </div>
        </div>
      )}
    </div>
  )
}
