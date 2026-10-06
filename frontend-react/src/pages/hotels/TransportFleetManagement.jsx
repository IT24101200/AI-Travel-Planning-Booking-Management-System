import { useEffect, useMemo, useState } from 'react'
import { createTransport, deleteTransport, fetchTransport, updateTransport } from '../../services/apiClient.js'
import { usePageTitle } from '../../lib/hooks.js'
import { AlertBanner } from '../../components/ui/AlertBanner.jsx'
import { LoadingState } from '../../components/ui/LoadingState.jsx'
import {
  PlusIcon,
  SearchIcon,
  RefreshIcon,
  CloseIcon,
  CheckIcon,
  CarIcon,
  TrainIcon,
  BusFrontIcon,
  PlaneIcon,
  TrashIcon,
  EditIcon
} from '../../components/ui/Icons.jsx'
import ImageUploadWidget from '../../components/common/ImageUploadWidget.jsx'

const MODES = ['All', 'Car', 'Van', 'Train', 'Bus', 'Flight']

function formatDateTimeFigma(isoString) {
  if (!isoString) return '—'
  try {
    const d = new Date(isoString)
    if (isNaN(d.getTime())) return '—'
    return `${d.getDate()} ${d.toLocaleString('default', { month: 'short' })} · ${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`
  } catch {
    return isoString
  }
}

/**
 * Serendib Trails — Transport Fleet Management
 * Designed based on Figma Dev Mode Specifications (node-id: 2:28401)
 */
