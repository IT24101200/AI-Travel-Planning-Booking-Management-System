import { useEffect, useMemo, useState } from 'react'
import { createHotel, fetchAllHotelsForStaff, updateHotel, deleteHotel, fetchDestinations } from '../../services/apiClient.js'
import { usePageTitle } from '../../lib/hooks.js'
import { AlertBanner } from '../../components/ui/AlertBanner.jsx'
import { LoadingState } from '../../components/ui/LoadingState.jsx'
import {
  PlusIcon,
  SearchIcon,
  RefreshIcon,
  CloseIcon,
  CheckIcon,
  EditIcon,
  TrashIcon
} from '../../components/ui/Icons.jsx'
import ImageUploadWidget from '../../components/common/ImageUploadWidget.jsx'

// Shared styles for labels, selects and inline errors
const labelStyle = { display: 'block', fontSize: '0.6875rem', fontWeight: 800, color: '#475569', textTransform: 'uppercase', marginBottom: '0.35rem' }
const selectStyle = {
  width: '100%',
  height: '38px',
  padding: '0 0.5rem',
  fontSize: '0.8125rem',
  color: '#182126',
  backgroundColor: '#ffffff',
  border: '1px solid #c8d1d4',
  borderRadius: '8px',
  colorScheme: 'light',
  opacity: 1
}
const optionStyle = { color: '#182126', backgroundColor: '#ffffff' }
const errorStyle = { color: '#b91c1c', fontSize: '0.6875rem', marginTop: '0.25rem', display: 'block' }

const pageSize = 6

const emptyForm = {
  name: '',
  destinationId: '',
  address: '',
  contactEmail: '',
  contactPhone: '',
  starRating: 5,
  imageUrl: '',
  status: 'Active'
}

// Convert a hotel from the API into a table row
function toRow(h, destinations) {
  const rooms = Array.isArray(h.rooms) ? h.rooms : []
  const roomCount = rooms.reduce((sum, r) => sum + (Number(r.totalRooms) || 0), 0)
  const prices = rooms.map(r => Number(r.pricePerNight)).filter(p => p > 0)
  const dest = destinations.find(d => d.id === h.destinationId)
  const status = typeof h.status === 'number'
    ? (h.status === 0 ? 'Active' : 'Inactive')
    : (String(h.status || '').toLowerCase() === 'inactive' ? 'Inactive' : 'Active')

  return {
    id: h.id,
    code: `HTL-${String(h.id).padStart(3, '0')}`,
    name: h.name,
    destinationId: h.destinationId,
    destination: dest?.name || 'Destination not provided',
    address: h.address || '',
    contactEmail: h.contactEmail || '',
    contactPhone: h.contactPhone || '',
    stars: Number(h.starRating) || 0,
    latitude: h.latitude || 0,
    longitude: h.longitude || 0,
    imageUrl: h.imageUrl || '',
    roomCount,
    minPrice: prices.length > 0 ? Math.min(...prices) : null,
    currency: rooms[0]?.currency || 'LKR',
    status
  }
}

/**
 * Serendib Trails — Hotel Vendor Console (staff)
 * List, create, edit, activate/deactivate and delete hotels.
 */
