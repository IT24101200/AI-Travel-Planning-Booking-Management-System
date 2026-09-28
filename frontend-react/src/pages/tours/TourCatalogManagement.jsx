import { useEffect, useMemo, useState } from 'react'
import { createTour, deleteTour, fetchDestinations, fetchTours, updateTour } from '../../services/apiClient.js'
import { usePageTitle } from '../../lib/hooks.js'
import { AlertBanner } from '../../components/ui/AlertBanner.jsx'
import { LoadingState } from '../../components/ui/LoadingState.jsx'
import {
  PlusIcon,
  SearchIcon,
  EditIcon,
  RefreshIcon,
  CloseIcon,
  CheckIcon
} from '../../components/ui/Icons.jsx'

const MAX_IMAGE_BYTES = 5 * 1024 * 1024
const ALLOWED_IMAGE_TYPES = ['image/jpeg', 'image/png', 'image/webp']
const CATEGORIES = ['All', 'Heritage', 'Adventure', 'Wildlife', 'Culinary', 'Scenic']

// High-quality imagery for tours
const FALLBACK_TOUR_IMAGES = {
  sigiriya: '/images/destinations/sigiriya.jpg',
  yala: '/images/destinations/yala.jpg',
  kandy: '/images/destinations/kandy.jpg',
  galle: '/images/destinations/galle.jpg',
  ella: '/images/destinations/ella.jpg',
  nuwara: '/images/destinations/nuwara-eliya.jpg',
  default: '/images/destinations/sigiriya.jpg'
}

/**
 * Serendib Trails — Tour Catalog Management
 * Designed based on Figma Dev Mode Specifications (node-id: 2:27473)
 */
