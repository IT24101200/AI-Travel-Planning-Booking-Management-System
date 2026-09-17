import { useEffect, useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import { createTour, deleteTour, fetchDestinations, fetchTours, updateTour } from '../../services/apiClient.js'
import { usePageTitle } from '../../lib/hooks.js'

const PAGE_SIZE = 6
const MAX_IMAGE_BYTES = 5 * 1024 * 1024
const ALLOWED_IMAGE_TYPES = ['image/jpeg', 'image/png', 'image/webp']

/** Student B — tour catalog with real database CRUD + search / filter / sort / pagination. */
export default function TourCatalogManagement() {
  const [rows, setRows] = useState([])
  const [destinations, setDestinations] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [notice, setNotice] = useState('')
  const [query, setQuery] = useState('')
  const [category, setCategory] = useState('All')
  const [page, setPage] = useState(1)
  const [form, setForm] = useState({ name: '', destinationId: '', price: '', duration: '', category: 'Heritage' })
  const [image, setImage] = useState(null)
  const [imagePreview, setImagePreview] = useState('')
  const [imageInputKey, setImageInputKey] = useState(0)
  // Edit mode state
  const [editId, setEditId] = useState(null)
  const [editForm, setEditForm] = useState({})
  usePageTitle('Tours · Staff')

  async function loadTours(cancelled = false) {
    setLoading(true)
    setError(null)
    try {
      const [tourRes, destRes] = await Promise.allSettled([
        fetchTours(),
        fetchDestinations(),
      ])

      if (!cancelled) {
        if (destRes.status === 'fulfilled') {
          const destList = Array.isArray(destRes.value) ? destRes.value : (destRes.value?.data || [])
          setDestinations(destList)
          if (destList.length > 0 && !form.destinationId) {
            setForm((f) => ({ ...f, destinationId: destList[0].id }))
          }
        }

        if (tourRes.status === 'fulfilled') {
          const live = Array.isArray(tourRes.value) ? tourRes.value : (tourRes.value?.data || [])
          const mapped = live.map((t) => ({
            id: t.id,
            name: t.name,
            destination: t.destinationName || t.destination?.name || 'Sri Lanka',
            destinationId: t.destinationId || 1,
            price: t.price,
            duration: `${t.durationHours || 3} hrs`,
            durationHours: t.durationHours || 3,
            category: t.category || 'Heritage',
            status: t.status || 'Active',
          }))
          setRows(mapped)
        }
      }
    } catch (err) {
      if (!cancelled) {
        setError(err.response?.data?.message || err.message || 'Failed to load tours from database.')
      }
    } finally {
      if (!cancelled) setLoading(false)
    }
  }

  useEffect(() => {
    let cancelled = false
    loadTours(cancelled)
    return () => { cancelled = true }
  }, [])

  useEffect(() => () => {
    if (imagePreview) URL.revokeObjectURL(imagePreview)
  }, [imagePreview])

  const categories = useMemo(() => ['All', ...new Set(rows.map((r) => r.category))], [rows])

  const view = useMemo(() => {
    const q = query.trim().toLowerCase()
    return rows.filter(
      (r) =>
        (!q || r.name.toLowerCase().includes(q) || r.destination.toLowerCase().includes(q)) &&
        (category === 'All' || r.category === category),
    )
  }, [rows, query, category])

  const pages = Math.max(1, Math.ceil(view.length / PAGE_SIZE))
  const pageRows = view.slice((page - 1) * PAGE_SIZE, page * PAGE_SIZE)

  // Add a new tour to the database
  async function addTour(e) {
    e.preventDefault()
    if (destinations.length === 0) {
      setNotice('Create a destination first, then return here to add a tour.')
      return
    }
    if (!form.name.trim() || Number(form.price) <= 0) {
      setNotice('Please provide a valid tour name and price.')
      return
    }
    if (!image) {
      setNotice('Please select a JPEG, PNG, or WebP image for the tour.')
      return
    }

    try {
      const destId = Number(form.destinationId)
      const selectedDest = destinations.find((d) => d.id === destId)
      await createTour({
        name: form.name.trim(),
        description: `${form.duration.trim() || '3 hrs'} excursion in ${selectedDest?.name || 'Sri Lanka'}`,
        price: Number(form.price),
        durationHours: Number.parseInt(form.duration) || 3,
        category: form.category,
        destinationId: destId,
        currency: 'USD',
      }, image)
      setNotice(`Tour "${form.name.trim()}" added to database successfully.`)
      setForm({ name: '', destinationId: destinations[0]?.id || '', price: '', duration: '', category: 'Heritage' })
      setImage(null)
      setImagePreview('')
      setImageInputKey((key) => key + 1)
      await loadTours()
    } catch (err) {
      setNotice(`Failed to save tour: ${err.response?.data?.message || err.message}`)
    }
  }

  function selectImage(event) {
    const file = event.target.files?.[0]
    if (!file) return
    if (!ALLOWED_IMAGE_TYPES.includes(file.type)) {
      event.target.value = ''
      setImage(null)
      setImagePreview('')
      setNotice('Only JPEG, PNG, and WebP images are allowed.')
      return
    }
    if (file.size > MAX_IMAGE_BYTES) {
      event.target.value = ''
      setImage(null)
      setImagePreview('')
      setNotice('The image must be 5 MB or smaller.')
      return
    }
    setImage(file)
    setImagePreview(URL.createObjectURL(file))
    setNotice('')
  }

  // Start editing a row
  function startEdit(row) {
    setEditId(row.id)
    setEditForm({
      name: row.name,
      destinationId: row.destinationId || 1,
      price: row.price,
      duration: row.durationHours || 3,
      category: row.category,
    })
  }

  // Save the edit to the database
  async function saveEdit(id) {
    if (!editForm.name.trim()) return

    try {
      const destId = Number(editForm.destinationId) || 1
      const selectedDest = destinations.find((d) => d.id === destId)
      await updateTour(id, {
        name: editForm.name.trim(),
        description: `${editForm.duration || 3} hrs excursion in ${selectedDest?.name || 'Sri Lanka'}`,
        price: Number(editForm.price) || 50,
        durationHours: Number(editForm.duration) || 3,
        category: editForm.category,
        destinationId: destId,
      })
      setNotice(`Tour #${id} updated in database.`)
      setEditId(null)
      await loadTours()
    } catch (err) {
      setNotice(`Failed to update tour: ${err.response?.data?.message || err.message}`)
    }
  }

  // Toggle status (Active / Inactive)
  async function toggle(row) {
    const nextStatus = row.status === 'Active' ? 'Inactive' : 'Active'
    try {
      await updateTour(row.id, {
        name: row.name,
        price: row.price,
        durationHours: row.durationHours,
        category: row.category,
        destinationId: row.destinationId || 1,
        status: nextStatus,
      })
      setNotice(`Tour #${row.id} set to ${nextStatus}.`)
      await loadTours()
    } catch (err) {
      setNotice(`Status update failed: ${err.response?.data?.message || err.message}`)
    }
  }

  // Delete a tour from database
  async function remove(id) {
    if (!window.confirm(`Delete tour #${id}?`)) return
    try {
      await deleteTour(id)
      setNotice(`Tour #${id} deleted from database.`)
      await loadTours()
    } catch (err) {
      setNotice(`Delete failed: ${err.response?.data?.message || err.message}`)
    }
  }

  return (
    <div className="staff-page">
      <header className="staff-page__head">
        <div>
          <p className="eyebrow">Component B · Tours</p>
          <h1>Tour catalog</h1>
        </div>
        <div className="staff-toolbar">
          <input className="input" placeholder="Search tours…" value={query} onChange={(e) => { setQuery(e.target.value); setPage(1) }} />
          <select className="select" value={category} onChange={(e) => setCategory(e.target.value)} aria-label="Category">
            {categories.map((c) => (
              <option key={c} value={c}>{c}</option>
            ))}
          </select>
          <button type="button" className="btn btn--sm" onClick={() => loadTours(false)} disabled={loading}>
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

      <form className="panel panel--solid staff-form" onSubmit={addTour}>
        <b>Add tour to database</b>
        <div className="staff-form__grid">
          <input className="input" placeholder="Name" value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} required />
          {destinations.length > 0 ? (
            <select className="select" value={form.destinationId} onChange={(e) => setForm({ ...form, destinationId: e.target.value })}>
              {destinations.map((d) => (
                <option key={d.id} value={d.id}>{d.name}</option>
              ))}
            </select>
          ) : (
            <input className="input" value="No destinations available" disabled aria-label="No destinations available" />
          )}
          <input className="input" type="number" min="1" placeholder="Price USD" value={form.price} onChange={(e) => setForm({ ...form, price: e.target.value })} required />
          <input className="input" placeholder="Duration (e.g. 4 hrs)" value={form.duration} onChange={(e) => setForm({ ...form, duration: e.target.value })} />
          <select className="select" value={form.category} onChange={(e) => setForm({ ...form, category: e.target.value })}>
            <option>Heritage</option>
            <option>Rail journey</option>
            <option>Safari</option>
            <option>Marine</option>
            <option>Tea</option>
            <option>Snorkelling</option>
          </select>
          <input
            key={imageInputKey}
            className="input"
            type="file"
            accept="image/jpeg,image/png,image/webp"
            onChange={selectImage}
            required
            aria-label="Tour image"
          />
          <button
            className="btn btn--sm"
            type="submit"
            disabled={loading || destinations.length === 0}
            title={destinations.length === 0 ? 'Create a destination first' : 'Add tour'}
            style={destinations.length === 0 ? { opacity: 0.55, cursor: 'not-allowed' } : undefined}
          >
            Add
          </button>
        </div>
        {imagePreview && (
          <img
            src={imagePreview}
            alt="Selected tour preview"
            style={{ width: '180px', height: '110px', objectFit: 'cover', borderRadius: '12px', marginTop: '1rem' }}
          />
        )}
        {destinations.length === 0 && (
          <div className="notice notice--error">
            No destinations exist yet. <Link to="/staff/destinations">Open Destination Management</Link> and add one before creating a tour.
          </div>
        )}
      </form>

      <div className="panel panel--solid staff-table-wrap">
        <table className="staff-table">
          <thead>
            <tr>
              <th>Name</th>
              <th>Destination</th>
              <th>Price</th>
              <th>Duration</th>
              <th>Category</th>
              <th>Status</th>
              <th />
            </tr>
          </thead>
          <tbody>
            {loading ? (
              <tr><td colSpan={7} className="staff-empty">Loading tours from database…</td></tr>
            ) : pageRows.length > 0 ? (
              pageRows.map((r) => (
                <tr key={r.id}>
                  {editId === r.id ? (
                    <>
                      <td><input className="input input--sm" value={editForm.name} onChange={(e) => setEditForm({ ...editForm, name: e.target.value })} /></td>
                      <td>
                        {destinations.length > 0 ? (
                          <select className="select select--sm" value={editForm.destinationId} onChange={(e) => setEditForm({ ...editForm, destinationId: e.target.value })}>
                            {destinations.map((d) => (
                              <option key={d.id} value={d.id}>{d.name}</option>
                            ))}
                          </select>
                        ) : (
                          <input className="input input--sm" value={editForm.destinationId} onChange={(e) => setEditForm({ ...editForm, destinationId: e.target.value })} />
                        )}
                      </td>
                      <td><input className="input input--sm" type="number" min="1" value={editForm.price} onChange={(e) => setEditForm({ ...editForm, price: e.target.value })} /></td>
                      <td><input className="input input--sm" value={editForm.duration} onChange={(e) => setEditForm({ ...editForm, duration: e.target.value })} /></td>
                      <td>
                        <select className="select" value={editForm.category} onChange={(e) => setEditForm({ ...editForm, category: e.target.value })}>
                          <option>Heritage</option>
                          <option>Rail journey</option>
                          <option>Safari</option>
                          <option>Marine</option>
                          <option>Tea</option>
                          <option>Snorkelling</option>
                        </select>
                      </td>
                      <td><span className={`staff-pill staff-pill--${r.status.toLowerCase()}`}>{r.status}</span></td>
                      <td className="staff-row-actions">
                        <button type="button" className="btn btn--sm" onClick={() => saveEdit(r.id)}>Save</button>
                        <button type="button" className="staff-mini" onClick={() => setEditId(null)}>Cancel</button>
                      </td>
                    </>
                  ) : (
                    <>
                      <td><b>{r.name}</b></td>
                      <td>{r.destination}</td>
                      <td>${r.price}</td>
                      <td>{r.duration}</td>
                      <td><span className="chip">{r.category}</span></td>
                      <td><span className={`staff-pill staff-pill--${r.status.toLowerCase()}`}>{r.status}</span></td>
                      <td className="staff-row-actions">
                        <button type="button" className="staff-mini" onClick={() => startEdit(r)}>Edit</button>
                        <button type="button" className="staff-mini" onClick={() => toggle(r)}>
                          {r.status === 'Active' ? 'Deactivate' : 'Activate'}
                        </button>
                        <button type="button" className="staff-mini staff-mini--danger" onClick={() => remove(r.id)}>
                          Delete
                        </button>
                      </td>
                    </>
                  )}
                </tr>
              ))
            ) : (
              <tr><td colSpan={7} className="staff-empty">No tours found in database.</td></tr>
            )}
          </tbody>
        </table>
      </div>

      <div className="staff-pager">
        <button type="button" disabled={page <= 1} onClick={() => setPage((p) => p - 1)}>← Prev</button>
        <span>Page {page} of {pages} · {view.length} tours</span>
        <button type="button" disabled={page >= pages} onClick={() => setPage((p) => p + 1)}>Next →</button>
      </div>
    </div>
  )
}
