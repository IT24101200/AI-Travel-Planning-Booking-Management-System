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
  CheckIcon
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
  const [drawerMode, setDrawerMode] = useState('edit') // 'edit' | 'create' | null
  const [selectedDest, setSelectedDest] = useState(null)
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

  async function loadData(cancelled = false) {
    setLoading(true)
    setError(null)
    try {
      const [destRes, tourRes] = await Promise.allSettled([
        fetchDestinations(),
        fetchTours({ pageSize: 1000 })
      ])

      if (!cancelled) {
        const loadErrors = []
        const counts = {}
        if (tourRes.status === 'fulfilled') {
          const tList = Array.isArray(tourRes.value) ? tourRes.value : (tourRes.value?.data || [])
          tList.forEach(t => {
            const dId = t.destinationId
            counts[dId] = (counts[dId] || 0) + 1
          })
        } else {
          loadErrors.push('Tour associations are unavailable.')
        }
        if (destRes.status === 'fulfilled') {
          const live = Array.isArray(destRes.value) ? destRes.value : (destRes.value?.data || [])
          const mapped = live.map((d, idx) => {
            const nameLower = (d.name || '').toLowerCase()
            let region = 'Not provided'
            for (const [key, val] of Object.entries(REGIONS)) {
              if (nameLower.includes(key)) {
                region = val
                break
              }
            }

            return {
              id: d.id,
              code: `DEST-${String(idx + 1).padStart(3, '0')}`,
              name: d.name,
              country: d.country || 'Country not provided',
              region,
              imageUrl: d.imageUrl || '',
              description: d.description || '',
              latitude: d.latitude,
              longitude: d.longitude,
              associatedTours: Number.isFinite(Number(d.tourCount))
                ? Number(d.tourCount)
                : (tourRes.status === 'fulfilled' ? (counts[d.id] || 0) : null),
              associatedHotels: Number.isFinite(Number(d.hotelCount)) ? Number(d.hotelCount) : null
            }
          })
          setRows(mapped)

          if (selectId) {
            const target = mapped.find(d => d.id === selectId)
            if (target) {
              selectForEdit(target)
            }
          } else if (mapped.length === 0) {
            setSelectedDest(null)
            setDrawerMode(null)
          }
          }
        } else {
          setRows([])
          setSelectedDest(null)
          setDrawerMode(null)
          loadErrors.unshift('Unable to load destinations from the database.')
        }
        setError(loadErrors.length > 0 ? loadErrors.join(' ') : null)
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
    setSelectedDest({
      ...dest,
      associatedTours: dest.associatedTours == null ? 'Unavailable' : String(dest.associatedTours),
      associatedHotels: dest.associatedHotels == null ? 'Unavailable' : String(dest.associatedHotels)
    })
    setDrawerMode('edit')
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
    setFormData({
      name: '',
      country: 'Sri Lanka',
      description: '',
      latitude: '',
      longitude: '',
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
      setNotice('Please provide a destination name and country.')
      return
    }
    setBusy(true)
    setNotice('')
    try {
      if (drawerMode === 'create') {
        await createDestination({
          name: formData.name.trim(),
          country: formData.country.trim(),
          description: formData.description.trim() || null,
          imageUrl: formData.imageUrl?.trim() || null,
          latitude: formData.latitude === '' ? null : Number(formData.latitude),
          longitude: formData.longitude === '' ? null : Number(formData.longitude),
        })
        setNotice(`Destination "${formData.name.trim()}" created successfully.`)
      } else if (drawerMode === 'edit' && selectedDest) {
        await updateDestination(selectedDest.id, {
          name: formData.name.trim(),
          country: formData.country.trim(),
          description: formData.description.trim() || null,
          imageUrl: formData.imageUrl?.trim() || null,
          latitude: formData.latitude === '' ? null : Number(formData.latitude),
          longitude: formData.longitude === '' ? null : Number(formData.longitude),
        })
        setNotice(`Destination #${selectedDest.id} updated successfully.`)
      }
      await loadData()
    } catch (err) {
      setNotice(`Failed to save destination: ${err.response?.data?.message || err.message}`)
    } finally {
      setBusy(false)
    }
  }

  async function handleRemove(id) {
    if (!window.confirm(`Delete destination #${id}? Warning: this record may be referenced by existing tours.`)) return
    try {
      await deleteDestination(id)
      setNotice(`Destination #${id} deleted from database.`)
      setDrawerMode(null)
      await loadData()
    } catch (err) {
      setNotice(`Delete failed: ${err.response?.data?.message || err.message}`)
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
      <div className="split-workspace" style={{ gridTemplateColumns: drawerMode ? 'minmax(0, 1fr) 420px' : '1fr' }}>
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
                                src={d.imageUrl}
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
                          {Number.isFinite(Number(d.latitude)) && Number.isFinite(Number(d.longitude))
                            ? `${Number(d.latitude).toFixed(4)}, ${Number(d.longitude).toFixed(4)}`
                            : 'Coordinates not provided'}
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
                              className="btn-action-edit"
                              onClick={() => selectForEdit(d)}
                              title="Edit destination"
                            >
                              <EditIcon size={12} />
                              <span>Edit</span>
                            </button>
                            <button
                              type="button"
                              className="btn-action-delete"
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
                    <td colSpan={6} style={{ textAlign: 'center', padding: '2rem', color: '#66747b' }}>
                      {query ? `No destinations match “${query}”.` : 'No destinations in catalog.'}
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
                  {formData.latitude || 'Latitude not provided'}, {formData.longitude || 'Longitude not provided'}
                </span>
              </div>

              {/* Removal guarded warning banner matching Figma */}
              {drawerMode === 'edit' && (
                <div className="banner-warning" style={{ fontSize: '0.75rem' }}>
                  <span>⚠️</span>
                  <span>
                    <strong>Removal guarded</strong> — {formData.name || 'This place'} has {selectedDest?.associatedTours ?? 'unavailable'} tour references and {selectedDest?.associatedHotels ?? 'unavailable'} hotel references.
                  </span>
                </div>
              )}

              {/* Actions */}
              <div style={{ display: 'flex', gap: '0.5rem', marginTop: '0.5rem', justifyContent: 'flex-end', flexWrap: 'wrap' }}>
                <button
                  type="button"
                  className="btn-outline"
                  onClick={() => setDrawerMode(null)}
                >
                  <CloseIcon size={14} />
                  <span>Cancel</span>
                </button>
                {drawerMode === 'edit' && selectedDest && (
                  <button
                    type="button"
                    className="btn-danger-soft"
                    onClick={() => handleRemove(selectedDest.id)}
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
    </div>
  )
}