export default function TourCatalogManagement() {
  const [rows, setRows] = useState([])
  const [destinations, setDestinations] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [notice, setNotice] = useState('')
  const [query, setQuery] = useState('')
  const [category, setCategory] = useState('All')
  const [page, setPage] = useState(1)

  // Drawer state: 'edit' | 'create' | null
  const [drawerMode, setDrawerMode] = useState('edit')
  const [selectedTour, setSelectedTour] = useState(null)

  // Active form data
  const [formData, setFormData] = useState({
    name: '',
    destinationId: '',
    price: '',
    durationHours: 8,
    category: 'Heritage',
    defaultStartTime: '05:15',
    description: ''
  })
  const [imageFile, setImageFile] = useState(null)
  const [imagePreview, setImagePreview] = useState('')
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
        let destList = []
        if (destRes.status === 'fulfilled') {
          destList = Array.isArray(destRes.value) ? destRes.value : (destRes.value?.data || [])
          setDestinations(destList)
        }

        if (tourRes.status === 'fulfilled') {
          const live = Array.isArray(tourRes.value) ? tourRes.value : (tourRes.value?.data || [])
          const mapped = live.map((t) => {
            const destName = t.destinationName || t.destination?.name || 'Sigiriya'
            const destKey = destName.toLowerCase()
            let thumb = t.imageUrl
            if (!thumb) {
              if (destKey.includes('sigiriya')) thumb = FALLBACK_TOUR_IMAGES.sigiriya
              else if (destKey.includes('yala')) thumb = FALLBACK_TOUR_IMAGES.yala
              else if (destKey.includes('kandy')) thumb = FALLBACK_TOUR_IMAGES.kandy
              else if (destKey.includes('galle')) thumb = FALLBACK_TOUR_IMAGES.galle
              else if (destKey.includes('ella')) thumb = FALLBACK_TOUR_IMAGES.ella
              else thumb = FALLBACK_TOUR_IMAGES.default
            }

            return {
              id: t.id,
              name: t.name,
              destination: destName,
              destinationId: t.destinationId || (destList.length > 0 ? destList[0].id : 1),
              price: t.price,
              durationHours: t.durationHours || 8,
              category: t.category || 'Heritage',
              defaultStartTime: t.defaultStartTime?.slice(0, 5) || '05:15',
              status: t.status || 'Active',
              description: t.description || `Guided excursion in scenic ${destName}.`,
              imageUrl: thumb
            }
          })
          setRows(mapped)

          if (mapped.length > 0 && !selectedTour) {
            selectForEdit(mapped[0])
          }
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
      description: tour.description
    })
    setImagePreview(tour.imageUrl || '')
    setImageFile(null)
  }

  function startCreateTour() {
    setDrawerMode('create')
    setSelectedTour(null)
    setFormData({
      name: '',
      destinationId: destinations[0]?.id || 1,
      price: '120.00',
      durationHours: 6,
      category: 'Heritage',
      defaultStartTime: '08:30',
      description: 'Comprehensive guided experience with private transport and certified guide.'
    })
    setImagePreview('')
    setImageFile(null)
  }

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase()
    return rows.filter((r) => {
      const matchCat = category === 'All' || r.category.toLowerCase() === category.toLowerCase()
      const matchQ = !q || r.name.toLowerCase().includes(q) || r.destination.toLowerCase().includes(q)
      return matchCat && matchQ
    })
  }, [rows, query, category])

  const pageSize = 5
  const pages = Math.max(1, Math.ceil(filtered.length / pageSize))
  const view = filtered.slice((page - 1) * pageSize, page * pageSize)

  function onImageChange(e) {
    const file = e.target.files?.[0]
    if (!file) return
    if (!ALLOWED_IMAGE_TYPES.includes(file.type)) {
      setNotice('Only JPEG, PNG, and WebP images are allowed.')
      return
    }
    if (file.size > MAX_IMAGE_BYTES) {
      setNotice('The image must be 5 MB or smaller.')
      return
    }
    setImageFile(file)
    setImagePreview(URL.createObjectURL(file))
    setNotice('')
  }

  async function handleSaveTour(e) {
    e.preventDefault()
    if (!formData.name.trim() || Number(formData.price) <= 0) {
      setNotice('Please provide a valid tour name and price.')
      return
    }
    setBusy(true)
    setNotice('')
    try {
      const destId = Number(formData.destinationId) || destinations[0]?.id || 1
      if (drawerMode === 'create') {
        await createTour({
          name: formData.name.trim(),
          description: formData.description,
          price: Number(formData.price),
          durationHours: Number(formData.durationHours) || 8,
          category: formData.category,
          defaultStartTime: formData.defaultStartTime,
          destinationId: destId,
          currency: 'USD',
        }, imageFile)
        setNotice(`Tour "${formData.name.trim()}" created successfully.`)
      } else if (drawerMode === 'edit' && selectedTour) {
        await updateTour(selectedTour.id, {
          name: formData.name.trim(),
          description: formData.description,
          price: Number(formData.price),
          durationHours: Number(formData.durationHours) || 8,
          category: formData.category,
          defaultStartTime: formData.defaultStartTime,
          destinationId: destId,
          currency: 'USD',
          status: selectedTour.status
        }, imageFile)
        setNotice(`Tour "${formData.name.trim()}" updated successfully.`)
      }
      await loadTours()
    } catch (err) {
      setNotice(`Failed to save tour: ${err.response?.data?.message || err.message}`)
    } finally {
      setBusy(false)
    }
  }

  async function toggleTourStatus(tour, e) {
    e.stopPropagation()
    const nextStatus = tour.status === 'Active' ? 'Inactive' : 'Active'
    try {
      await updateTour(tour.id, {
        name: tour.name,
        description: tour.description,
        price: tour.price,
        durationHours: tour.durationHours,
        category: tour.category,
        defaultStartTime: tour.defaultStartTime,
        destinationId: tour.destinationId,
        currency: 'USD',
        status: nextStatus
      })
      setRows(prev => prev.map(t => t.id === tour.id ? { ...t, status: nextStatus } : t))
      if (selectedTour?.id === tour.id) {
        setSelectedTour(prev => ({ ...prev, status: nextStatus }))
      }
      setNotice(`Tour status changed to ${nextStatus}.`)
    } catch (err) {
      setNotice(`Failed to update status: ${err.response?.data?.message || err.message}`)
    }
  }

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
          {CATEGORIES.map((c) => (
            <button
              key={c}
              type="button"
              className={`staff-tab ${category === c ? 'is-active' : ''}`}
              onClick={() => {
                setCategory(c)
                setPage(1)
              }}
            >
              {c}
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
          type={notice.startsWith('Failed') ? 'error' : 'success'}
          message={notice}
          onDismiss={() => setNotice('')}
        />
      )}

      {/* ── Split Workspace matching Figma 2:27473 ── */}
      <div className="split-workspace">
        {/* Left Column: Tour Card List */}
        <div className="tour-card-list">
          {loading ? (
            <div className="staff-card" style={{ padding: '3rem', textAlign: 'center' }}>
              <LoadingState message="Loading experiences from catalog database…" />
            </div>
          ) : view.length > 0 ? (
            view.map((t) => {
              const isSelected = selectedTour?.id === t.id && drawerMode === 'edit'
              return (
                <div
                  key={t.id}
                  className={`tour-item-card ${isSelected ? 'is-selected' : ''}`}
                  onClick={() => selectForEdit(t)}
                >
                  <img
                    src={t.imageUrl}
                    alt={t.name}
                    className="tour-item-thumb"
                    onError={(e) => {
                      e.target.onerror = null
                      e.target.src = FALLBACK_TOUR_IMAGES.default
                    }}
                  />
                  <div className="tour-item-body">
                    <div className="tour-item-header">
                      <h3 className="tour-item-title">{t.name}</h3>
                      <span className={`badge-pill ${t.status === 'Active' ? 'badge-green' : 'badge-gray'}`}>
                        <span className="badge-dot" /> {t.status}
                      </span>
                    </div>

                    <div style={{ display: 'flex', gap: '0.4rem', margin: '2px 0' }}>
                      <span className="badge-pill badge-blue">
                        <span className="badge-dot" /> {t.destination}
                      </span>
                      <span className="badge-pill badge-purple">
                        <span className="badge-dot" /> {t.category}
                      </span>
                    </div>

                    <div className="tour-item-meta">
                      <span>🏷️ <strong>${t.price}</strong></span>
                      <span>⏱️ {t.durationHours} hours</span>
                      <span>⚓ {t.defaultStartTime}</span>
                    </div>
                  </div>

                  <div className="tour-item-actions">
                    <button
                      type="button"
                      className="btn-outline"
                      style={{ height: '32px', padding: '0 0.625rem', fontSize: '0.75rem' }}
                      onClick={(e) => {
                        e.stopPropagation()
                        selectForEdit(t)
                      }}
                    >
                      <EditIcon size={14} />
                      <span>Edit</span>
                    </button>
                    <button
                      type="button"
                      style={{
                        background: 'none',
                        border: 'none',
                        color: t.status === 'Active' ? '#66747b' : '#15803d',
                        fontSize: '0.75rem',
                        fontWeight: 600,
                        cursor: 'pointer',
                        padding: '0.25rem 0.5rem'
                      }}
                      onClick={(e) => toggleTourStatus(t, e)}
                    >
                      {t.status === 'Active' ? 'Inactivate' : 'Activate'}
                    </button>
                  </div>
                </div>
              )
            })
          ) : (
            <div className="staff-card" style={{ padding: '2.5rem', textAlign: 'center', color: '#66747b' }}>
              {query ? `No tours match “${query}”.` : 'No experiences found in catalog.'}
            </div>
          )}

          {/* Pagination */}
          {pages > 1 && (
            <div className="staff-pagination" style={{ background: '#ffffff', borderRadius: '10px' }}>
              <span>Page {page} of {pages} ({filtered.length} tours)</span>
              <div className="staff-pagination__btns">
                <button
                  type="button"
                  className="staff-page-btn"
                  disabled={page <= 1}
                  onClick={() => setPage(p => p - 1)}
                >
                  Previous
                </button>
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
          )}
        </div>

        {/* Right Column: Edit/Create Tour Drawer matching Figma 2:27473 */}
        {drawerMode && (
          <aside className="detail-pane" style={{ position: 'sticky', top: '5.5rem' }}>
            <div className="detail-pane__head">
              <div>
                <h3 style={{ margin: 0, fontSize: '1.0625rem', fontWeight: 700, color: '#182126' }}>
                  {drawerMode === 'create' ? 'Create tour' : 'Edit tour'}
                </h3>
                <span style={{ fontSize: '0.75rem', color: '#66747b' }}>
                  {drawerMode === 'create'
                    ? 'New experience record'
                    : `Last updated by Operations · ${selectedTour?.status || 'Active'}`}
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

            <form onSubmit={handleSaveTour} style={{ display: 'flex', flexDirection: 'column', gap: '0.875rem' }}>
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
                    style={{ width: '100%', height: '38px', padding: '0 0.5rem', fontSize: '0.8125rem' }}
                    value={formData.destinationId}
                    onChange={(e) => setFormData({ ...formData, destinationId: e.target.value })}
                  >
                    {destinations.map((d) => (
                      <option key={d.id} value={d.id}>{d.name}</option>
                    ))}
                  </select>
                </div>

                <div>
                  <label style={{ display: 'block', fontSize: '0.6875rem', fontWeight: 800, color: '#475569', textTransform: 'uppercase', marginBottom: '0.35rem' }}>
                    Category *
                  </label>
                  <select
                    className="btn-outline"
                    style={{ width: '100%', height: '38px', padding: '0 0.5rem', fontSize: '0.8125rem' }}
                    value={formData.category}
                    onChange={(e) => setFormData({ ...formData, category: e.target.value })}
                  >
                    {CATEGORIES.filter(c => c !== 'All').map((c) => (
                      <option key={c} value={c}>{c}</option>
                    ))}
                  </select>
                </div>
              </div>

              {/* 3-Column: Price, Duration, Start Time */}
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: '0.5rem' }}>
                <div>
                  <label style={{ display: 'block', fontSize: '0.6875rem', fontWeight: 800, color: '#475569', textTransform: 'uppercase', marginBottom: '0.35rem' }}>
                    Price USD
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
                  <label style={{ display: 'block', fontSize: '0.6875rem', fontWeight: 800, color: '#475569', textTransform: 'uppercase', marginBottom: '0.35rem' }}>
                    Duration (hrs)
                  </label>
                  <input
                    type="number"
                    min="1"
                    max="72"
                    required
                    className="staff-search-box"
                    style={{ maxWidth: '100%', width: '100%' }}
                    value={formData.durationHours}
                    onChange={(e) => setFormData({ ...formData, durationHours: e.target.value })}
                  />
                </div>

                <div>
                  <label style={{ display: 'block', fontSize: '0.6875rem', fontWeight: 800, color: '#475569', textTransform: 'uppercase', marginBottom: '0.35rem' }}>
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

              {/* Cover Image Upload Box matching Figma */}
              <div>
                <label style={{ display: 'block', fontSize: '0.6875rem', fontWeight: 800, color: '#475569', textTransform: 'uppercase', marginBottom: '0.35rem' }}>
                  Cover image
                </label>
                <div style={{ display: 'flex', alignItems: 'center', gap: '0.875rem', padding: '0.75rem', border: '1px solid #dde3e5', borderRadius: '8px', background: '#f8fafa' }}>
                  {imagePreview ? (
                    <img
                      src={imagePreview}
                      alt="Preview"
                      style={{ width: '64px', height: '48px', objectFit: 'cover', borderRadius: '6px' }}
                    />
                  ) : (
                    <div style={{ width: '64px', height: '48px', background: '#e2e8f0', borderRadius: '6px', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '0.6875rem', color: '#64748b' }}>
                      No img
                    </div>
                  )}
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <p style={{ margin: 0, fontSize: '0.75rem', fontWeight: 600, color: '#182126', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                      {imageFile ? imageFile.name : (selectedTour?.name ? `${selectedTour.name.toLowerCase().replace(/\s+/g, '-')}.jpg` : 'experience.jpg')}
                    </p>
                    <label style={{ fontSize: '0.75rem', color: '#b7791f', fontWeight: 700, cursor: 'pointer', textDecoration: 'underline' }}>
                      Replace image
                      <input
                        type="file"
                        accept="image/jpeg,image/png,image/webp"
                        style={{ display: 'none' }}
                        onChange={onImageChange}
                      />
                    </label>
                  </div>
                </div>
              </div>

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
                >
                  Save as draft
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
