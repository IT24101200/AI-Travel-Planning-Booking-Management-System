import { useEffect, useMemo, useState } from 'react'
import {
  createTour,
  deleteTour,
  fetchDestinations,
  fetchTours,
  updateTour
} from '../../services/apiClient.js'
import { usePageTitle } from '../../lib/hooks.js'
import { formatPrice } from '../../lib/formatPrice.js'
import { AlertBanner } from '../../components/ui/AlertBanner.jsx'
import { LoadingState } from '../../components/ui/LoadingState.jsx'
import {
  SearchIcon,
  PlusIcon,
  RefreshIcon,
  EditIcon,
  TrashIcon,
  CheckIcon,
  CloseIcon
} from '../../components/ui/Icons.jsx'
import { ImageUploadWidget } from '../../components/common/ImageUploadWidget.jsx'

const CATEGORIES = ['All', 'Heritage', 'Wildlife', 'Cultural', 'Marine', 'Scenic', 'Adventure']

/**
 * Serendib Trails — Tour Catalog Management
 * Designed based on Figma Dev Mode Specifications (node-id: 2:27473)
 */
export default function TourCatalogManagement() {
  const [rows, setRows] = useState([])
  const [destinations, setDestinations] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [notice, setNotice] = useState(null)

  // Filters
  const [query, setQuery] = useState('')
  const [category, setCategory] = useState('All')
  const [statusFilter] = useState('All')
  const [page, setPage] = useState(1)
  const pageSize = 8

  // Selection & Right Drawer / Edit Mode
  const [selectedTour, setSelectedTour] = useState(null)
  const [drawerMode, setDrawerMode] = useState(null) // 'create' | 'edit' | null
  const [formData, setFormData] = useState({
    name: '',
    destinationId: '',
    price: '',
    durationHours: 8,
    category: 'Heritage',
    defaultStartTime: '05:15',
    description: '',
    imageUrl: ''
  })
  const [busy, setBusy] = useState(false)

  usePageTitle('Tour Catalog · Serendib Trails')

  async function loadTours(cancelled = false) {
    setLoading(true)
    setError(null)
    try {
      const [tourRes, destRes] = await Promise.allSettled([
        Promise.all([
          fetchTours({ status: 'Active', pageSize: 1000 }),
          fetchTours({ status: 'Inactive', pageSize: 1000 }),
        ]).then(([activeTours, inactiveTours]) => [...activeTours, ...inactiveTours]),
        fetchDestinations(),
      ])

      if (!cancelled) {
        const loadErrors = []
        let destList = []

        if (destRes.status === 'fulfilled') {
          destList = Array.isArray(destRes.value) ? destRes.value : (destRes.value?.data || [])
          setDestinations(destList)
          if (destList.length > 0 && !formData.destinationId) {
            setFormData((f) => ({ ...f, destinationId: destList[0].id }))
          }
        } else {
          setDestinations([])
          loadErrors.push('Could not load destinations. Check that the backend is running.')
        }

        if (tourRes.status === 'fulfilled') {
          const live = Array.isArray(tourRes.value) ? tourRes.value : (tourRes.value?.data || [])
          const mapped = live.map((t) => {
            const destName = t.destinationName || t.destination?.name || 'Destination not provided'
            return {
              apiTour: t,
              id: t.id,
              name: t.name,
              destination: destName,
              destinationId: t.destinationId || null,
              price: t.price,
              durationHours: t.durationHours || 8,
              category: t.category || 'Heritage',
              defaultStartTime: t.defaultStartTime?.slice(0, 5) || '05:15',
              status: t.status || 'Active',
              description: t.description || `Guided excursion in scenic ${destName}.`,
              imageUrl: t.imageUrl || ''
            }
          })
          setRows(mapped)
        } else {
          setRows([])
          loadErrors.push('Could not load tours. Check that the backend is running.')
        }

        setError(loadErrors.length > 0 ? loadErrors.join(' ') : null)
      }
    } catch (err) {
      if (!cancelled) {
        setError(err.response?.data?.message || err.message || 'Failed to load tour catalog.')
      }
    } finally {
      if (!cancelled) setLoading(false)
    }
  }

  useEffect(() => {
    let cancelled = false
    // This starts an async API load; its state updates occur after the request.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    loadTours(cancelled)
    return () => { cancelled = true }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  function selectForEdit(tour) {
    setSelectedTour(tour)
    setDrawerMode('edit')
    setFormData({
      name: tour.name,
      destinationId: tour.destinationId,
      price: tour.price,
      durationHours: tour.durationHours,
      category: tour.category,
      defaultStartTime: tour.defaultStartTime,
      description: tour.description,
      imageUrl: tour.imageUrl || ''
    })
  }

  function startCreateTour() {
    setSelectedTour(null)
    setDrawerMode('create')
    setFormData({
      name: '',
      destinationId: destinations[0]?.id || '',
      price: '85.00',
      durationHours: 4,
      category: 'Heritage',
      defaultStartTime: '08:00',
      description: 'Exclusive guided experience operated by certified naturalists and historians.',
      imageUrl: ''
    })
  }

  async function handleSaveTour(e) {
    e.preventDefault()
    if (!formData.name?.trim()) {
      setNotice({ type: 'error', message: 'Please enter a tour name.' })
      return
    }
    if (!formData.destinationId) {
      setNotice({ type: 'error', message: 'Please select a destination.' })
      return
    }
    if (!formData.imageUrl?.trim()) {
      setNotice({ type: 'error', message: 'Please select or upload a cover image for the tour.' })
      return
    }
    setBusy(true)
    setNotice(null)
    try {
      if (drawerMode === 'create') {
        const res = await createTour({
          destinationId: Number(formData.destinationId),
          name: formData.name.trim(),
          category: formData.category,
          price: Number(formData.price),
          currency: 'LKR',
          durationHours: Number(formData.durationHours),
          defaultStartTime: `${formData.defaultStartTime}:00`,
          description: formData.description,
          imageUrl: formData.imageUrl.trim(),
          status: 'Active'
        })
        setNotice({ type: 'success', message: `Tour "${res.name || formData.name}" created successfully.` })
        setDrawerMode(null)
      } else if (drawerMode === 'edit' && selectedTour) {
        await updateTour(selectedTour.id, {
          destinationId: Number(formData.destinationId),
          name: formData.name,
          category: formData.category,
          price: Number(formData.price),
          currency: 'LKR',
          durationHours: Number(formData.durationHours),
          defaultStartTime: `${formData.defaultStartTime}:00`,
          description: formData.description,
          imageUrl: formData.imageUrl || selectedTour.imageUrl || '',
          status: selectedTour.status
        })
        setNotice({ type: 'success', message: `Tour "${formData.name}" updated successfully.` })
      }
      await loadTours()
    } catch (err) {
      setNotice({ type: 'error', message: err.response?.data?.message || err.message || 'Operation failed.' })
    } finally {
      setBusy(false)
    }
  }

  async function handleRestoreTour(tour) {
    try {
      await updateTour(tour.id, { ...tour.apiTour, status: 'Active' })
      setSelectedTour((current) => current?.id === tour.id ? { ...current, status: 'Active' } : current)
      setNotice({ type: 'success', message: `Tour "${tour.name}" restored.` })
      await loadTours()
    } catch (err) {
      setNotice({ type: 'error', message: err.response?.data?.message || err.message || 'Failed to restore tour.' })
    }
  }

  async function handleDeleteTour(id, name) {
    if (!window.confirm(`Are you sure you want to deactivate "${name}"?`)) return
    try {
      await deleteTour(id)
      setNotice({ type: 'success', message: `Tour "${name}" deactivated.` })
      loadTours()
    } catch (err) {
      setNotice({ type: 'error', message: err.message || 'Failed to deactivate tour.' })
    }
  }

  // Filtered & Paginated records
  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase()
    return rows.filter((r) => {
      if (category !== 'All' && r.category.toLowerCase() !== category.toLowerCase()) return false
      if (statusFilter !== 'All' && r.status.toLowerCase() !== statusFilter.toLowerCase()) return false
      return !q || r.name.toLowerCase().includes(q) || r.destination.toLowerCase().includes(q)
    })
  }, [rows, query, category, statusFilter])

  const totalPages = Math.max(1, Math.ceil(filtered.length / pageSize))
  const pagedRows = filtered.slice((page - 1) * pageSize, page * pageSize)

  return (
    <div className="staff-page">
      {/* ── Page Header matching Figma 2:27473 ── */}
      <header className="staff-page__head">
        <div className="staff-page__title-block">
          <p className="staff-page__eyebrow">CATALOG / EXPERIENCES</p>
          <h1 className="staff-page__title">Tour catalog</h1>
          <p className="staff-page__subtitle">
            Maintain sellable experiences, pricing, schedules, and publishing status.
          </p>
        </div>
        <div className="staff-page__actions">
          <button
            type="button"
            className="btn-outline"
            onClick={() => loadTours(false)}
            disabled={loading}
          >
            <RefreshIcon size={15} />
            <span>{loading ? 'Refreshing…' : 'Refresh'}</span>
          </button>
          <button
            type="button"
            className="btn-gold"
            onClick={startCreateTour}
          >
            <PlusIcon size={15} />
            <span>Create tour</span>
          </button>
        </div>
      </header>

      {/* ── Toolbar: Search Box on Left, Category Tabs on Right ── */}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: '1rem', flexWrap: 'wrap' }}>
        <div className="staff-search-box" style={{ maxWidth: '320px' }}>
          <SearchIcon size={16} />
          <input
            type="text"
            placeholder="Search tours or destinations"
            value={query}
            onChange={(e) => {
              setQuery(e.target.value)
              setPage(1)
            }}
          />
        </div>

        <div className="staff-tabs" style={{ width: 'auto', flex: 1, justifyContent: 'flex-end' }}>
          {CATEGORIES.map((cat) => (
            <button
              key={cat}
              type="button"
              className={`staff-tab ${category === cat ? 'is-active' : ''}`}
              onClick={() => {
                setCategory(cat)
                setPage(1)
              }}
            >
              <span>{cat}</span>
            </button>
          ))}
        </div>
      </div>

      {error && (
        <AlertBanner
          type="error"
          message={error}
          onRetry={() => loadTours(false)}
          onDismiss={() => setError(null)}
        />
      )}

      {notice && (
        <AlertBanner
          type={notice.type}
          message={notice.message}
          onDismiss={() => setNotice(null)}
        />
      )}

      {/* ── Split Layout: Table on Left (65%), Edit Drawer on Right (35%) matching Figma ── */}
      <div className="split-workspace" style={{ gridTemplateColumns: drawerMode ? 'minmax(0, 1fr) 380px' : '1fr' }}>
        <div className="staff-table-wrap">
          {loading ? (
            <LoadingState label="Loading tour catalog from database…" />
          ) : (
            <table className="staff-table">
              <thead>
                <tr>
                  <th style={{ width: '56px' }}>Photo</th>
                  <th>Tour Name & Region</th>
                  <th>Category</th>
                  <th>Duration</th>
                  <th>Departure</th>
                  <th>Price</th>
                  <th>Status</th>
                  <th style={{ width: '80px', textAlign: 'right' }}>Actions</th>
                </tr>
              </thead>
              <tbody>
                {pagedRows.map((tour) => {
                  const isSelected = selectedTour?.id === tour.id
                  return (
                    <tr
                      key={tour.id}
                      style={{ cursor: 'pointer', backgroundColor: isSelected ? '#f5fbf7' : undefined }}
                      onClick={() => selectForEdit(tour)}
                    >
                      <td>
                        <img
                          src={tour.imageUrl}
                          alt={tour.name}
                          style={{ width: '40px', height: '40px', borderRadius: '6px', objectFit: 'cover' }}
                        />
                      </td>
                      <td>
                        <strong style={{ display: 'block', color: '#182126', fontSize: '0.875rem' }}>
                          {tour.name}
                        </strong>
                        <span style={{ fontSize: '0.75rem', color: '#66747b' }}>
                          📍 {tour.destination}
                        </span>
                      </td>
                      <td>
                        <span className="badge-pill badge-gold">
                          <span className="badge-dot" />
                          {tour.category}
                        </span>
                      </td>
                      <td style={{ fontSize: '0.8125rem', color: '#334155' }}>
                        {tour.durationHours} hrs
                      </td>
                      <td style={{ fontSize: '0.8125rem', color: '#334155' }}>
                        {tour.defaultStartTime}
                      </td>
                      <td>
                        <strong style={{ color: '#182126', fontSize: '0.875rem' }}>
                          {formatPrice(tour.price)}
                        </strong>
                        <span style={{ fontSize: '0.6875rem', color: '#64748b' }}> / person</span>
                      </td>
                      <td>
                        <span className={`badge-pill ${tour.status === 'Active' ? 'badge-green' : 'badge-gray'}`}>
                          <span className="badge-dot" />
                          {tour.status}
                        </span>
                      </td>
                      <td style={{ textAlign: 'right' }}>
                        <div style={{ display: 'inline-flex', gap: '0.375rem' }} onClick={(e) => e.stopPropagation()}>
                          <button
                            type="button"
                            className="btn-action-edit"
                            title="Edit Tour"
                            onClick={() => selectForEdit(tour)}
                          >
                            <EditIcon size={12} />
                            <span>Edit</span>
                          </button>
                          <button
                            type="button"
                            className="btn-action-delete"
                            title={tour.status === 'Inactive' ? 'Restore' : 'Deactivate'}
                            onClick={() => tour.status === 'Inactive' ? handleRestoreTour(tour) : handleDeleteTour(tour.id, tour.name)}
                          >
                            {tour.status === 'Inactive' ? <CheckIcon size={12} /> : <TrashIcon size={12} />}
                            <span>{tour.status === 'Inactive' ? 'Restore' : 'Delete'}</span>
                          </button>
                        </div>
                      </td>
                    </tr>
                  )
                })}
                {pagedRows.length === 0 && (
                  <tr>
                    <td colSpan={8} style={{ textAlign: 'center', padding: '3rem', color: '#66747b' }}>
                      No tours match your current filters.
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          )}

          {/* Pagination Footer */}
          <div className="table-footer">
            <span style={{ fontSize: '0.8125rem', color: '#66747b' }}>
              Showing {filtered.length === 0 ? 0 : (page - 1) * pageSize + 1}–{Math.min(page * pageSize, filtered.length)} of {filtered.length} tours
            </span>
            <div className="table-pagination">
              <button
                type="button"
                className="table-page-btn"
                disabled={page <= 1}
                onClick={() => setPage(p => p - 1)}
              >
                ‹ Prev
              </button>
              <button
                type="button"
                className="table-page-btn"
                disabled={page >= totalPages}
                onClick={() => setPage(p => p + 1)}
              >
                Next ›
              </button>
            </div>
          </div>
        </div>

        {/* ── Edit / Create Drawer matching Figma Spec ── */}
        {drawerMode && (
          <aside className="staff-card" style={{ padding: '1.25rem' }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '1rem', paddingBottom: '0.75rem', borderBottom: '1px solid #eef2f3' }}>
              <div>
                <span className={`badge-pill ${selectedTour?.status === 'Inactive' ? 'badge-gray' : 'badge-green'}`} style={{ fontSize: '0.625rem', padding: '1px 6px', marginBottom: '4px' }}>
                  <span className="badge-dot" /> {selectedTour?.status === 'Inactive' ? 'INACTIVE' : 'LIVE IN CATALOG'}
                </span>
                <h3 style={{ margin: 0, fontSize: '1rem', fontWeight: 700, color: '#182126' }}>
                  {drawerMode === 'create' ? 'Create new tour' : (selectedTour?.name || 'Edit tour')}
                </h3>
              </div>
              <button
                type="button"
                className="btn-outline"
                style={{ height: '28px', padding: '0 8px' }}
                onClick={() => setDrawerMode(null)}
              >
                ✕
              </button>
            </div>

            <form onSubmit={handleSaveTour} style={{ display: 'flex', flexDirection: 'column', gap: '0.875rem' }}>
              {/* Tour Name */}
              <div>
                <label style={{ display: 'block', fontSize: '0.6875rem', fontWeight: 800, color: '#475569', textTransform: 'uppercase', marginBottom: '0.35rem' }}>
                  Tour name *
                </label>
                <input
                  type="text"
                  required
                  placeholder="e.g. Sigiriya Sunrise & Village Trail"
                  className="staff-search-box"
                  style={{ maxWidth: '100%', width: '100%' }}
                  value={formData.name}
                  onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                />
              </div>

              {/* 2-Column: Destination & Category */}
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '0.75rem' }}>
                <div>
                  <label style={{ display: 'block', fontSize: '0.6875rem', fontWeight: 800, color: '#475569', textTransform: 'uppercase', marginBottom: '0.35rem' }}>
                    Destination *
                  </label>
                  <select
                    className="btn-outline"
                    style={{
                      width: '100%',
                      height: '38px',
                      padding: '0 0.5rem',
                      fontSize: '0.8125rem',
                      color: '#182126',
                      backgroundColor: '#ffffff',
                      opacity: 1,
                      colorScheme: 'light'
                    }}
                    value={formData.destinationId}
                    onChange={(e) => setFormData({ ...formData, destinationId: e.target.value })}
                  >
                    {destinations.length === 0 ? (
                      <option value="">No destinations available</option>
                    ) : destinations.map((d) => (
                      <option key={d.id} value={d.id} style={{ color: '#182126', backgroundColor: '#ffffff' }}>{d.name}</option>
                    ))}
                  </select>
                </div>

                <div>
                  <label style={{ display: 'block', fontSize: '0.6875rem', fontWeight: 800, color: '#475569', textTransform: 'uppercase', marginBottom: '0.35rem' }}>
                    Category *
                  </label>
                  <select
                    className="btn-outline"
                    style={{
                      width: '100%',
                      height: '38px',
                      padding: '0 0.5rem',
                      fontSize: '0.8125rem',
                      color: '#182126',
                      backgroundColor: '#ffffff',
                      opacity: 1,
                      colorScheme: 'light'
                    }}
                    value={formData.category}
                    onChange={(e) => setFormData({ ...formData, category: e.target.value })}
                  >
                    {CATEGORIES.filter(c => c !== 'All').map((c) => (
                      <option key={c} value={c} style={{ color: '#182126', backgroundColor: '#ffffff' }}>{c}</option>
                    ))}
                  </select>
                </div>
              </div>

              {/* 3-Column: Price, Duration, Start Time */}
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: '0.5rem' }}>
                <div>
                  <label style={{ display: 'flex', alignItems: 'flex-start', minHeight: '2.4rem', fontSize: '0.6875rem', fontWeight: 800, color: '#475569', textTransform: 'uppercase', marginBottom: '0.35rem' }}>
                    PRICE (LKR)
                  </label>
                  <input
                    type="number"
                    step="0.01"
                    required
                    className="staff-search-box"
                    style={{ maxWidth: '100%', width: '100%' }}
                    value={formData.price}
                    onChange={(e) => setFormData({ ...formData, price: e.target.value })}
                  />
                </div>

                <div>
                  <label style={{ display: 'flex', alignItems: 'flex-start', minHeight: '2.4rem', fontSize: '0.6875rem', fontWeight: 800, color: '#475569', textTransform: 'uppercase', marginBottom: '0.35rem' }}>
                    Duration (hrs)
                  </label>
                  <input
                    type="number"
                    step="0.5"
                    min="0.5"
                    max="72"
                    required
                    className="staff-search-box"
                    style={{ maxWidth: '100%', width: '100%' }}
                    value={formData.durationHours}
                    onChange={(e) => setFormData({ ...formData, durationHours: e.target.value })}
                  />
                </div>

                <div>
                  <label style={{ display: 'flex', alignItems: 'flex-start', minHeight: '2.4rem', fontSize: '0.6875rem', fontWeight: 800, color: '#475569', textTransform: 'uppercase', marginBottom: '0.35rem' }}>
                    Start Time
                  </label>
                  <input
                    type="time"
                    required
                    className="staff-search-box"
                    style={{ maxWidth: '100%', width: '100%' }}
                    value={formData.defaultStartTime}
                    onChange={(e) => setFormData({ ...formData, defaultStartTime: e.target.value })}
                  />
                </div>
              </div>

              {/* Cover Image Upload & Media Library Selector */}
              <ImageUploadWidget
                value={formData.imageUrl}
                onChange={(url) => setFormData((prev) => ({ ...prev, imageUrl: url }))}
                category="tours"
                label="Cover Image"
              />


              {/* Description Textarea */}
              <div>
                <label style={{ display: 'block', fontSize: '0.6875rem', fontWeight: 800, color: '#475569', textTransform: 'uppercase', marginBottom: '0.35rem' }}>
                  Description
                </label>
                <textarea
                  rows={3}
                  required
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

              {/* Action Buttons */}
              <div style={{ display: 'flex', gap: '0.5rem', marginTop: '0.5rem', justifyContent: 'flex-end' }}>
                <button
                  type="button"
                  className="btn-outline"
                  onClick={() => setDrawerMode(null)}
                  style={{ opacity: 1, color: '#182126', backgroundColor: '#ffffff' }}
                >
                  <CloseIcon size={14} />
                  <span>Cancel</span>
                </button>
                <button
                  type="submit"
                  className="btn-gold"
                  disabled={busy}
                >
                  <CheckIcon size={14} />
                  <span>{busy ? 'Saving…' : (drawerMode === 'create' ? 'Create tour' : 'Save changes')}</span>
                </button>
              </div>
            </form>
          </aside>
        )}
      </div>
    </div>
  )
}