export default function TransportFleetManagement() {
  const [rows, setRows] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [notice, setNotice] = useState('')
  const [type, setType] = useState('All')
  const [query, setQuery] = useState('')
  const [page, setPage] = useState(1)

  // Drawer state
  const [drawerMode, setDrawerMode] = useState(null) // 'edit' | 'create' | null
  const [selectedSchedule, setSelectedSchedule] = useState(null)
  const [formData, setFormData] = useState({
    type: 'Car',
    provider: '',
    from: '',
    to: '',
    price: '',
    currency: 'LKR',
    capacity: '',
    departureTime: '',
    arrivalTime: '',
    imageUrl: '',
    status: 'Active'
  })
  const [busy, setBusy] = useState(false)

  usePageTitle('Transport Fleet · Serendib Trails')

  async function loadFleet(cancelled = false) {
    setLoading(true)
    setError(null)
    try {
      const res = await fetchTransport(undefined, undefined, 'All')
      const live = Array.isArray(res) ? res : (res?.data || [])
      if (!cancelled) {
        const mapped = live.map((t) => {
          const typeStr = typeof t.type === 'string' ? t.type : ''

          return {
            id: t.id,
            code: `TR-${t.id}`,
            type: typeStr,
            provider: t.provider,
            from: t.routeFrom,
            to: t.routeTo,
            price: Number(t.price),
            currency: t.currency || 'LKR',
            capacity: Number(t.capacity),
            departureRaw: t.departureTime,
            arrivalRaw: t.arrivalTime,
            departureFormatted: formatDateTimeFigma(t.departureTime),
            arrivalFormatted: formatDateTimeFigma(t.arrivalTime),
            imageUrl: t.imageUrl || '',
            status: t.status || 'Active'
          }
        })
        setRows(mapped)
      }
    } catch (err) {
      if (!cancelled) {
        setError(err.response?.data?.message || err.message || 'Failed to load transport from database.')
      }
    } finally {
      if (!cancelled) setLoading(false)
    }
  }

  useEffect(() => {
    let cancelled = false
    // This starts an async API load; its state updates occur after the request.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    loadFleet(cancelled)
    return () => { cancelled = true }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  function selectForEdit(sch) {
    setSelectedSchedule(sch)
    setDrawerMode('edit')
    setFormData({
      type: sch.type,
      provider: sch.provider,
      from: sch.from,
      to: sch.to,
      price: sch.price,
      currency: sch.currency,
      capacity: sch.capacity,
      departureTime: sch.departureRaw ? sch.departureRaw.substring(0, 16) : '2026-11-12T08:30',
      arrivalTime: sch.arrivalRaw ? sch.arrivalRaw.substring(0, 16) : '2026-11-12T12:45',
      imageUrl: sch.imageUrl || '',
      status: sch.status
    })
  }

  function startCreate() {
    setDrawerMode('create')
    setSelectedSchedule(null)
    setFormData({
      type: 'Car',
      provider: '',
      from: '',
      to: '',
      price: '',
      currency: 'LKR',
      capacity: '',
      departureTime: '',
      arrivalTime: '',
      imageUrl: '',
      status: 'Active'
    })
  }

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase()
    return rows.filter((r) => {
      const matchType = type === 'All' || r.type.toLowerCase() === type.toLowerCase()
      const matchQ = !q || `${r.from} ${r.to} ${r.provider} ${r.code}`.toLowerCase().includes(q)
      return matchType && matchQ
    })
  }, [rows, type, query])

  const pageSize = 6
  const pages = Math.max(1, Math.ceil(filtered.length / pageSize))
  const view = filtered.slice((page - 1) * pageSize, page * pageSize)

  async function handleSave(e) {
    e.preventDefault()
    if (!formData.type || !formData.provider.trim() || !formData.from.trim() || !formData.to.trim()) {
      setNotice('Please provide transport type, provider, origin, and destination.')
      return
    }
    if (!formData.departureTime || !formData.arrivalTime) {
      setNotice('Departure and arrival times are required.')
      return
    }
    setBusy(true)
    setNotice('')
    try {
      const depDate = new Date(formData.departureTime)
      const arrDate = new Date(formData.arrivalTime)
      if (Number.isNaN(depDate.getTime()) || Number.isNaN(arrDate.getTime()) || arrDate <= depDate) {
        setNotice('Arrival must be later than departure.')
        return
      }
      if (!Number.isInteger(Number(formData.capacity)) || Number(formData.capacity) < 1) {
        setNotice('Capacity must be a whole number greater than zero.')
        return
      }
      if (!Number.isFinite(Number(formData.price)) || Number(formData.price) < 0) {
        setNotice('Price must be zero or greater.')
        return
      }

      if (drawerMode === 'create') {
        await createTransport({
          type: formData.type,
          provider: formData.provider.trim(),
          routeFrom: formData.from.trim(),
          routeTo: formData.to.trim(),
          price: Number(formData.price),
          capacity: Number(formData.capacity),
          currency: formData.currency,
          status: formData.status,
          departureTime: depDate.toISOString(),
          arrivalTime: arrDate.toISOString(),
          imageUrl: formData.imageUrl || '',
        })
        setNotice(`Schedule "${formData.provider.trim()}" created successfully.`)
      } else if (drawerMode === 'edit' && selectedSchedule) {
        await updateTransport(selectedSchedule.id, {
          type: formData.type,
          provider: formData.provider.trim(),
          routeFrom: formData.from.trim(),
          routeTo: formData.to.trim(),
          price: Number(formData.price),
          capacity: Number(formData.capacity),
          currency: formData.currency,
          status: formData.status,
          departureTime: depDate.toISOString(),
          arrivalTime: arrDate.toISOString(),
          imageUrl: formData.imageUrl || '',
        })
        setNotice(`Schedule #${selectedSchedule.id} updated successfully.`)
      }
      await loadFleet()
    } catch (err) {
      setNotice(`Failed to save schedule: ${err.response?.data?.message || err.message}`)
    } finally {
      setBusy(false)
    }
  }

  async function deleteSchedule(sch) {
    if (!window.confirm(`Permanently delete schedule ${sch.code}? This cannot be undone.`)) return
    try {
      await deleteTransport(sch.id)
      setNotice(`Schedule ${sch.code} permanently deleted.`)
      await loadFleet()
    } catch (err) {
      setNotice(`Failed to delete schedule: ${err.response?.data?.message || err.message || 'The server rejected the request.'}`)
    }
  }

  function renderModeIcon(modeType) {
    switch (modeType.toLowerCase()) {
      case 'car':
        return <CarIcon size={18} />
      case 'train':
        return <TrainIcon size={18} />
      case 'bus':
        return <BusFrontIcon size={18} />
      case 'flight':
        return <PlaneIcon size={18} />
      default:
        return <CarIcon size={18} />
    }
  }

  return (
    <div className="staff-page">
      {/* ── Page Header matching Figma 2:28401 ── */}
      <header className="staff-page__head">
        <div className="staff-page__title-block">
          <p className="staff-page__eyebrow">LOGISTICS / FLEET</p>
          <h1 className="staff-page__title">Transport fleet</h1>
          <p className="staff-page__subtitle">
            Coordinate intercity schedules, capacity, passenger rates, and service status.
          </p>
        </div>
        <div className="staff-page__actions">
          <button
            type="button"
            className="btn-outline"
            onClick={() => loadFleet(false)}
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
            <span>Add schedule</span>
          </button>
        </div>
      </header>

      {/* ── Filter Toolbar matching Figma ── */}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: '1rem', flexWrap: 'wrap' }}>
        <div className="staff-search-box" style={{ maxWidth: '320px' }}>
          <SearchIcon size={16} />
          <input
            type="text"
            placeholder="Search schedule, origin, destination"
            value={query}
            onChange={(e) => {
              setQuery(e.target.value)
              setPage(1)
            }}
          />
        </div>

        <div className="staff-tabs" style={{ width: 'auto', flex: 1, justifyContent: 'flex-end' }}>
          {MODES.map((m) => (
            <button
              key={m}
              type="button"
              className={`staff-tab ${type === m ? 'is-active' : ''}`}
              onClick={() => {
                setType(m)
                setPage(1)
              }}
            >
              {m}
            </button>
          ))}
        </div>
      </div>

      {error && (
        <AlertBanner
          type="error"
          message={error}
          onRetry={() => loadFleet(false)}
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

      {/* ── Split Workspace matching Figma 2:28401 ── */}
      <div className="split-workspace" style={{ gridTemplateColumns: drawerMode ? 'minmax(0, 1fr) 420px' : '1fr' }}>
        {/* Left Table Card */}
        <div className="staff-card">
          <div className="staff-card__head">
            <div>
              <h3 className="staff-card__title">Upcoming schedules</h3>
              <p className="staff-card__sub">{filtered.length} active services · next 30 days</p>
            </div>
          </div>

          <div className="staff-table-wrap">
            <table className="staff-table">
              <thead>
                <tr>
                  <th>MODE / ID</th>
                  <th>ORIGIN</th>
                  <th>DESTINATION</th>
                  <th>DEPARTURE</th>
                  <th>ARRIVAL</th>
                  <th>SEATS</th>
                  <th>RATE</th>
                  <th>STATUS</th>
                  <th style={{ textAlign: 'right' }}>ACTIONS</th>
                </tr>
              </thead>
              <tbody>
                {loading ? (
                  <tr>
                    <td colSpan={9} style={{ textAlign: 'center', padding: '2.5rem' }}>
                      <LoadingState message="Loading transport schedules from database…" />
                    </td>
                  </tr>
                ) : view.length > 0 ? (
                  view.map((sch) => {
                    const isSelected = selectedSchedule?.id === sch.id && drawerMode === 'edit'
                    return (
                      <tr
                        key={sch.id}
                        className={isSelected ? 'is-selected' : ''}
                        style={{ cursor: 'pointer' }}
                        onClick={() => selectForEdit(sch)}
                      >
                        <td>
                          <div style={{ display: 'flex', alignItems: 'center', gap: '0.625rem' }}>
                            {sch.imageUrl ? (
                              <img
                                src={sch.imageUrl}
                                alt={sch.provider}
                                style={{
                                  width: '48px',
                                  height: '36px',
                                  borderRadius: '5px',
                                  objectFit: 'cover',
                                  border: '1px solid #d0d7de',
                                  flexShrink: 0
                                }}
                                onError={(e) => { e.target.style.display = 'none' }}
                              />
                            ) : (
                              <div
                                style={{
                                  width: '36px',
                                  height: '32px',
                                  borderRadius: '6px',
                                  backgroundColor: '#e0f2fe',
                                  color: '#0369a1',
                                  display: 'flex',
                                  alignItems: 'center',
                                  justifyContent: 'center',
                                  flexShrink: 0
                                }}
                              >
                                {renderModeIcon(sch.type)}
                              </div>
                            )}
                            <div style={{ display: 'flex', flexDirection: 'column' }}>
                              <strong style={{ color: '#182126', fontSize: '0.8125rem' }}>{sch.provider}</strong>
                              <span style={{ fontSize: '0.6875rem', color: '#66747b' }}>{sch.code} · {sch.type}</span>
                            </div>
                          </div>
                        </td>
                        <td style={{ color: '#182126' }}>{sch.from}</td>
                        <td style={{ color: '#182126' }}>{sch.to}</td>
                        <td style={{ color: '#66747b', fontSize: '0.75rem' }}>{sch.departureFormatted}</td>
                        <td style={{ color: '#66747b', fontSize: '0.75rem' }}>{sch.arrivalFormatted}</td>
                        <td style={{ fontWeight: 600, color: '#182126' }}>{sch.capacity}</td>
                        <td style={{ fontWeight: 700, color: '#182126' }}>{sch.currency} {sch.price.toFixed(2)}</td>
                        <td>
                          <span
                            className={`badge-pill ${
                              sch.status === 'Active' ? 'badge-green' : 'badge-gray'
                            }`}
                          >
                            <span className="badge-dot" /> {sch.status}
                          </span>
                        </td>
                        <td style={{ textAlign: 'right' }} onClick={(e) => e.stopPropagation()}>
                          <div style={{ display: 'inline-flex', alignItems: 'center', gap: '0.35rem' }}>
                          <button
                            type="button"
                            className="btn-action-edit"
                            title="Edit Schedule"
                            onClick={() => selectForEdit(sch)}
                          >
                            <EditIcon size={12} />
                            <span>Edit</span>
                          </button>
                          <button
                            type="button"
                            className="btn-danger-soft"
                            title="Delete schedule"
                            onClick={() => deleteSchedule(sch)}
                            style={{ padding: '0.35rem 0.5rem' }}
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
                    <td colSpan={9} style={{ textAlign: 'center', padding: '2rem', color: '#66747b' }}>
                      {query ? `No transport services match “${query}”.` : 'No schedules in fleet.'}
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>

          {/* Pagination */}
          <div className="staff-pagination">
            <span>
              Showing {filtered.length > 0 ? (page - 1) * pageSize + 1 : 0}–{Math.min(page * pageSize, filtered.length)} of {filtered.length} services
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

        {/* Right Detail / Edit Drawer matching Figma 2:28401 */}
        {drawerMode && (
          <aside className="detail-pane" style={{ position: 'sticky', top: '5.5rem' }}>
            <div className="detail-pane__head">
              <div>
                <h3 style={{ margin: 0, fontSize: '1.0625rem', fontWeight: 700, color: '#182126' }}>
                  {drawerMode === 'create' ? 'Add transport schedule' : 'Edit transport schedule'}
                </h3>
                <span style={{ fontSize: '0.75rem', color: '#66747b' }}>
                  {drawerMode === 'create'
                    ? 'New fleet route schedule'
                    : `${selectedSchedule?.code || ''} · Transport schedule`}
                </span>
              </div>
              <button
                type="button"
                className="btn-outline"
                style={{
                  height: '32px',
                  padding: '0 0.625rem',
                  color: '#182126',
                  backgroundColor: '#ffffff',
                  borderColor: '#c8d1d4'
                }}
                onClick={() => setDrawerMode(null)}
              >
                <CloseIcon size={14} />
                <span>Close</span>
              </button>
            </div>

            <form onSubmit={handleSave} style={{ display: 'flex', flexDirection: 'column', gap: '0.875rem' }}>
              <div>
                <label style={{ display: 'block', fontSize: '0.6875rem', fontWeight: 800, color: '#475569', textTransform: 'uppercase', marginBottom: '0.35rem' }}>
                  Transport mode *
                </label>
                <select
                  required
                  className="staff-search-box"
                  style={{ maxWidth: '100%', width: '100%' }}
                  value={formData.type}
                  onChange={(e) => setFormData({ ...formData, type: e.target.value })}
                >
                  {MODES.filter((mode) => mode !== 'All').map((mode) => (
                    <option key={mode} value={mode}>{mode}</option>
                  ))}
                </select>
              </div>

              <div>
                <label style={{ display: 'block', fontSize: '0.6875rem', fontWeight: 800, color: '#475569', textTransform: 'uppercase', marginBottom: '0.35rem' }}>
                  Provider *
                </label>
                <input
                  type="text"
                  required
                  placeholder="e.g. Sri Lanka Railways"
                  className="staff-search-box"
                  style={{ maxWidth: '100%', width: '100%' }}
                  value={formData.provider}
                  onChange={(e) => setFormData({ ...formData, provider: e.target.value })}
                />
              </div>

              {/* Cover Image Upload & Media Selection */}
              <div>
                <ImageUploadWidget
                  value={formData.imageUrl}
                  onChange={(url) => setFormData({ ...formData, imageUrl: url })}
                  category="transport"
                  label="Fleet vehicle cover image"
                />
              </div>

              {/* 2-Column: Origin & Destination */}
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '0.75rem' }}>
                <div>
                  <label style={{ display: 'block', fontSize: '0.6875rem', fontWeight: 800, color: '#475569', textTransform: 'uppercase', marginBottom: '0.35rem' }}>
                    Origin
                  </label>
                  <input
                    type="text"
                    required
                    placeholder="e.g. Colombo Airport"
                    className="staff-search-box"
                    style={{ maxWidth: '100%', width: '100%' }}
                    value={formData.from}
                    onChange={(e) => setFormData({ ...formData, from: e.target.value })}
                  />
                </div>

                <div>
                  <label style={{ display: 'block', fontSize: '0.6875rem', fontWeight: 800, color: '#475569', textTransform: 'uppercase', marginBottom: '0.35rem' }}>
                    Destination
                  </label>
                  <input
                    type="text"
                    required
                    placeholder="e.g. Sigiriya"
                    className="staff-search-box"
                    style={{ maxWidth: '100%', width: '100%' }}
                    value={formData.to}
                    onChange={(e) => setFormData({ ...formData, to: e.target.value })}
                  />
                </div>
              </div>

              {/* Departure & Arrival Datetimes */}
              <div>
                <label style={{ display: 'block', fontSize: '0.6875rem', fontWeight: 800, color: '#475569', textTransform: 'uppercase', marginBottom: '0.35rem' }}>
                  Departure datetime *
                </label>
                <input
                  type="datetime-local"
                  required
                  className="staff-search-box"
                  style={{ maxWidth: '100%', width: '100%' }}
                  value={formData.departureTime}
                  onChange={(e) => setFormData({ ...formData, departureTime: e.target.value })}
                />
              </div>

              <div>
                <label style={{ display: 'block', fontSize: '0.6875rem', fontWeight: 800, color: '#475569', textTransform: 'uppercase', marginBottom: '0.35rem' }}>
                  Arrival datetime *
                </label>
                <input
                  type="datetime-local"
                  required
                  className="staff-search-box"
                  style={{ maxWidth: '100%', width: '100%' }}
                  value={formData.arrivalTime}
                  onChange={(e) => setFormData({ ...formData, arrivalTime: e.target.value })}
                />
              </div>

              {/* 2-Column: Seat Capacity & Passenger Rate */}
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '0.75rem' }}>
                <div>
                  <label style={{ display: 'block', fontSize: '0.6875rem', fontWeight: 800, color: '#475569', textTransform: 'uppercase', marginBottom: '0.35rem' }}>
                    Seat capacity
                  </label>
                  <input
                    type="number"
                    min="1"
                    required
                    className="staff-search-box"
                    style={{ maxWidth: '100%', width: '100%' }}
                    value={formData.capacity}
                    onChange={(e) => setFormData({ ...formData, capacity: e.target.value })}
                  />
                </div>

                <div>
                  <label style={{ display: 'block', fontSize: '0.6875rem', fontWeight: 800, color: '#475569', textTransform: 'uppercase', marginBottom: '0.35rem' }}>
                    Passenger rate ({formData.currency})
                  </label>
                  <input
                    type="number"
                    step="0.01"
                    min="0"
                    required
                    className="staff-search-box"
                    style={{ maxWidth: '100%', width: '100%' }}
                    value={formData.price}
                    onChange={(e) => setFormData({ ...formData, price: e.target.value })}
                  />
                </div>
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '0.75rem' }}>
                <div>
                  <label style={{ display: 'block', fontSize: '0.6875rem', fontWeight: 800, color: '#475569', textTransform: 'uppercase', marginBottom: '0.35rem' }}>
                    Currency
                  </label>
                  <select
                    className="staff-search-box"
                    style={{ maxWidth: '100%', width: '100%' }}
                    value={formData.currency}
                    onChange={(e) => setFormData({ ...formData, currency: e.target.value })}
                  >
                    <option value="LKR">LKR</option>
                    <option value="USD">USD</option>
                  </select>
                </div>
                <div>
                  <label style={{ display: 'block', fontSize: '0.6875rem', fontWeight: 800, color: '#475569', textTransform: 'uppercase', marginBottom: '0.35rem' }}>
                    Status
                  </label>
                  <select
                    className="staff-search-box"
                    style={{ maxWidth: '100%', width: '100%' }}
                    value={formData.status}
                    onChange={(e) => setFormData({ ...formData, status: e.target.value })}
                  >
                    <option value="Active">Active</option>
                    <option value="Inactive">Inactive</option>
                  </select>
                </div>
              </div>

              {/* Capacity Check Passed Banner matching Figma */}

              {/* Actions matching Figma 2:28401 */}
              <div style={{ display: 'flex', gap: '0.5rem', marginTop: '0.5rem', justifyContent: 'flex-end', flexWrap: 'wrap' }}>
                <button
                  type="button"
                  className="btn-outline"
                  style={{
                    color: '#182126',
                    backgroundColor: '#ffffff',
                    borderColor: '#c8d1d4'
                  }}
                  onClick={() => setDrawerMode(null)}
                >
                  <CloseIcon size={14} />
                  <span>Cancel</span>
                </button>
                {drawerMode === 'edit' && selectedSchedule && (
                  <button
                    type="button"
                    className="btn-outline"
                    style={{
                      color: '#182126',
                      backgroundColor: '#ffffff',
                      borderColor: '#c8d1d4'
                    }}
                    onClick={() => {
                      setFormData({
                        ...formData,
                        provider: `${formData.provider} (Copy)`
                      })
                      setDrawerMode('create')
                    }}
                  >
                    Duplicate
                  </button>
                )}

                <button
                  type="submit"
                  className="btn-gold"
                  disabled={busy}
                >
                  <CheckIcon size={14} />
                  <span>{busy ? 'Saving…' : 'Save schedule'}</span>
                </button>
              </div>

              {drawerMode === 'edit' && selectedSchedule && (
                <button
                  type="button"
                  className="btn-danger-soft"
                  style={{ width: '100%', justifyContent: 'center', marginTop: '0.25rem' }}
                  onClick={() => deleteSchedule(selectedSchedule)}
                >
                  <TrashIcon size={14} />
                  <span>Delete schedule permanently</span>
                </button>
              )}
            </form>
          </aside>
        )}
      </div>
    </div>
  )
}
