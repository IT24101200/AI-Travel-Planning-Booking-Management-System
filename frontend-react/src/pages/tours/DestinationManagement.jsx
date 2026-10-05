import { useEffect, useMemo, useState } from 'react'
import {
  createDestination,
  deleteDestination,
  fetchDestinations,
  updateDestination,
  fetchTours
} from '../../services/apiClient.js'
import { usePageTitle } from '../../lib/hooks.js'
import { AlertBanner } from '../../components/ui/AlertBanner.jsx'
import { LoadingState } from '../../components/ui/LoadingState.jsx'
import {
  PlusIcon,
  SearchIcon,
  MapPinIcon,
  RefreshIcon,
  TrashIcon,
  CloseIcon,
  CheckIcon,
  EditIcon
} from '../../components/ui/Icons.jsx'
import { ImageUploadWidget } from '../../components/common/ImageUploadWidget.jsx'

// Province mapping for Sri Lankan destinations
const REGIONS = {
  sigiriya: 'Central Province',
  kandy: 'Central Province',
  'nuwara eliya': 'Central Province',
  ella: 'Uva Province',
  mirissa: 'Southern Province',
  yala: 'Southern Province',
  trincomalee: 'Eastern Province',
  colombo: 'Western Province',
  galle: 'Southern Province',
  jaffna: 'Northern Province'
}

/**
 * Serendib Trails — Destination Catalog
 * Designed based on Figma Dev Mode Specifications (node-id: 2:27727)
 */
