import { useEffect, useMemo, useState } from 'react'
import { createHotel, deleteHotel, fetchDestinations, fetchHotels, updateHotel } from '../../services/apiClient.js'
import { usePageTitle } from '../../lib/hooks.js'
import { AlertBanner } from '../../components/ui/AlertBanner.jsx'

const PAGE_SIZE = 6

/** Student C — hotel & vendor management with real database CRUD (add/edit/delete), room stats & pagination. */
export default function HotelVendorManagement() {
  const [rows, setRows] = useState([])
  const [destinations, setDestinations] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [notice, setNotice] = useState('')
  const [query, setQuery] = useState('')
  const [page, setPage] = useState(1)
  const [form, setForm] = useState({ name: '', location: '', stars: '3', destinationId: '' })
  // Edit mode state
  const [editId, setEditId] = useState(null)
  const [editForm, setEditForm] = useState({})
  usePageTitle('Hotels · Staff')

  async function loadHotels(cancelled = false) {
    setLoading(true)
    setError(null)
    try {
      const [hotelsRes, destsRes] = await Promise.allSettled([
        fetchHotels(),
        fetchDestinations(),
      ])

      if (!cancelled) {
        if (destsRes.status === 'fulfilled') {
          const destList = Array.isArray(destsRes.value) ? destsRes.value : (destsRes.value?.data || [])
          setDestinations(destList)
          if (destList.length > 0) {
            setForm((f) => ({ ...f, destinationId: f.destinationId || destList[0].id }))
          }
        }

        if (hotelsRes.status === 'fulfilled') {
          const live = Array.isArray(hotelsRes.value) ? hotelsRes.value : (hotelsRes.value?.data || [])
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
      }
    } catch (err) {
      setError(err.response?.data?.message || err.message || 'Failed to load hotels from database.')
      return null
    } finally {
      setLoading(false)
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
        destinationId: Number(form.destinationId) || (destinations[0]?.id || 1),
        address: form.location.trim(),
        starRating: Number(form.stars) || 3,
      })
      setNotice(`Hotel "${form.name.trim()}" added to database.`)
      setForm({ name: '', location: '', stars: '3', destinationId: destinations[0]?.id || '' })
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
        destinationId: Number(editForm.destinationId) || 1,
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
        <AlertBanner
          type="error"
          message={error}
          onRetry={() => loadHotels(false)}
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
        <b>Add hotel to database</b>
        <div className="staff-form__grid">
          <input className="input" placeholder="Name" value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} required />
          <input className="input" placeholder="Address / Location" value={form.location} onChange={(e) => setForm({ ...form, location: e.target.value })} required />
          <select
            className="select"
            value={form.destinationId}
            onChange={(e) => setForm({ ...form, destinationId: e.target.value })}
            aria-label="Destination"
          >
            {destinations.map((d) => (
              <option key={d.id} value={d.id}>
                {d.name}
              </option>
            ))}
          </select>
          <select className="select" value={form.stars} onChange={(e) => setForm({ ...form, stars: e.target.value })}>
            <option value="3">3 Stars</option>
            <option value="4">4 Stars</option>
            <option value="5">5 Stars</option>
          </select>
          <button className="btn btn--sm" type="submit" disabled={loading}>Add</button>
        </div>

<<<<<<<<< Temporary merge branch 1
        {/* Right Detail / Edit Drawer matching Figma 2:28195 */}
        {drawerMode && (
          <aside className="detail-pane" style={{ position: 'sticky', top: '5.5rem' }}>
            <div className="detail-pane__head">
              <div>
                <h3 style={{ margin: 0, fontSize: '1.0625rem', fontWeight: 700, color: '#182126' }}>
                  {drawerMode === 'create' ? 'Add hotel partner' : 'Edit hotel partner'}
                </h3>
                <span style={{ fontSize: '0.75rem', color: '#66747b' }}>
                  {drawerMode === 'create' ? 'New vendor agreement' : `Vendor ID · ${selectedHotel?.code}`}
                </span>
              </div>
              <button
                type="button"
                className="btn-outline"
                style={{ height: '32px', padding: '0 0.625rem', color: '#182126', backgroundColor: '#ffffff', borderColor: '#c8d1d4' }}
                onClick={closeDrawer}
              >
                <CloseIcon size={14} />
                <span>Close</span>
              </button>
            </div>

            <form onSubmit={handleSave} noValidate style={{ display: 'flex', flexDirection: 'column', gap: '0.875rem' }}>
              <div>
                <label htmlFor="hotel-name" style={labelStyle}>Hotel name *</label>
                <input
                  id="hotel-name"
                  type="text"
                  placeholder="e.g. Jetwing Vil Uyana"
                  className="staff-search-box"
                  style={{ maxWidth: '100%', width: '100%' }}
                  value={formData.name}
                  onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                />
                {formErrors.name && <span style={errorStyle}>{formErrors.name}</span>}
              </div>

              {/* Cover Image Upload & Media Selection */}
              <div>
                <ImageUploadWidget
                  value={formData.imageUrl}
                  onChange={(url) => setFormData({ ...formData, imageUrl: url })}
                  category="hotels"
                  title="Hotel Cover Image"
                  description="Upload a photo to Supabase Cloud or pick from the media library."
                />
              </div>

              <div>
                <label htmlFor="hotel-destination" style={labelStyle}>Destination *</label>
                <select
                  id="hotel-destination"
                  className="staff-select"
                  style={selectStyle}
                  value={formData.destinationId}
                  onChange={(e) => setFormData({ ...formData, destinationId: e.target.value })}
                >
                  <option value="" style={optionStyle}>Select a destination</option>
                  {destinations.map((d) => (
                    <option key={d.id} value={d.id} style={optionStyle}>
                      {d.name}{d.country ? ` · ${d.country}` : ''}
                    </option>
                  ))}
                </select>
                {formErrors.destinationId && <span style={errorStyle}>{formErrors.destinationId}</span>}
              </div>

              <div>
                <label htmlFor="hotel-address" style={labelStyle}>Address *</label>
                <input
                  id="hotel-address"
                  type="text"
                  placeholder="e.g. 123 Main Street, Galle"
                  className="staff-search-box"
                  style={{ maxWidth: '100%', width: '100%' }}
                  value={formData.address}
                  onChange={(e) => setFormData({ ...formData, address: e.target.value })}
                />
                {formErrors.address && <span style={errorStyle}>{formErrors.address}</span>}
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '0.75rem' }}>
                <div>
                  <label htmlFor="hotel-email" style={labelStyle}>Contact Email</label>
                  <input
                    id="hotel-email"
                    type="email"
                    placeholder="e.g. info@hotel.com"
                    className="staff-search-box"
                    style={{ maxWidth: '100%', width: '100%' }}
                    value={formData.contactEmail}
                    onChange={(e) => setFormData({ ...formData, contactEmail: e.target.value })}
                  />
                  {formErrors.contactEmail && <span style={errorStyle}>{formErrors.contactEmail}</span>}
                </div>
                <div>
                  <label htmlFor="hotel-phone" style={labelStyle}>Contact Phone</label>
                  <input
                    id="hotel-phone"
                    type="text"
                    placeholder="e.g. +94 77 123 4567"
                    className="staff-search-box"
                    style={{ maxWidth: '100%', width: '100%' }}
                    value={formData.contactPhone}
                    onChange={(e) => setFormData({ ...formData, contactPhone: e.target.value })}
                  />
                  {formErrors.contactPhone && <span style={errorStyle}>{formErrors.contactPhone}</span>}
                </div>
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '0.75rem' }}>
                <div>
                  <label htmlFor="hotel-stars" style={labelStyle}>Star rating *</label>
                  <select
                    id="hotel-stars"
                    className="staff-select"
                    style={selectStyle}
                    value={formData.starRating}
                    onChange={(e) => setFormData({ ...formData, starRating: e.target.value })}
                  >
                    {[5, 4, 3, 2, 1].map(n => (
                      <option key={n} value={n} style={optionStyle}>{n} Star{n > 1 ? 's' : ''}</option>
                    ))}
                  </select>
                  {formErrors.starRating && <span style={errorStyle}>{formErrors.starRating}</span>}
                </div>

                <div>
                  <label htmlFor="hotel-rooms" style={labelStyle}>Total rooms</label>
                  <input
                    id="hotel-rooms"
                    type="text"
                    readOnly
                    className="staff-search-box"
                    style={{ maxWidth: '100%', width: '100%', backgroundColor: '#f8fafc' }}
                    value={drawerMode === 'edit' ? selectedHotel?.roomCount ?? 0 : 0}
                    title="Calculated from the hotel's room types"
                  />
                </div>
              </div>

              {drawerMode === 'edit' && selectedHotel && (
                <p style={{ margin: 0, fontSize: '0.75rem', color: '#66747b' }}>
                  Current status: <strong>{selectedHotel.status}</strong>
                </p>
              )}

              {/* Actions */}
              <div style={{ display: 'flex', gap: '0.5rem', marginTop: '0.5rem', justifyContent: 'flex-end', flexWrap: 'wrap' }}>
                <button
                  type="button"
                  className="btn-outline"
                  style={{ color: '#182126', backgroundColor: '#ffffff', borderColor: '#c8d1d4' }}
                  onClick={closeDrawer}
                >
                  <CloseIcon size={14} />
                  <span>Cancel</span>
                </button>
                {drawerMode === 'edit' && selectedHotel && (
                  <>
                    <button
                      type="button"
                      className="btn-outline"
                      disabled={busy}
                      style={{ color: '#182126', backgroundColor: '#ffffff', borderColor: '#c8d1d4' }}
                      onClick={() => toggleStatus(selectedHotel)}
                    >
                      {selectedHotel.status === 'Active' ? 'Set inactive' : 'Set active'}
                    </button>
                    <button
                      type="button"
                      className="btn-danger-soft"
                      disabled={busy}
                      onClick={() => handleDelete(selectedHotel)}
                    >
                      <TrashIcon size={14} />
                      <span>Delete hotel</span>
                    </button>
                  </>
                )}
                <button type="submit" className="btn-gold" disabled={busy}>
                  <CheckIcon size={14} />
                  <span>{busy ? 'Saving…' : (drawerMode === 'create' ? 'Add hotel' : 'Save changes')}</span>
                </button>
              </div>
            </form>
          </aside>
        )}
      </div>
    </div>
  )
}

// Read a readable error message from an API error
function getErrorMessage(err) {
  const data = err.response?.data
  if (data?.message) return data.message
  if (data?.errors) return Object.values(data.errors).flat().join(' ')
  if (data?.title) return data.title
  return err.message
}