export default function HotelVendorManagement() {
  const [rows, setRows] = useState([])
  const [destinations, setDestinations] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [notice, setNotice] = useState('')
  const [query, setQuery] = useState('')
  const [page, setPage] = useState(1)

  // Drawer state
  const [drawerMode, setDrawerMode] = useState(null) // 'edit' | 'create' | null
  const [selectedHotel, setSelectedHotel] = useState(null)
  const [formData, setFormData] = useState(emptyForm)
  const [formErrors, setFormErrors] = useState({})
  const [busy, setBusy] = useState(false)

  usePageTitle('Hotel Vendor Console · Serendib Trails')

  // API call: load destinations + hotels, returns the new rows
  async function loadData() {
    setLoading(true)
    setError(null)
    try {
      const [hotelList, destRes] = await Promise.all([
        fetchAllHotelsForStaff(),
        fetchDestinations().catch(() => [])
      ])
      const destList = Array.isArray(destRes) ? destRes : (destRes?.data || [])
      const mapped = hotelList.map(h => toRow(h, destList))
      setDestinations(destList)
      setRows(mapped)
      return mapped
    } catch (err) {
      setError(err.response?.data?.message || err.message || 'Failed to load hotels from database.')
      return null
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect
    loadData()
  }, [])

  function closeDrawer() {
    setDrawerMode(null)
    setSelectedHotel(null)
    setFormErrors({})
  }

  function selectForEdit(hotel) {
    setSelectedHotel(hotel)
    setDrawerMode('edit')
    setFormErrors({})
    setFormData({
      name: hotel.name,
      destinationId: hotel.destinationId || '',
      address: hotel.address,
      contactEmail: hotel.contactEmail || '',
      contactPhone: hotel.contactPhone || '',
      starRating: hotel.stars >= 1 && hotel.stars <= 5 ? hotel.stars : 5,
      imageUrl: hotel.imageUrl || '',
      status: hotel.status
    })
  }

  function startCreate() {
    setDrawerMode('create')
    setSelectedHotel(null)
    setFormErrors({})
    setFormData({ ...emptyForm, destinationId: destinations[0]?.id || '' })
  }

  // Search filter + pagination
  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase()
    return rows.filter(r => !q || r.name.toLowerCase().includes(q) || r.destination.toLowerCase().includes(q))
  }, [rows, query])

  const pages = Math.max(1, Math.ceil(filtered.length / pageSize))
  const currentPage = Math.min(page, pages) // stay valid after deletes
  const view = filtered.slice((currentPage - 1) * pageSize, currentPage * pageSize)

  const totalRoomsLive = rows.filter(r => r.status === 'Active').reduce((sum, r) => sum + r.roomCount, 0)
  const activeCount = rows.filter(r => r.status === 'Active').length
  const inactiveCount = rows.length - activeCount

  // Validation for the hotel form
  function validateForm() {
    const errors = {}
    if (!formData.name.trim()) errors.name = 'Hotel name is required.'
    else if (formData.name.trim().length > 200) errors.name = 'Hotel name cannot exceed 200 characters.'
    if (!formData.address.trim()) errors.address = 'Address is required.'
    else if (formData.address.trim().length > 500) errors.address = 'Address cannot exceed 500 characters.'
    
    if (formData.contactEmail && formData.contactEmail.length > 256) errors.contactEmail = 'Email cannot exceed 256 characters.'
    else if (formData.contactEmail && !/\\S+@\\S+\\.\\S+/.test(formData.contactEmail)) errors.contactEmail = 'Invalid email address.'
    
    if (formData.contactPhone && formData.contactPhone.length > 30) errors.contactPhone = 'Phone cannot exceed 30 characters.'

    const destId = Number(formData.destinationId)
    if (!Number.isInteger(destId) || destId <= 0) errors.destinationId = 'Please select a destination.'
    const stars = Number(formData.starRating)
    if (stars < 1 || stars > 5) errors.starRating = 'Star rating must be between 1 and 5.'
    setFormErrors(errors)
    return Object.keys(errors).length === 0
  }

  // API call: create or update a hotel
  async function handleSave(e) {
    e.preventDefault()
    setNotice('')
    if (!validateForm()) return

    const payload = {
      name: formData.name.trim(),
      destinationId: Number(formData.destinationId),
      address: formData.address.trim(),
      contactEmail: formData.contactEmail?.trim() || null,
      contactPhone: formData.contactPhone?.trim() || null,
      imageUrl: formData.imageUrl || '',
      starRating: Number(formData.starRating),
      // keep existing map coordinates so editing does not reset them to 0
      latitude: selectedHotel?.latitude || 0,
      longitude: selectedHotel?.longitude || 0,
      status: formData.status
    }

    setBusy(true)
    try {
      if (drawerMode === 'create') {
        await createHotel(payload)
        setNotice(`Hotel "${payload.name}" created successfully.`)
      } else if (drawerMode === 'edit' && selectedHotel) {
        await updateHotel(selectedHotel.id, payload)
        setNotice(`Hotel "${payload.name}" updated successfully.`)
      }
      closeDrawer()
      await loadData()
    } catch (err) {
      setNotice(`Failed to save hotel: ${getErrorMessage(err)}`)
    } finally {
      setBusy(false)
    }
  }

  // API call: switch a hotel between Active and Inactive
  async function toggleStatus(hotel) {
    const nextStatus = hotel.status === 'Active' ? 'Inactive' : 'Active'
    setBusy(true)
    setNotice('')
    try {
      if (nextStatus === 'Inactive') {
        // Soft delete = mark as Inactive
        await deleteHotel(hotel.id, true)
      } else {
        await updateHotel(hotel.id, {
          name: hotel.name,
          destinationId: hotel.destinationId > 0 ? hotel.destinationId : (destinations[0]?.id || 1),
          address: hotel.address || `${hotel.name}, Sri Lanka`,
          contactEmail: hotel.contactEmail || null,
          contactPhone: hotel.contactPhone || null,
          imageUrl: hotel.imageUrl || '',
          starRating: hotel.stars >= 1 && hotel.stars <= 5 ? hotel.stars : 5,
          latitude: hotel.latitude,
          longitude: hotel.longitude,
          status: 'Active'
        })
      }

      // Reload and check the real status saved in the database
      const fresh = await loadData()
      const saved = fresh?.find(h => h.id === hotel.id)
      if (saved && saved.status !== nextStatus) {
        setNotice('Failed to change status: the server did not save it. Please deploy the latest backend code.')
      } else {
        setNotice(`Hotel "${hotel.name}" is now ${nextStatus}.`)
      }
      if (selectedHotel?.id === hotel.id && saved) selectForEdit(saved)
    } catch (err) {
      setNotice(`Failed to change status: ${getErrorMessage(err)}`)
    } finally {
      setBusy(false)
    }
  }

  // API call: permanently delete a hotel
  async function handleDelete(hotel) {
    if (!window.confirm(`Are you sure you want to delete hotel "${hotel.name}"? This cannot be undone.`)) return
    setBusy(true)
    setNotice('')
    try {
      await deleteHotel(hotel.id)
      if (selectedHotel?.id === hotel.id) closeDrawer()

      // Reload and check the hotel is really gone
      const fresh = await loadData()
      if (fresh?.some(h => h.id === hotel.id)) {
        setNotice(`Hotel "${hotel.name}" was only set to Inactive. The server needs the latest backend code for permanent delete.`)
      } else {
        setNotice(`Hotel "${hotel.name}" deleted successfully.`)
      }
    } catch (err) {
      setNotice(`Failed to delete hotel: ${getErrorMessage(err)}`)
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="staff-page">
      {/* ── Page Header ── */}
      <header className="staff-page__head">
        <div className="staff-page__title-block">
          <p className="staff-page__eyebrow">PARTNERS / ACCOMMODATION</p>
          <h1 className="staff-page__title">Hotel vendor console</h1>
          <p className="staff-page__subtitle">
            Manage accommodation partners, room inventory and hotel status.
          </p>
        </div>
        <div className="staff-page__actions">
          <button type="button" className="btn-outline" onClick={() => loadData()} disabled={loading}>
            <RefreshIcon size={15} />
            <span>{loading ? 'Refreshing…' : 'Refresh'}</span>
          </button>
          <button type="button" className="btn-gold" onClick={startCreate}>
            <PlusIcon size={15} />
            <span>Add hotel</span>
          </button>
        </div>
      </header>

      {/* ── Search + summary pills ── */}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: '1rem', flexWrap: 'wrap' }}>
        <div className="staff-search-box" style={{ maxWidth: '320px' }}>
          <SearchIcon size={16} />
          <input
            type="text"
            placeholder="Search hotel or destination"
            value={query}
            onChange={(e) => {
              setQuery(e.target.value)
              setPage(1)
            }}
          />
        </div>

        <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem', flexWrap: 'wrap' }}>
          <span className="badge-pill badge-green" style={{ fontSize: '0.75rem', padding: '0.35rem 0.75rem' }}>
            <span className="badge-dot" /> {totalRoomsLive} rooms live
          </span>
          <span className="badge-pill badge-amber" style={{ fontSize: '0.75rem', padding: '0.35rem 0.75rem' }}>
            <span className="badge-dot" /> {activeCount} active · {inactiveCount} inactive
          </span>
        </div>
      </div>

      {error && (
        <AlertBanner type="error" message={error} onRetry={() => loadData()} onDismiss={() => setError(null)} />
      )}

      {notice && (
        <AlertBanner
          type={notice.startsWith('Failed') || notice.includes('only set to Inactive') ? 'error' : 'success'}
          message={notice}
          onDismiss={() => setNotice('')}
        />
      )}

      {/* ── Table + Drawer ── */}
      <div className="split-workspace" style={{ gridTemplateColumns: drawerMode ? 'minmax(0, 1fr) 420px' : '1fr' }}>
        {/* Left Table Card */}
        <div className="staff-card">
          <div className="staff-card__head">
            <div>
              <h3 className="staff-card__title">Hotel partners</h3>
              <p className="staff-card__sub">{filtered.length} shown · rooms and prices from room inventory</p>
            </div>
          </div>

          <div className="staff-table-wrap">
            <table className="staff-table">
              <thead>
                <tr>
                  <th>HOTEL NAME</th>
                  <th>DESTINATION / REGION</th>
                  <th>RATING</th>
                  <th>ROOMS</th>
                  <th>PRICE / NIGHT</th>
                  <th>STATUS</th>
                  <th style={{ textAlign: 'right' }}>ACTIONS</th>
                </tr>
              </thead>
              <tbody>
                {loading && rows.length === 0 ? (
                  <tr>
                    <td colSpan={7} style={{ textAlign: 'center', padding: '2.5rem' }}>
                      <LoadingState message="Loading hotel partners from database…" />
                    </td>
                  </tr>
                ) : view.length > 0 ? (
                  view.map((h) => {
                    const isSelected = selectedHotel?.id === h.id && drawerMode === 'edit'
                    return (
                      <tr
                        key={h.id}
                        className={isSelected ? 'is-selected' : ''}
                        style={{ cursor: 'pointer', opacity: h.status === 'Inactive' ? 0.75 : 1 }}
                        onClick={() => selectForEdit(h)}
                      >
                        <td>
                          <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
                            {h.imageUrl ? (
                              <img
                                src={h.imageUrl}
                                alt={h.name}
                                style={{ width: '48px', height: '38px', objectFit: 'cover', borderRadius: '5px', border: '1px solid #d0d7de', flexShrink: 0 }}
                                onError={(e) => { e.target.style.display = 'none' }}
                              />
                            ) : (
                              <div
                                style={{
                                  width: '48px', height: '38px', background: '#f1f5f9', borderRadius: '5px',
                                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                                  color: '#64748b', fontSize: '0.625rem', fontWeight: 700, flexShrink: 0
                                }}
                              >
                                HOTEL
                              </div>
                            )}
                            <div style={{ display: 'flex', flexDirection: 'column' }}>
                              <strong style={{ color: '#182126', fontSize: '0.8125rem' }}>{h.name}</strong>
                              <span style={{ fontSize: '0.6875rem', color: '#66747b', marginTop: '4px' }}>
                                {h.address || 'Address not provided'}
                              </span>
                            </div>
                          </div>
                        </td>
                        <td style={{ color: '#66747b', fontSize: '0.75rem' }}>{h.destination}</td>
                        <td>
                          <span style={{ color: '#b7791f', letterSpacing: '1px', fontSize: '0.75rem' }}>
                            {h.stars > 0 ? '★'.repeat(h.stars) : 'Not rated'}
                          </span>
                        </td>
                        <td style={{ fontWeight: 600, color: '#182126' }}>{h.roomCount}</td>
                        <td style={{ fontWeight: 700, color: '#182126' }}>
                          {h.minPrice != null ? `From ${h.currency} ${h.minPrice.toLocaleString()}` : 'Not provided'}
                        </td>
                        <td onClick={(e) => e.stopPropagation()}>
                          <div style={{ display: 'inline-flex', alignItems: 'center', gap: '0.5rem' }}>
                            <span className={`badge-pill ${h.status === 'Active' ? 'badge-green' : 'badge-gray'}`}>
                              <span className="badge-dot" /> {h.status}
                            </span>
                            <button
                              type="button"
                              className="btn-outline"
                              disabled={busy}
                              style={{
                                height: '26px',
                                padding: '0 0.5rem',
                                fontSize: '0.6875rem',
                                fontWeight: 700,
                                color: h.status === 'Active' ? '#b45309' : '#047857',
                                backgroundColor: '#ffffff',
                                borderColor: h.status === 'Active' ? '#fde68a' : '#a7f3d0'
                              }}
                              onClick={() => toggleStatus(h)}
                              title={h.status === 'Active' ? 'Set hotel partner inactive' : 'Set hotel partner active'}
                            >
                              {h.status === 'Active' ? 'Set inactive' : 'Set active'}
                            </button>
                          </div>
                        </td>
                        <td style={{ textAlign: 'right' }} onClick={(e) => e.stopPropagation()}>
                          <div style={{ display: 'inline-flex', alignItems: 'center', gap: '0.375rem' }}>
                            <button type="button" className="btn-action-edit" title="Edit Hotel" onClick={() => selectForEdit(h)}>
                              <EditIcon size={12} />
                              <span>Edit</span>
                            </button>
                            <button
                              type="button"
                              className="btn-action-delete"
                              title="Delete Hotel"
                              disabled={busy}
                              onClick={() => handleDelete(h)}
                            >
                              <TrashIcon size={12} />
                              <span>Delete</span>
                            </button>
                          </div>
                        </td>
                      </tr>
                    )
                  })
                ) : (
                  <tr>
                    <td colSpan={7} style={{ textAlign: 'center', padding: '2rem', color: '#66747b' }}>
                      {query ? `No hotels match “${query}”.` : 'No hotels yet. Click "Add hotel" to create one.'}
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>

          {/* Pagination */}
          <div className="staff-pagination">
            <span>
              Showing {filtered.length > 0 ? (currentPage - 1) * pageSize + 1 : 0}–{Math.min(currentPage * pageSize, filtered.length)} of {filtered.length} hotels
            </span>
            <div className="staff-pagination__btns">
              <button type="button" className="staff-page-btn" disabled={currentPage <= 1} onClick={() => setPage(currentPage - 1)}>
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
              <button type="button" className="staff-page-btn" disabled={currentPage >= pages} onClick={() => setPage(currentPage + 1)}>
                Next
              </button>
            </div>
          </div>
        </div>

        {/* Right Create / Edit Drawer */}
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
