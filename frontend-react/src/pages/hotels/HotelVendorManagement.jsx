import { useEffect, useMemo, useState } from 'react'
import { createHotel, deleteHotel, fetchHotels, updateHotel } from '../../services/apiClient.js'
import { usePageTitle } from '../../lib/hooks.js'

const PAGE_SIZE = 6

/** Student C — hotel & vendor management with real database CRUD (add/edit/delete), room stats & pagination. */
export default function HotelVendorManagement() {
  const [rows, setRows] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [notice, setNotice] = useState('')
  const [query, setQuery] = useState('')
  const [page, setPage] = useState(1)
  const [form, setForm] = useState({ name: '', location: '', stars: '3' })
  // Edit mode state
  const [editId, setEditId] = useState(null)
  const [editForm, setEditForm] = useState({})
  usePageTitle('Hotels · Staff')

  async function loadHotels(cancelled = false) {
    setLoading(true)
    setError(null)
    try {
      const res = await fetchHotels()
      const live = Array.isArray(res) ? res : (res?.data || [])
      if (!cancelled) {
        const mapped = live.map((h) => {
          const rooms = Array.isArray(h.rooms) ? h.rooms : []
          const roomCount = rooms.reduce((acc, r) => acc + (r.totalRooms || 1), 0)
          const validPrices = rooms.map((r) => Number(r.pricePerNight) || 0).filter((p) => p > 0)
          const minPrice = validPrices.length > 0 ? Math.min(...validPrices) : null

          return {
            id: h.id,
            name: h.name,
            location: h.destinationName || h.address || 'Sri Lanka',
            address: h.address || '',
            destinationId: h.destinationId || 1,
            stars: h.starRating || 3,
            roomCount: roomCount || (rooms.length > 0 ? rooms.length : 0),
            minPrice,
            status: typeof h.status === 'number' ? (h.status === 0 ? 'Active' : 'Inactive') : (h.status || 'Active'),
          }
        })
        setRows(mapped)
      }
    } catch (err) {
      if (!cancelled) {
        setError(err.response?.data?.message || err.message || 'Failed to load hotels from database.')
      }
    } finally {
      if (!cancelled) setLoading(false)
    }
  }

  useEffect(() => {
    let cancelled = false
    loadHotels(cancelled)
    return () => { cancelled = true }
  }, [])

  const view = useMemo(() => {
    const q = query.trim().toLowerCase()
    return rows.filter((r) => !q || r.name.toLowerCase().includes(q) || r.location.toLowerCase().includes(q))
  }, [rows, query])

  const pages = Math.max(1, Math.ceil(view.length / PAGE_SIZE))
  const pageRows = view.slice((page - 1) * PAGE_SIZE, page * PAGE_SIZE)

  // Add a new hotel to the database
  async function add(e) {
    e.preventDefault()
    if (!form.name.trim() || !form.location.trim()) {
      setNotice('Please provide a name and address.')
      return
    }

    try {
      await createHotel({
        name: form.name.trim(),
        destinationId: 1,
        address: form.location.trim(),
        starRating: Number(form.stars) || 3,
      })
      setNotice(`Hotel "${form.name.trim()}" added to database.`)
      setForm({ name: '', location: '', stars: '3' })
      await loadHotels()
    } catch (err) {
      setNotice(`Failed to add hotel: ${err.response?.data?.message || err.message}`)
    }
  }

  // Start editing a hotel row
  function startEdit(row) {
    setEditId(row.id)
    setEditForm({
      name: row.name,
      location: row.address || row.location,
      destinationId: row.destinationId || 1,
      stars: row.stars,
    })
  }

  // Save the edit to the database
  async function saveEdit(id) {
    if (!editForm.name.trim()) return

    try {
      await updateHotel(id, {
        name: editForm.name.trim(),
        address: editForm.location.trim(),
        destinationId: editForm.destinationId || 1,
        starRating: Number(editForm.stars) || 3,
      })
      setNotice(`Hotel #${id} updated in database.`)
      setEditId(null)
      await loadHotels()
    } catch (err) {
      setNotice(`Failed to update hotel: ${err.response?.data?.message || err.message}`)
    }
  }

  // Delete a hotel from database
  async function remove(id) {
    if (!window.confirm(`Delete hotel #${id}?`)) return
    try {
      await deleteHotel(id)
      setNotice(`Hotel #${id} deleted from database.`)
      await loadHotels()
    } catch (err) {
      setNotice(`Delete failed: ${err.response?.data?.message || err.message}`)
    }
  }

  function onSearchChange(val) {
    setQuery(val)
    setPage(1)
  }

  return (
    <div className="staff-page">
      <header className="staff-page__head">
        <div>
          <p className="eyebrow">Component C · Accommodation</p>
          <h1>Hotels & vendors</h1>
        </div>
        <div className="staff-toolbar">
          <input className="input" placeholder="Search hotels…" value={query} onChange={(e) => onSearchChange(e.target.value)} />
          <button type="button" className="btn btn--sm" onClick={() => loadHotels(false)} disabled={loading}>
            {loading ? 'Refreshing…' : 'Refresh'}
          </button>
        </div>
      </header>

      {error && (
        <div className="notice notice--error" style={{ color: '#ff6b6b' }}>
          {error}
        </div>
      )}

      {notice && <div className="notice">{notice}</div>}

      <form className="panel panel--solid staff-form" onSubmit={add}>
        <b>Add hotel to database</b>
        <div className="staff-form__grid">
          <input className="input" placeholder="Name" value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} required />
          <input className="input" placeholder="Location / Address" value={form.location} onChange={(e) => setForm({ ...form, location: e.target.value })} required />
          <select className="select" value={form.stars} onChange={(e) => setForm({ ...form, stars: e.target.value })}>
            <option value="3">3 Stars</option>
            <option value="4">4 Stars</option>
            <option value="5">5 Stars</option>
          </select>
          <button className="btn btn--sm" type="submit" disabled={loading}>Add</button>
        </div>
      </form>

      <div className="panel panel--solid staff-table-wrap">
        <table className="staff-table">
          <thead>
            <tr>
              <th>Name</th>
              <th>Location</th>
              <th>Rating</th>
              <th>Rooms</th>
              <th>From / Night</th>
              <th>Status</th>
              <th />
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <tr><td colSpan={7} className="staff-empty">Loading hotels from database…</td></tr>
            ) : pageRows.length > 0 ? (
              pageRows.map((h) => (
                <tr key={h.id}>
                  {editId === h.id ? (
                    <>
                      <td><input className="input input--sm" value={editForm.name} onChange={(e) => setEditForm({ ...editForm, name: e.target.value })} /></td>
                      <td><input className="input input--sm" value={editForm.location} onChange={(e) => setEditForm({ ...editForm, location: e.target.value })} /></td>
                      <td>
                        <select className="select" value={editForm.stars} onChange={(e) => setEditForm({ ...editForm, stars: e.target.value })}>
                          <option value="3">3 Stars</option>
                          <option value="4">4 Stars</option>
                          <option value="5">5 Stars</option>
                        </select>
                      </td>
                      <td>{h.roomCount > 0 ? `${h.roomCount} rooms` : '—'}</td>
                      <td>{h.minPrice ? `$${h.minPrice}` : '—'}</td>
                      <td><span className={`staff-pill staff-pill--${h.status.toLowerCase()}`}>{h.status}</span></td>
                      <td className="staff-row-actions">
                        <button type="button" className="btn btn--sm" onClick={() => saveEdit(h.id)}>Save</button>
                        <button type="button" className="staff-mini" onClick={() => setEditId(null)}>Cancel</button>
                      </td>
                    </>
                  ) : (
                    <>
                      <td><b>{h.name}</b></td>
                      <td>{h.location}</td>
                      <td>{'★'.repeat(h.stars)}</td>
                      <td>{h.roomCount > 0 ? `${h.roomCount} rooms` : '—'}</td>
                      <td>{h.minPrice ? `$${h.minPrice}` : '—'}</td>
                      <td><span className={`staff-pill staff-pill--${h.status.toLowerCase()}`}>{h.status}</span></td>
                      <td className="staff-row-actions">
                        <button type="button" className="staff-mini" onClick={() => startEdit(h)}>Edit</button>
                        <button type="button" className="staff-mini staff-mini--danger" onClick={() => remove(h.id)}>
                          Delete
                        </button>
                      </td>
                    </>
                  )}
                </tr>
              ))
            ) : (
              <tr><td colSpan={7} className="staff-empty">No hotels found in database.</td></tr>
            )}
          </tbody>
        </table>
      </div>

      <div className="staff-pager">
        <button type="button" disabled={page <= 1} onClick={() => setPage((p) => p - 1)}>← Prev</button>
        <span>Page {page} of {pages} · {view.length} hotels</span>
        <button type="button" disabled={page >= pages} onClick={() => setPage((p) => p + 1)}>Next →</button>
      </div>
    </div>
  )
}
