import { useEffect, useMemo, useState } from 'react'
import {
  createDestination,
  deleteDestination,
  fetchDestinations,
  updateDestination,
} from '../../services/apiClient.js'
import { usePageTitle } from '../../lib/hooks.js'

const PAGE_SIZE = 6

/** Student B — Destination catalog management with full CRUD and pagination. */
export default function DestinationManagement() {
  const [rows, setRows] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [notice, setNotice] = useState('')
  const [query, setQuery] = useState('')
  const [page, setPage] = useState(1)
  const [form, setForm] = useState({
    name: '',
    country: 'Sri Lanka',
    description: '',
    latitude: '',
    longitude: '',
  })
  // Edit mode state
  const [editId, setEditId] = useState(null)
  const [editForm, setEditForm] = useState({})
  usePageTitle('Destinations · Staff')

  async function loadDestinations(cancelled = false) {
    setLoading(true)
    setError(null)
    try {
      const res = await fetchDestinations()
      const live = Array.isArray(res) ? res : (res?.data || [])
      if (!cancelled) {
        const mapped = live.map((d) => ({
          id: d.id,
          name: d.name,
          country: d.country || 'Sri Lanka',
          description: d.description || '',
          latitude: d.latitude || 0,
          longitude: d.longitude || 0,
        }))
        setRows(mapped)
      }
    } catch (err) {
      if (!cancelled) {
        setError(err.response?.data?.message || err.message || 'Failed to load destinations from database.')
      }
    } finally {
      if (!cancelled) setLoading(false)
    }
  }

  useEffect(() => {
    let cancelled = false
    loadDestinations(cancelled)
    return () => { cancelled = true }
  }, [])

  const view = useMemo(() => {
    const q = query.trim().toLowerCase()
    return rows.filter(
      (r) => !q || r.name.toLowerCase().includes(q) || r.country.toLowerCase().includes(q) || r.description.toLowerCase().includes(q),
    )
  }, [rows, query])

  const pages = Math.max(1, Math.ceil(view.length / PAGE_SIZE))
  const pageRows = view.slice((page - 1) * PAGE_SIZE, page * PAGE_SIZE)

  // Add a new destination to database
  async function add(e) {
    e.preventDefault()
    if (!form.name.trim() || !form.country.trim()) {
      setNotice('Please provide a destination name and country.')
      return
    }

    try {
      await createDestination({
        name: form.name.trim(),
        country: form.country.trim(),
        description: form.description.trim() || null,
        latitude: Number(form.latitude) || 0,
        longitude: Number(form.longitude) || 0,
      })
      setNotice(`Destination "${form.name.trim()}" added to database.`)
      setForm({ name: '', country: 'Sri Lanka', description: '', latitude: '', longitude: '' })
      await loadDestinations()
    } catch (err) {
      setNotice(`Failed to add destination: ${err.response?.data?.message || err.message}`)
    }
  }

  // Start editing a destination
  function startEdit(row) {
    setEditId(row.id)
    setEditForm({
      name: row.name,
      country: row.country,
      description: row.description,
      latitude: row.latitude,
      longitude: row.longitude,
    })
  }

  // Save edit to database
  async function saveEdit(id) {
    if (!editForm.name.trim()) return

    try {
      await updateDestination(id, {
        name: editForm.name.trim(),
        country: editForm.country.trim() || 'Sri Lanka',
        description: editForm.description.trim() || null,
        latitude: Number(editForm.latitude) || 0,
        longitude: Number(editForm.longitude) || 0,
      })
      setNotice(`Destination #${id} updated in database.`)
      setEditId(null)
      await loadDestinations()
    } catch (err) {
      setNotice(`Failed to update destination: ${err.response?.data?.message || err.message}`)
    }
  }

  // Delete a destination from database
  async function remove(id) {
    if (!window.confirm(`Delete destination #${id}?`)) return
    try {
      await deleteDestination(id)
      setNotice(`Destination #${id} deleted from database.`)
      await loadDestinations()
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
          <p className="eyebrow">Component B · Destinations</p>
          <h1>Destination catalog</h1>
        </div>
        <div className="staff-toolbar">
          <input
            className="input"
            placeholder="Search destinations…"
            value={query}
            onChange={(e) => onSearchChange(e.target.value)}
          />
          <button type="button" className="btn btn--sm" onClick={() => loadDestinations(false)} disabled={loading}>
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
        <b>Add destination to database</b>
        <div className="staff-form__grid" style={{ gridTemplateColumns: 'repeat(auto-fit, minmax(140px, 1fr))' }}>
          <input
            className="input"
            placeholder="Destination Name"
            value={form.name}
            onChange={(e) => setForm({ ...form, name: e.target.value })}
            required
          />
          <input
            className="input"
            placeholder="Country"
            value={form.country}
            onChange={(e) => setForm({ ...form, country: e.target.value })}
            required
          />
          <input
            className="input"
            placeholder="Description (optional)"
            value={form.description}
            onChange={(e) => setForm({ ...form, description: e.target.value })}
          />
          <input
            className="input"
            type="number"
            step="any"
            placeholder="Latitude"
            value={form.latitude}
            onChange={(e) => setForm({ ...form, latitude: e.target.value })}
          />
          <input
            className="input"
            type="number"
            step="any"
            placeholder="Longitude"
            value={form.longitude}
            onChange={(e) => setForm({ ...form, longitude: e.target.value })}
          />
          <button className="btn btn--sm" type="submit" disabled={loading}>Add</button>
        </div>
      </form>

      <div className="panel panel--solid staff-table-wrap">
        <table className="staff-table">
          <thead>
            <tr>
              <th>ID</th>
              <th>Name</th>
              <th>Country</th>
              <th>Description</th>
              <th>Coordinates</th>
              <th />
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <tr><td colSpan={6} className="staff-empty">Loading destinations from database…</td></tr>
            ) : pageRows.length > 0 ? (
              pageRows.map((d) => (
                <tr key={d.id}>
                  {editId === d.id ? (
                    <>
                      <td>{d.id}</td>
                      <td><input className="input input--sm" value={editForm.name} onChange={(e) => setEditForm({ ...editForm, name: e.target.value })} /></td>
                      <td><input className="input input--sm" value={editForm.country} onChange={(e) => setEditForm({ ...editForm, country: e.target.value })} /></td>
                      <td><input className="input input--sm" value={editForm.description} onChange={(e) => setEditForm({ ...editForm, description: e.target.value })} /></td>
                      <td>
                        <span className="staff-sub">{editForm.latitude}, {editForm.longitude}</span>
                      </td>
                      <td className="staff-row-actions">
                        <button type="button" className="btn btn--sm" onClick={() => saveEdit(d.id)}>Save</button>
                        <button type="button" className="staff-mini" onClick={() => setEditId(null)}>Cancel</button>
                      </td>
                    </>
                  ) : (
                    <>
                      <td><b>#{d.id}</b></td>
                      <td><b>{d.name}</b></td>
                      <td>{d.country}</td>
                      <td>{d.description || '—'}</td>
                      <td>
                        <span className="staff-sub">{d.latitude.toFixed(2)}, {d.longitude.toFixed(2)}</span>
                      </td>
                      <td className="staff-row-actions">
                        <button type="button" className="staff-mini" onClick={() => startEdit(d)}>Edit</button>
                        <button type="button" className="staff-mini staff-mini--danger" onClick={() => remove(d.id)}>
                          Delete
                        </button>
                      </td>
                    </>
                  )}
                </tr>
              ))
            ) : (
              <tr><td colSpan={6} className="staff-empty">No destinations found in database.</td></tr>
            )}
          </tbody>
        </table>
      </div>

      <div className="staff-pager">
        <button type="button" disabled={page <= 1} onClick={() => setPage((p) => p - 1)}>← Prev</button>
        <span>Page {page} of {pages} · {view.length} destinations</span>
        <button type="button" disabled={page >= pages} onClick={() => setPage((p) => p + 1)}>Next →</button>
      </div>
    </div>
  )
}
