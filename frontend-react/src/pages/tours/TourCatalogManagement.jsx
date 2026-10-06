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
  const [form, setForm] = useState({ name: '', destinationId: '', price: '', duration: '', category: 'Heritage', defaultStartTime: '09:00' })
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
        defaultStartTime: row.defaultStartTime,
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
          <label>
            Start Time
            <input className="input" type="time" value={form.defaultStartTime} onChange={(e) => setForm({ ...form, defaultStartTime: e.target.value })} />
          </label>
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
                style={{
                  height: '28px',
                  padding: '0 8px',
                  color: '#182126',
                  backgroundColor: '#ffffff',
                  borderColor: '#c8d1d4'
                }}
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
                    className="staff-select"
                    style={{
                      width: '100%',
                      height: '38px',
                      padding: '0 0.5rem',
                      fontSize: '0.8125rem',
                      color: '#182126',
                      backgroundColor: '#ffffff',
                      border: '1px solid #c8d1d4',
                      borderRadius: '8px',
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
                    className="staff-select"
                    style={{
                      width: '100%',
                      height: '38px',
                      padding: '0 0.5rem',
                      fontSize: '0.8125rem',
                      color: '#182126',
                      backgroundColor: '#ffffff',
                      border: '1px solid #c8d1d4',
                      borderRadius: '8px',
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
