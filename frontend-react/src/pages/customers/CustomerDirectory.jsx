import { useEffect, useMemo, useState } from 'react'
import { mockCustomers } from '../../services/staffData.js'
import { fetchCustomers } from '../../services/apiClient.js'
import { usePageTitle } from '../../lib/hooks.js'

const PAGE_SIZE = 5

/** Student A — staff customer directory with search / sort / pagination. */
export default function CustomerDirectory() {
  const [dataList, setDataList] = useState(mockCustomers)
  const [query, setQuery] = useState('')
  const [sort, setSort] = useState('name')
  const [page, setPage] = useState(1)
  const [selected, setSelected] = useState(null)
  usePageTitle('Customers · Staff')

  useEffect(() => {
    let cancelled = false
    async function loadCustomers() {
      try {
        const live = await fetchCustomers()
        if (!cancelled && Array.isArray(live) && live.length > 0) {
          const mapped = live.map((c, idx) => ({
            id: c.id || idx + 1,
            name: c.fullName || c.name || 'Customer',
            email: c.email || c.id,
            joinedAt: c.createdAt ? c.createdAt.split('T')[0] : '2026-01-15',
            trips: c.tripCount || 1,
            lastActive: '2026-09-08',
          }))
          setDataList(mapped)
        }
      } catch {
        // Fallback to local mock data
      }
    }
    loadCustomers()
    return () => { cancelled = true }
  }, [])

  const rows = useMemo(() => {
    const q = query.trim().toLowerCase()
    const filtered = dataList.filter(
      (c) => !q || c.name.toLowerCase().includes(q) || c.email.toLowerCase().includes(q),
    )
    const sorted = [...filtered].sort((a, b) => {
      if (sort === 'trips') return b.trips - a.trips
      if (sort === 'joined') return b.joinedAt.localeCompare(a.joinedAt)
      return a.name.localeCompare(b.name)
    })
    return sorted
  }, [dataList, query, sort])

  const pages = Math.max(1, Math.ceil(rows.length / PAGE_SIZE))
  const view = rows.slice((page - 1) * PAGE_SIZE, page * PAGE_SIZE)

  return (
    <div className="staff-page">
      <header className="staff-page__head">
        <div>
          <p className="eyebrow">Component A · Profiles</p>
          <h1>Customer directory</h1>
        </div>
        <div className="staff-toolbar">
          <input
            className="input"
            placeholder="Search name or email…"
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
        </div>
      </header>

      <div className="panel panel--solid staff-table-wrap">
        <table className="staff-table">
          <thead>
            <tr>
              <th>Name</th>
              <th>Email</th>
              <th>Joined</th>
              <th>Trips</th>
              <th>Last active</th>
              <th />
            </tr>
          </thead>
          <tbody>
            {view.map((c) => (
              <tr key={c.id}>
                <td><b>{c.name}</b></td>
                <td>{c.email}</td>
                <td>{c.joinedAt}</td>
                <td>{c.trips}</td>
                <td>{c.lastActive}</td>
                <td>
                  <button type="button" className="staff-mini" onClick={() => setSelected(c)}>
                    View
                  </button>
                </td>
              </tr>
            ))}
            {!view.length && (
              <tr>
                <td colSpan={6} className="staff-empty">No customers match “{query}”.</td>
              </tr>
            )}
          </tbody>
        </table>
      </div>

      <div className="staff-pager">
        <button type="button" disabled={page <= 1} onClick={() => setPage((p) => p - 1)}>← Prev</button>
        <span>Page {page} of {pages} · {rows.length} customers</span>
        <button type="button" disabled={page >= pages} onClick={() => setPage((p) => p + 1)}>Next →</button>
      </div>

      {selected && (
        <div className="panel panel--solid staff-detail">
          <b>{selected.name}</b>
          <span>{selected.email} · joined {selected.joinedAt} · {selected.trips} trips · active {selected.lastActive}</span>
          <button type="button" className="staff-mini" onClick={() => setSelected(null)}>Close</button>
        </div>
      )}
    </div>
  )
}