export default function DestinationManagement() {
  const [rows, setRows] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [notice, setNotice] = useState('')
  const [query, setQuery] = useState('')
  const [page, setPage] = useState(1)

  // Drawer state
  const [drawerMode, setDrawerMode] = useState(null) // 'edit' | 'create' | null
  const [selectedDest, setSelectedDest] = useState(null)
  const [drawerNotice, setDrawerNotice] = useState(null) // { type: 'success' | 'error', message: string } | null

  // Visual Remove Modal State
  const [destToDelete, setDestToDelete] = useState(null)
  const [deleteBusy, setDeleteBusy] = useState(false)
  const [deleteError, setDeleteError] = useState(null)

  const [formData, setFormData] = useState({
    name: '',
    country: 'Sri Lanka',
    description: '',
    latitude: '',
    longitude: '',
    imageUrl: ''
  })
  const [busy, setBusy] = useState(false)

  usePageTitle('Destination Catalog · Serendib Trails')

  async function loadData(cancelled = false, selectId = null) {
    setLoading(true)
    setError(null)
    try {
      const [destRes, tourRes] = await Promise.allSettled([
        fetchDestinations(),
        fetchTours({ pageSize: 1000 })
      ])

      if (!cancelled) {
        // Map tour counts per destination
        const counts = {}
        if (tourRes.status === 'fulfilled') {
          const tList = Array.isArray(tourRes.value) ? tourRes.value : (tourRes.value?.data || [])
          tList.forEach(t => {
            const dId = t.destinationId
            counts[dId] = (counts[dId] || 0) + 1
          })
        }
        if (destRes.status === 'fulfilled') {
          const live = Array.isArray(destRes.value) ? destRes.value : (destRes.value?.data || [])
          const mapped = live.map((d, idx) => {
            const nameLower = (d.name || '').toLowerCase()
            let region = 'Central Province'
            for (const [key, val] of Object.entries(REGIONS)) {
              if (nameLower.includes(key)) {
                region = val
                break
              }
            }

            return {
              id: d.id,
              code: `DEST-${String(idx + 1).padStart(3, '0')}`,
              name: d.name || 'Unnamed Destination',
              country: d.country || 'Sri Lanka',
              region,
              imageUrl: d.imageUrl || '',
              description: d.description || `Ancient fortress and UNESCO heritage site surrounded by gardens and forest in ${d.name || 'Sri Lanka'}.`,
              latitude: Number(d.latitude) || 7.9570,
              longitude: Number(d.longitude) || 80.7603,
              associatedTours: counts[d.id] || 0
            }
          })
          setRows(mapped)

          if (selectId) {
            const target = mapped.find(d => d.id === selectId)
            if (target) {
              selectForEdit(target)
            }
          } else if (mapped.length > 0 && !selectedDest && drawerMode !== 'create') {
            selectForEdit(mapped[0])
          }
        }
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
    // This starts an async API load; its state updates occur after the request.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    loadData(cancelled)
    return () => { cancelled = true }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  function selectForEdit(dest) {
    setSelectedDest(dest)
    setDrawerMode('edit')
    setDrawerNotice(null)
    setFormData({
      name: dest.name,
      country: dest.country,
      description: dest.description,
      latitude: dest.latitude,
      longitude: dest.longitude,
      imageUrl: dest.imageUrl || ''
    })
  }

  function startCreate() {
    setDrawerMode('create')
    setSelectedDest(null)
    setDrawerNotice(null)
    setFormData({
      name: '',
      country: 'Sri Lanka',
      description: '',
      latitude: '7.957032',
      longitude: '80.760261',
      imageUrl: ''
    })
  }

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase()
    return rows.filter(
      (r) =>
        !q ||
        r.name.toLowerCase().includes(q) ||
        r.region.toLowerCase().includes(q) ||
        r.country.toLowerCase().includes(q)
    )
  }, [rows, query])

  const pageSize = 7
  const pages = Math.max(1, Math.ceil(filtered.length / pageSize))
  const view = filtered.slice((page - 1) * pageSize, page * pageSize)

  async function handleSave(e) {
    e.preventDefault()
    if (!formData.name.trim() || !formData.country.trim()) {
      const msg = 'Please provide a destination name and country.'
      setNotice(msg)
      setDrawerNotice({ type: 'error', message: msg })
      return
    }
    setBusy(true)
    setNotice('')
    setDrawerNotice(null)
    try {
      if (drawerMode === 'create') {
        const created = await createDestination({
          name: formData.name.trim(),
          country: formData.country.trim(),
          description: formData.description.trim() || null,
          imageUrl: formData.imageUrl?.trim() || null,
          latitude: Number(formData.latitude) || 0,
          longitude: Number(formData.longitude) || 0,
        })
        const displayName = created?.name || formData.name.trim()
        const msg = `Destination "${displayName}" created successfully.`
        setNotice(msg)
        setDrawerNotice({ type: 'success', message: msg })
        await loadData(false, created?.id)
      } else if (drawerMode === 'edit' && selectedDest) {
        await updateDestination(selectedDest.id, {
          name: formData.name.trim(),
          country: formData.country.trim(),
          description: formData.description.trim() || null,
          imageUrl: formData.imageUrl?.trim() || null,
          latitude: Number(formData.latitude) || 0,
          longitude: Number(formData.longitude) || 0,
        })
        const msg = `Destination #${selectedDest.id} updated successfully.`
        setNotice(msg)
        setDrawerNotice({ type: 'success', message: msg })
        await loadData(false, selectedDest.id)
      }
    } catch (err) {
      const errMsg = err.response?.data?.message || err.message || 'Failed to save destination.'
      setNotice(`Failed to save destination: ${errMsg}`)
      setDrawerNotice({ type: 'error', message: `Failed to save: ${errMsg}` })
    } finally {
      setBusy(false)
    }
  }

  function requestRemove(dest) {
    setDestToDelete(dest)
    setDeleteError(null)
  }

  async function confirmRemove() {
    if (!destToDelete) return
    setDeleteBusy(true)
    setDeleteError(null)
    try {
      await deleteDestination(destToDelete.id)
      const name = destToDelete.name || `#${destToDelete.id}`
      setNotice(`Destination "${name}" was permanently removed.`)
      setDestToDelete(null)
      if (selectedDest?.id === destToDelete.id) {
        setDrawerMode(null)
        setSelectedDest(null)
      }
      await loadData()
    } catch (err) {
      setDeleteError(err.response?.data?.message || err.message || 'Failed to delete destination.')
    } finally {
      setDeleteBusy(false)
    }
  }

  return (
    <div className="staff-page">
      {/* ── Page Header matching Figma 2:27727 ── */}
      <header className="staff-page__head">
        <div className="staff-page__title-block">
          <p className="staff-page__eyebrow">CATALOG / PLACES</p>
          <h1 className="staff-page__title">Destination catalog</h1>
          <p className="staff-page__subtitle">
            Maintain geographic records referenced by tours, hotels, and route planning.
          </p>
        </div>
        <div className="staff-page__actions">
          <button
            type="button"
            className="btn-outline"
            onClick={() => loadData(false)}
            disabled={loading}
          >
            <RefreshIcon size={15} />
            <span>{loading ? 'Refreshing…' : 'Refresh'}</span>
          </button>
          <button
            type="button"
            className="btn-gold"
            onClick={startCreate}
          >
            <PlusIcon size={15} />
            <span>Create destination</span>
          </button>
        </div>
      </header>

      {error && (
        <AlertBanner
          type="error"
          message={error}
          onRetry={() => loadData(false)}
          onDismiss={() => setError(null)}
        />
      )}

      {notice && (
        <AlertBanner
          type={notice.startsWith('Failed') || notice.startsWith('Delete failed') ? 'error' : 'success'}
          message={notice}
          onDismiss={() => setNotice('')}
        />
      )}

      {/* ── Split Workspace matching Figma 2:27727 ── */}
      <div className="split-workspace">
        {/* Left Table Card */}
        <div className="staff-card">
          <div className="staff-card__head">
            <div>
              <h3 className="staff-card__title">Sri Lanka destinations</h3>
              <p className="staff-card__sub">
                {rows.length} active records · {rows.reduce((acc, r) => acc + r.associatedTours, 0)} associated tours
              </p>
            </div>
            <div className="staff-search-box">
              <SearchIcon size={16} />
              <input
                type="text"
                placeholder="Search destinations"
                value={query}
                onChange={(e) => {
                  setQuery(e.target.value)
                  setPage(1)
                }}
              />
            </div>
          </div>

          <div className="staff-table-wrap">
            <table className="staff-table">
              <thead>
                <tr>
                  <th>DESTINATION</th>
                  <th>COUNTRY</th>
                  <th>REGION</th>
                  <th>LATITUDE / LONGITUDE</th>
                  <th>ASSOCIATED TOURS</th>
                  <th style={{ textAlign: 'right' }}>ACTIONS</th>
                </tr>
              </thead>
              <tbody>
                {loading ? (
                  <tr>
                    <td colSpan={6} style={{ textAlign: 'center', padding: '2.5rem' }}>
                      <LoadingState message="Loading destination records from database…" />
                    </td>
                  </tr>
                ) : view.length > 0 ? (
                  view.map((d) => {
                    const isSelected = selectedDest?.id === d.id && drawerMode === 'edit'
                    return (
                      <tr
                        key={d.id}
                        className={isSelected ? 'is-selected' : ''}
                        style={{ cursor: 'pointer' }}
                        onClick={() => selectForEdit(d)}
                      >
                        <td>
                          <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
                            {d.imageUrl ? (
                              <img
                                src={d.imageUrl.startsWith('http') ? d.imageUrl : `${(import.meta.env.VITE_API_BASE_URL ? import.meta.env.VITE_API_BASE_URL.replace(/\/api\/?$/, '') : 'https://ai-travel-planning-booking-management.onrender.com')}${d.imageUrl.startsWith('/') ? '' : '/'}${d.imageUrl}`}
                                alt={d.name}
                                style={{
                                  width: '32px',
                                  height: '32px',
                                  borderRadius: '6px',
                                  objectFit: 'cover'
                                }}
                                onError={(e) => {
                                  e.target.onerror = null
                                  e.target.style.display = 'none'
                                }}
                              />
                            ) : (
                              <div
                                style={{
                                  width: '32px',
                                  height: '32px',
                                  borderRadius: '6px',
                                  backgroundColor: '#e0f2fe',
                                  color: '#0369a1',
                                  display: 'flex',
                                  alignItems: 'center',
                                  justifyContent: 'center'
                                }}
                              >
                                <MapPinIcon size={16} />
                              </div>
                            )}
                            <strong style={{ color: '#182126', fontSize: '0.8125rem' }}>{d.name}</strong>
                          </div>
                        </td>
                        <td style={{ color: '#182126' }}>{d.country}</td>
                        <td style={{ color: '#66747b', fontSize: '0.75rem' }}>{d.region}</td>
                        <td style={{ color: '#475569', fontSize: '0.75rem', fontFamily: 'monospace' }}>
                          {Number(d.latitude).toFixed(4)}, {Number(d.longitude).toFixed(4)}
                        </td>
                        <td>
                          <span className="badge-pill badge-blue">
                            <span className="badge-dot" /> {d.associatedTours} tours
                          </span>
                        </td>
                        <td style={{ textAlign: 'right' }} onClick={(e) => e.stopPropagation()}>
                          <div style={{ display: 'inline-flex', alignItems: 'center', gap: '0.375rem' }}>
                            <button
                              type="button"
                              className="btn-outline"
                              style={{ height: '28px', padding: '0 0.5rem', fontSize: '0.75rem', gap: '0.25rem' }}
                              onClick={() => selectForEdit(d)}
                              title="Edit destination"
                            >
                              <EditIcon size={12} />
                              <span>Edit</span>
                            </button>
                            <button
                              type="button"
                              className="btn-danger-soft"
                              style={{ height: '28px', padding: '0 0.5rem', fontSize: '0.75rem', gap: '0.25rem' }}
                              onClick={() => requestRemove(d)}
                              title="Delete destination"
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
                    <td colSpan={6} style={{ textAlign: 'center', padding: '3rem 2rem', color: '#66747b' }}>
                      <p style={{ margin: '0 0 0.75rem', fontWeight: 600 }}>
                        {query ? `No destinations match “${query}”.` : 'No destinations in catalog yet.'}
                      </p>
                      {!query && (
                        <button
                          type="button"
                          className="btn-gold"
                          style={{ margin: '0 auto', fontSize: '0.8125rem' }}
                          onClick={startCreate}
                        >
                          <PlusIcon size={14} />
                          <span>Create first destination</span>
                        </button>
                      )}
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>

          {/* Pagination */}
          <div className="staff-pagination">
            <span>
              Showing {filtered.length > 0 ? (page - 1) * pageSize + 1 : 0}–{Math.min(page * pageSize, filtered.length)} of {filtered.length} destinations
            </span>
            <div className="staff-pagination__btns">
              <button
                type="button"
                className="staff-page-btn"
                disabled={page <= 1}
                onClick={() => setPage(p => p - 1)}
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
                onClick={() => setPage(p => p + 1)}
              >
                Next
              </button>
            </div>
          </div>
        </div>

        {/* Right Detail / Edit Drawer matching Figma 2:27727 */}
        {drawerMode && (
          <aside className="detail-pane" style={{ position: 'sticky', top: '5.5rem' }}>
            <div className="detail-pane__head">
              <div>
                <h3 style={{ margin: 0, fontSize: '1.0625rem', fontWeight: 700, color: '#182126' }}>
                  {drawerMode === 'create' ? 'Create destination' : 'Edit destination'}
                </h3>
                <span style={{ fontSize: '0.75rem', color: '#66747b' }}>
                  {drawerMode === 'create' ? 'New geographic record' : `Geographic ID · ${selectedDest?.code || 'DEST-001'}`}
                </span>
              </div>
              <button
                type="button"
                className="btn-outline"
                style={{ height: '32px', padding: '0 0.625rem' }}
                onClick={() => setDrawerMode(null)}
              >
                <CloseIcon size={14} />
                <span>Close</span>
              </button>
            </div>

            {drawerNotice && (
              <div
                style={{
                  padding: '0.625rem 0.875rem',
                  borderRadius: '6px',
                  fontSize: '0.8125rem',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  backgroundColor: drawerNotice.type === 'error' ? '#fef2f2' : '#ecfdf5',
                  color: drawerNotice.type === 'error' ? '#b91c1c' : '#047857',
                  border: `1px solid ${drawerNotice.type === 'error' ? '#fecaca' : '#a7f3d0'}`
                }}
              >
                <span>{drawerNotice.message}</span>
                <button
                  type="button"
                  onClick={() => setDrawerNotice(null)}
                  style={{ background: 'none', border: 'none', cursor: 'pointer', color: 'inherit', padding: '0 4px', fontSize: '1rem', lineHeight: 1 }}
                >
                  ×
                </button>
              </div>
            )}

            <form onSubmit={handleSave} style={{ display: 'flex', flexDirection: 'column', gap: '0.875rem' }}>
              <div>
                <label style={{ display: 'block', fontSize: '0.6875rem', fontWeight: 800, color: '#475569', textTransform: 'uppercase', marginBottom: '0.35rem' }}>
                  Destination name *
                </label>
                <input
                  type="text"
                  required
                  placeholder="e.g. Sigiriya"
                  className="staff-search-box"
                  style={{ maxWidth: '100%', width: '100%' }}
                  value={formData.name}
                  onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                />
              </div>

              <div>
                <label style={{ display: 'block', fontSize: '0.6875rem', fontWeight: 800, color: '#475569', textTransform: 'uppercase', marginBottom: '0.35rem' }}>
                  Country *
                </label>
                <input
                  type="text"
                  required
                  className="staff-search-box"
                  style={{ maxWidth: '100%', width: '100%' }}
                  value={formData.country}
                  onChange={(e) => setFormData({ ...formData, country: e.target.value })}
                />
              </div>

              <div>
                <label style={{ display: 'block', fontSize: '0.6875rem', fontWeight: 800, color: '#475569', textTransform: 'uppercase', marginBottom: '0.35rem' }}>
                  Description
                </label>
                <textarea
                  rows={3}
                  style={{
                    width: '100%',
                    padding: '0.5rem 0.75rem',
                    borderRadius: '6px',
                    border: '1px solid #c8d1d4',
                    fontSize: '0.8125rem',
                    boxSizing: 'border-box'
                  }}
                  value={formData.description}
                  onChange={(e) => setFormData({ ...formData, description: e.target.value })}
                />
              </div>

              {/* Cover Image Upload & Media Library Selector */}
              <ImageUploadWidget
                value={formData.imageUrl}
                onChange={(url) => setFormData((prev) => ({ ...prev, imageUrl: url }))}
                category="destinations"
                label="Destination Cover Image"
              />

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '0.75rem' }}>
                <div>
                  <label style={{ display: 'block', fontSize: '0.6875rem', fontWeight: 800, color: '#475569', textTransform: 'uppercase', marginBottom: '0.35rem' }}>
                    Latitude
                  </label>
                  <input
                    type="number"
                    step="0.000001"
                    className="staff-search-box"
                    style={{ maxWidth: '100%', width: '100%' }}
                    value={formData.latitude}
                    onChange={(e) => setFormData({ ...formData, latitude: e.target.value })}
                  />
                </div>

                <div>
                  <label style={{ display: 'block', fontSize: '0.6875rem', fontWeight: 800, color: '#475569', textTransform: 'uppercase', marginBottom: '0.35rem' }}>
                    Longitude
                  </label>
                  <input
                    type="number"
                    step="0.000001"
                    className="staff-search-box"
                    style={{ maxWidth: '100%', width: '100%' }}
                    value={formData.longitude}
                    onChange={(e) => setFormData({ ...formData, longitude: e.target.value })}
                  />
                </div>
              </div>

              {/* Map Preview Block matching Figma */}
              <div
                style={{
                  height: '80px',
                  backgroundColor: '#e0f2fe',
                  borderRadius: '8px',
                  display: 'flex',
                  flexDirection: 'column',
                  alignItems: 'center',
                  justifyContent: 'center',
                  gap: '0.25rem',
                  color: '#0369a1'
                }}
              >
                <MapPinIcon size={24} />
                <span style={{ fontSize: '0.75rem', fontWeight: 700, fontFamily: 'monospace' }}>
                  {formData.latitude || '7.957032'}, {formData.longitude || '80.760261'}
                </span>
              </div>

              {/* Removal guarded warning banner matching Figma */}
              {drawerMode === 'edit' && (
                <div className="banner-warning" style={{ fontSize: '0.75rem' }}>
                  <span>⚠️</span>
                  <span>
                    <strong>Removal guarded</strong> — {formData.name || 'This place'} is referenced by {selectedDest?.associatedTours || 0} active tours, hotels, and future itineraries.
                  </span>
                </div>
              )}

              {/* Actions */}
              <div style={{ display: 'flex', gap: '0.5rem', marginTop: '0.5rem', justifyContent: 'flex-end' }}>
                {drawerMode === 'edit' && selectedDest && (
                  <button
                    type="button"
                    className="btn-danger-soft"
                    onClick={() => requestRemove(selectedDest)}
                  >
                    <TrashIcon size={14} />
                    <span>Remove destination</span>
                  </button>
                )}
                <button
                  type="submit"
                  className="btn-gold"
                  disabled={busy}
                >
                  <CheckIcon size={14} />
                  <span>{busy ? 'Saving…' : (drawerMode === 'create' ? 'Create destination' : 'Save changes')}</span>
                </button>
              </div>
            </form>
          </aside>
        )}
      </div>

      {/* ── Visual Remove Destination Dialog Box ── */}
      {destToDelete && (
        <div
          style={{
            position: 'fixed',
            inset: 0,
            backgroundColor: 'rgba(15, 23, 27, 0.65)',
            backdropFilter: 'blur(4px)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            zIndex: 1000,
            padding: '1rem'
          }}
          onClick={(e) => {
            if (e.target === e.currentTarget && !deleteBusy) setDestToDelete(null)
          }}
        >
          <div
            className="staff-card"
            style={{
              width: '100%',
              maxWidth: '460px',
              padding: '1.75rem',
              borderRadius: '16px',
              boxShadow: '0 20px 40px -15px rgba(0,0,0,0.3)',
              border: '1px solid #e2e8f0',
              backgroundColor: '#ffffff'
            }}
          >
            {/* Dialog Header with Trash Icon Badge */}
            <div style={{ display: 'flex', alignItems: 'flex-start', gap: '1rem', marginBottom: '1.25rem' }}>
              <div
                style={{
                  width: '44px',
                  height: '44px',
                  borderRadius: '12px',
                  backgroundColor: '#fee2e2',
                  color: '#dc2626',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  flexShrink: 0
                }}
              >
                <TrashIcon size={22} />
              </div>
              <div style={{ flex: 1 }}>
                <h3 style={{ margin: '0 0 0.25rem', fontSize: '1.125rem', fontWeight: 700, color: '#182126' }}>
                  Remove destination?
                </h3>
                <p style={{ margin: 0, fontSize: '0.8125rem', color: '#64748b', lineHeight: 1.4 }}>
                  Are you sure you want to permanently delete this location from the catalog database?
                </p>
              </div>
              <button
                type="button"
                className="btn-outline"
                style={{ height: '30px', width: '30px', padding: 0, display: 'flex', alignItems: 'center', justifyContent: 'center' }}
                onClick={() => !deleteBusy && setDestToDelete(null)}
                disabled={deleteBusy}
              >
                <CloseIcon size={14} />
              </button>
            </div>

            {/* Visual Destination Card Preview */}
            <div
              style={{
                backgroundColor: '#f8fafc',
                border: '1px solid #e2e8f0',
                borderRadius: '10px',
                padding: '1rem',
                marginBottom: '1.25rem',
                display: 'flex',
                gap: '0.875rem',
                alignItems: 'center'
              }}
            >
              {destToDelete.imageUrl ? (
                <img
                  src={destToDelete.imageUrl.startsWith('http') ? destToDelete.imageUrl : `${(import.meta.env.VITE_API_BASE_URL ? import.meta.env.VITE_API_BASE_URL.replace(/\/api\/?$/, '') : 'https://ai-travel-planning-booking-management.onrender.com')}${destToDelete.imageUrl.startsWith('/') ? '' : '/'}${destToDelete.imageUrl}`}
                  alt={destToDelete.name}
                  style={{ width: '48px', height: '48px', borderRadius: '8px', objectFit: 'cover' }}
                  onError={(e) => { e.target.style.display = 'none' }}
                />
              ) : (
                <div
                  style={{
                    width: '48px',
                    height: '48px',
                    borderRadius: '8px',
                    backgroundColor: '#e0f2fe',
                    color: '#0369a1',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center'
                  }}
                >
                  <MapPinIcon size={22} />
                </div>
              )}
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', marginBottom: '0.2rem' }}>
                  <h4 style={{ margin: 0, fontSize: '0.9375rem', fontWeight: 700, color: '#0f172a' }}>
                    {destToDelete.name}
                  </h4>
                  <span style={{ fontSize: '0.6875rem', padding: '1px 6px', borderRadius: '4px', backgroundColor: '#e2e8f0', color: '#475569', fontWeight: 600 }}>
                    {destToDelete.code || `DEST-${String(destToDelete.id).padStart(3, '0')}`}
                  </span>
                </div>
                <p style={{ margin: 0, fontSize: '0.75rem', color: '#64748b' }}>
                  {destToDelete.country} · {destToDelete.region}
                </p>
                <p style={{ margin: '0.2rem 0 0', fontSize: '0.6875rem', color: '#94a3b8', fontFamily: 'monospace' }}>
                  GPS: {Number(destToDelete.latitude).toFixed(4)}, {Number(destToDelete.longitude).toFixed(4)}
                </p>
              </div>
            </div>

            {/* Warning about associated records */}
            {destToDelete.associatedTours > 0 ? (
              <div
                style={{
                  backgroundColor: '#fffbeb',
                  border: '1px solid #fef3c7',
                  borderRadius: '8px',
                  padding: '0.75rem 0.875rem',
                  marginBottom: '1.25rem',
                  display: 'flex',
                  gap: '0.625rem',
                  alignItems: 'flex-start',
                  fontSize: '0.8125rem',
                  color: '#92400e'
                }}
              >
                <span style={{ fontSize: '1rem', lineHeight: 1 }}>⚠️</span>
                <div>
                  <strong>Linked records detected:</strong> This destination is referenced by <strong>{destToDelete.associatedTours} active tour(s)</strong>. Deleting it may impact itineraries and booking schedules.
                </div>
              </div>
            ) : (
              <div
                style={{
                  backgroundColor: '#f8fafc',
                  border: '1px solid #e2e8f0',
                  borderRadius: '8px',
                  padding: '0.625rem 0.875rem',
                  marginBottom: '1.25rem',
                  fontSize: '0.75rem',
                  color: '#64748b'
                }}
              >
                ℹ️ This destination currently has <strong>0 associated tours</strong>. It can be safely removed.
              </div>
            )}

            {/* Error Alert inside modal */}
            {deleteError && (
              <div
                style={{
                  backgroundColor: '#fef2f2',
                  border: '1px solid #fecaca',
                  color: '#b91c1c',
                  padding: '0.625rem 0.875rem',
                  borderRadius: '8px',
                  fontSize: '0.8125rem',
                  marginBottom: '1.25rem'
                }}
              >
                {deleteError}
              </div>
            )}

            {/* Modal Footer Actions */}
            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '0.625rem' }}>
              <button
                type="button"
                className="btn-outline"
                onClick={() => setDestToDelete(null)}
                disabled={deleteBusy}
              >
                Cancel
              </button>
              <button
                type="button"
                style={{
                  backgroundColor: '#dc2626',
                  color: '#ffffff',
                  border: 'none',
                  borderRadius: '6px',
                  padding: '0 1rem',
                  height: '38px',
                  fontSize: '0.8125rem',
                  fontWeight: 700,
                  display: 'inline-flex',
                  alignItems: 'center',
                  gap: '0.5rem',
                  cursor: deleteBusy ? 'not-allowed' : 'pointer',
                  opacity: deleteBusy ? 0.7 : 1,
                  transition: 'background-color 0.15s ease'
                }}
                onClick={confirmRemove}
                disabled={deleteBusy}
              >
                <TrashIcon size={15} />
                <span>{deleteBusy ? 'Deleting destination…' : 'Delete destination'}</span>
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

