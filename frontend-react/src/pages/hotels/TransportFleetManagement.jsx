import { useEffect, useMemo, useState } from 'react'
import { createTransport, deleteTransport, fetchTransport, updateTransport } from '../../services/apiClient.js'
import { usePageTitle } from '../../lib/hooks.js'
import { AlertBanner } from '../../components/ui/AlertBanner.jsx'

const TRANSPORT_TYPES = ['Flight', 'Bus', 'Car', 'Train']
const PAGE_SIZE = 6

function formatScheduleTime(isoString) {
  if (!isoString) return '—'
  try {
    const d = new Date(isoString)
    if (isNaN(d.getTime())) return isoString
    return d.toLocaleString([], { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' })
  } catch {
    return isoString
  }
}

/** Student C — transport fleet with real database CRUD (add/edit/delete), schedule times + filter & pagination. */
export default function TransportFleetManagement() {
  const [rows, setRows] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [notice, setNotice] = useState('')
  const [type, setType] = useState('All')
  const [query, setQuery] = useState('')
  const [page, setPage] = useState(1)
  const [form, setForm] = useState({
    type: 'Car',
    provider: '',
    from: '',
    to: '',
    price: '',
    capacity: '',
    departureTime: '',
    arrivalTime: '',
  })
  // Edit mode state
  const [editId, setEditId] = useState(null)
  const [editForm, setEditForm] = useState({})
  usePageTitle('Transport · Staff')

  async function loadFleet(cancelled = false) {
    setLoading(true)
    setError(null)
    try {
      const res = await fetchTransport()
      const live = Array.isArray(res) ? res : (res?.data || [])
      if (!cancelled) {
        const mapped = live.map((t) => ({
          id: t.id,
          type: typeof t.type === 'number' ? (TRANSPORT_TYPES[t.type] || 'Car') : (t.type || 'Car'),
          provider: t.provider,
          from: t.routeFrom,
          to: t.routeTo,
          price: t.price,
          capacity: t.capacity,
          departureRaw: t.departureTime,
          arrivalRaw: t.arrivalTime,
          departureFormatted: formatScheduleTime(t.departureTime),
          arrivalFormatted: formatScheduleTime(t.arrivalTime),
        }))
        setRows(mapped)
      }
    } catch (err) {
      if (!cancelled) {
        setError(err.response?.data?.message || err.message || 'Failed to load transport from database.')
      }
    } finally {
      if (!cancelled) setLoading(false)
    }
  }

  useEffect(() => {
    let cancelled = false
    loadFleet(cancelled)
    return () => { cancelled = true }
  }, [])

  const view = useMemo(() => {
    const q = query.trim().toLowerCase()
    return rows.filter(
      (r) =>
        (type === 'All' || r.type === type) &&
        (!q || `${r.from} ${r.to} ${r.provider}`.toLowerCase().includes(q)),
    )
  }, [rows, type, query])

  const pages = Math.max(1, Math.ceil(view.length / PAGE_SIZE))
  const pageRows = view.slice((page - 1) * PAGE_SIZE, page * PAGE_SIZE)

  // Add departure to database
  async function add(e) {
    e.preventDefault()
    if (!form.provider.trim() || !form.from.trim() || !form.to.trim()) {
      setNotice('Please provide provider and departure/arrival locations.')
      return
    }

    try {
      const depDate = form.departureTime ? new Date(form.departureTime) : new Date()
      const arrDate = form.arrivalTime ? new Date(form.arrivalTime) : new Date(depDate.getTime() + 4 * 3600000)

      await createTransport({
        type: form.type,
        provider: form.provider.trim(),
        routeFrom: form.from.trim(),
        routeTo: form.to.trim(),
        price: Number(form.price) || 25,
        capacity: Number(form.capacity) || 4,
        departureTime: depDate.toISOString(),
        arrivalTime: arrDate.toISOString(),
      })
      setNotice(`Transport "${form.provider.trim()}" added to database.`)
      setForm({
        type: 'Car',
        provider: '',
        from: '',
        to: '',
        price: '',
        capacity: '',
        departureTime: '',
        arrivalTime: '',
      })
      await loadFleet()
    } catch (err) {
      setNotice(`Failed to add transport: ${err.response?.data?.message || err.message}`)
    }
  }

  // Start editing a transport row
  function startEdit(row) {
    setEditId(row.id)
    setEditForm({
      type: row.type,
      provider: row.provider,
      from: row.from,
      to: row.to,
      price: row.price,
      capacity: row.capacity,
      departureTime: row.departureRaw ? row.departureRaw.substring(0, 16) : '',
      arrivalTime: row.arrivalRaw ? row.arrivalRaw.substring(0, 16) : '',
    })
  }

  // Save the edit to database
  async function saveEdit(id) {
    if (!editForm.provider.trim()) return

    try {
      const depDate = editForm.departureTime ? new Date(editForm.departureTime) : new Date()
      const arrDate = editForm.arrivalTime ? new Date(editForm.arrivalTime) : new Date(depDate.getTime() + 4 * 3600000)

      await updateTransport(id, {
        type: editForm.type,
        provider: editForm.provider.trim(),
        routeFrom: editForm.from.trim(),
        routeTo: editForm.to.trim(),
        price: Number(editForm.price) || 20,
        capacity: Number(editForm.capacity) || 4,
        departureTime: depDate.toISOString(),
        arrivalTime: arrDate.toISOString(),
      })
      setNotice(`Transport #${id} updated in database.`)
      setEditId(null)
      await loadFleet()
    } catch (err) {
      setNotice(`Failed to update transport: ${err.response?.data?.message || err.message}`)
    }
  }

  // Delete a transport option from database
  async function remove(id) {
    if (!window.confirm(`Delete transport #${id}?`)) return
    try {
      await deleteTransport(id)
      setNotice(`Transport #${id} deleted from database.`)
      await loadFleet()
    } catch (err) {
      setNotice(`Delete failed: ${err.response?.data?.message || err.message}`)
    }
  }

  function onFilterType(newType) {
    setType(newType)
    setPage(1)
  }

  function onSearchChange(val) {
    setQuery(val)
    setPage(1)
  }

  return (
    <div className="staff-page">
      <header className="staff-page__head">
        <div>
          <p className="eyebrow">Component C · Transport</p>
          <h1>Transport fleet</h1>
        </div>
        <div className="staff-toolbar">
          <input className="input" placeholder="Search route or carrier…" value={query} onChange={(e) => onSearchChange(e.target.value)} />
          <select className="select" value={type} onChange={(e) => onFilterType(e.target.value)} aria-label="Transport type">
            <option value="All">All types</option>
            {TRANSPORT_TYPES.map((t) => (
              <option key={t} value={t}>{t}</option>
            ))}
          </select>
          <button type="button" className="btn btn--sm" onClick={() => loadFleet(false)} disabled={loading}>
            {loading ? 'Refreshing…' : 'Refresh'}
          </button>
        </div>
      </header>

      {error && (
        <AlertBanner
          type="error"
          message={error}
          onRetry={() => loadFleet(false)}
          onDismiss={() => setError(null)}
        />
      )}

      {notice && (
        <AlertBanner
          type={notice.includes('failed') || notice.includes('Failed') ? 'error' : 'success'}
          message={notice}
          onDismiss={() => setNotice('')}
        />
      )}

      <form className="panel panel--solid staff-form" onSubmit={add}>
        <b>Add transport departure to database</b>
        <div className="staff-form__grid" style={{ gridTemplateColumns: 'repeat(auto-fit, minmax(130px, 1fr))' }}>
          <select className="select" value={form.type} onChange={(e) => setForm({ ...form, type: e.target.value })}>
            {TRANSPORT_TYPES.map((t) => (
              <option key={t} value={t}>{t}</option>
            ))}
          </select>
          <input className="input" placeholder="Operator" value={form.provider} onChange={(e) => setForm({ ...form, provider: e.target.value })} required />
          <input className="input" placeholder="From" value={form.from} onChange={(e) => setForm({ ...form, from: e.target.value })} required />
          <input className="input" placeholder="To" value={form.to} onChange={(e) => setForm({ ...form, to: e.target.value })} required />
          <input className="input" type="datetime-local" title="Departure Time" value={form.departureTime} onChange={(e) => setForm({ ...form, departureTime: e.target.value })} />
          <input className="input" type="datetime-local" title="Arrival Time" value={form.arrivalTime} onChange={(e) => setForm({ ...form, arrivalTime: e.target.value })} />
          <input className="input" type="number" min="1" placeholder="Price USD" value={form.price} onChange={(e) => setForm({ ...form, price: e.target.value })} required />
          <input className="input" type="number" min="1" placeholder="Seats" value={form.capacity} onChange={(e) => setForm({ ...form, capacity: e.target.value })} />
          <button className="btn btn--sm" type="submit" disabled={loading}>Add</button>
        </div>
      </form>

      <div className="panel panel--solid staff-table-wrap">
        <table className="staff-table">
          <thead>
            <tr>
              <th>Type</th>
              <th>Operator</th>
              <th>Route</th>
              <th>Departure</th>
              <th>Arrival</th>
              <th>Seats</th>
              <th>Price</th>
              <th />
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <tr><td colSpan={8} className="staff-empty">Loading transport options from database…</td></tr>
            ) : pageRows.length > 0 ? (
              pageRows.map((r) => (
                <tr key={r.id}>
                  {editId === r.id ? (
                    <>
                      <td>
                        <select className="select" value={editForm.type} onChange={(e) => setEditForm({ ...editForm, type: e.target.value })}>
                          {TRANSPORT_TYPES.map((t) => (
                            <option key={t} value={t}>{t}</option>
                          ))}
                        </select>
                      </td>
                      <td><input className="input input--sm" value={editForm.provider} onChange={(e) => setEditForm({ ...editForm, provider: e.target.value })} /></td>
                      <td>
                        <div style={{ display: 'flex', gap: '0.25rem' }}>
                          <input className="input input--sm" placeholder="From" value={editForm.from} onChange={(e) => setEditForm({ ...editForm, from: e.target.value })} />
                          <span>→</span>
                          <input className="input input--sm" placeholder="To" value={editForm.to} onChange={(e) => setEditForm({ ...editForm, to: e.target.value })} />
                        </div>
                      </td>
                      <td>
                        <input className="input input--sm" type="datetime-local" value={editForm.departureTime} onChange={(e) => setEditForm({ ...editForm, departureTime: e.target.value })} />
                      </td>
                      <td>
                        <input className="input input--sm" type="datetime-local" value={editForm.arrivalTime} onChange={(e) => setEditForm({ ...editForm, arrivalTime: e.target.value })} />
                      </td>
                      <td><input className="input input--sm" type="number" min="1" value={editForm.capacity} onChange={(e) => setEditForm({ ...editForm, capacity: e.target.value })} /></td>
                      <td><input className="input input--sm" type="number" min="1" value={editForm.price} onChange={(e) => setEditForm({ ...editForm, price: e.target.value })} /></td>
                      <td className="staff-row-actions">
                        <button type="button" className="btn btn--sm" onClick={() => saveEdit(r.id)}>Save</button>
                        <button type="button" className="staff-mini" onClick={() => setEditId(null)}>Cancel</button>
                      </td>
                    </>
                  ) : (
                    <>
                      <td><span className="chip">{r.type}</span></td>
                      <td><b>{r.provider}</b></td>
                      <td>{r.from} → {r.to}</td>
                      <td><span className="staff-sub">{r.departureFormatted}</span></td>
                      <td><span className="staff-sub">{r.arrivalFormatted}</span></td>
                      <td>{r.capacity} seats</td>
                      <td>${r.price}</td>
                      <td className="staff-row-actions">
                        <button type="button" className="staff-mini" onClick={() => startEdit(r)}>Edit</button>
                        <button type="button" className="staff-mini staff-mini--danger" onClick={() => remove(r.id)}>
                          Delete
                        </button>
                      </td>
                    </>
                  )}
                </tr>
              ))
            ) : (
              <tr><td colSpan={8} className="staff-empty">No transport options found in database.</td></tr>
            )}
          </tbody>
        </table>
      </div>

      <div className="staff-pager">
        <button type="button" disabled={page <= 1} onClick={() => setPage((p) => p - 1)}>← Prev</button>
        <span>Page {page} of {pages} · {view.length} departures</span>
        <button type="button" disabled={page >= pages} onClick={() => setPage((p) => p + 1)}>Next →</button>
      </div>
    </div>
  )
}
