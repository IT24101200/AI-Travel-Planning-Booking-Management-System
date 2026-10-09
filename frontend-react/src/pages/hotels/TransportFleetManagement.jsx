import { useEffect, useState } from 'react'
import {
  createTransport,
  deleteTransport,
  fetchDestinations,
  fetchTransport,
  fetchTransportCoverage,
  updateTransport
} from '../../services/apiClient.js'
import { usePageTitle } from '../../lib/hooks.js'
import { formatLocalSchedule } from '../../lib/dateTime.js'
import { AlertBanner } from '../../components/ui/AlertBanner.jsx'
import { LoadingState } from '../../components/ui/LoadingState.jsx'
import { transportErrorMessage } from '../../services/transportErrors.js'
import {
  buildTransportPayload,
  getCoveragePresentation,
  normalizeTransportResponse,
  TRANSPORT_PAGE_SIZE,
  validateTransportForm
} from '../../services/transportManagement.js'
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
    return formatLocalSchedule(isoString)
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
  const [routeFromFilter, setRouteFromFilter] = useState('')
  const [routeToFilter, setRouteToFilter] = useState('')
  const [statusFilter, setStatusFilter] = useState('All')
  const [page, setPage] = useState(1)
  const [pagination, setPagination] = useState({
    page: 1,
    pageSize: TRANSPORT_PAGE_SIZE,
    totalCount: 0,
    totalPages: 1,
    activeCount: 0
  })
  const [destinations, setDestinations] = useState([])

  const [coverageForm, setCoverageForm] = useState({
    from: '',
    to: '',
    startDate: '',
    endDate: '',
    travellers: 1
  })
  const [coverage, setCoverage] = useState(null)
  const [coverageLoading, setCoverageLoading] = useState(false)
  const [coverageError, setCoverageError] = useState('')

  // Drawer state
  const [drawerMode, setDrawerMode] = useState(null) // 'edit' | 'create' | null
  const [selectedSchedule, setSelectedSchedule] = useState(null)
  const [formData, setFormData] = useState({
    type: 'Car',
    provider: '',
    contactPhone: '',
    contactEmail: '',
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

  async function loadFleet(requestPage = page, isCancelled = () => false) {
    setLoading(true)
    setError(null)
    try {
      const response = await fetchTransport({
        type,
        routeFrom: routeFromFilter,
        routeTo: routeToFilter,
        status: statusFilter,
        page: requestPage,
        pageSize: TRANSPORT_PAGE_SIZE,
        sortBy: 'departure'
      })
      const normalized = normalizeTransportResponse(response)
      if (!isCancelled()) {
        const safePage = Math.min(normalized.page, normalized.totalPages)
        if (requestPage > normalized.totalPages) {
          setPage(safePage)
        }
        const mapped = normalized.data.map((t) => {
          const typeStr = typeof t.type === 'string' ? t.type : ''

          return {
            id: t.id,
            code: `TR-${t.id}`,
            type: typeStr,
            provider: t.provider,
            contactPhone: t.contactPhone || '',
            contactEmail: t.contactEmail || '',
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
        setPagination({ ...normalized, page: safePage, activeCount: Number(response?.activeCount) || 0 })
      }
    } catch (err) {
      if (!isCancelled()) {
        setError(transportErrorMessage(err, 'Unable to load transport catalogue. Please retry.'))
      }
    } finally {
      if (!isCancelled()) setLoading(false)
    }
  }

  useEffect(() => {
    let cancelled = false
    const request = setTimeout(() => {
      if (!cancelled) void loadFleet(page, () => cancelled)
    }, 0)
    return () => {
      cancelled = true
      clearTimeout(request)
    }
    // loadFleet intentionally reads the current server-filter values.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [page, type, routeFromFilter, routeToFilter, statusFilter])

  useEffect(() => {
    let cancelled = false
    fetchDestinations()
      .then((response) => {
        if (!cancelled) {
          const values = Array.isArray(response) ? response : (response?.data || [])
          setDestinations(values.filter((destination) => destination?.name).sort((a, b) => a.name.localeCompare(b.name)))
        }
      })
      .catch(() => {
        // Destination suggestions are an enhancement; free-text route entry remains available.
      })
    return () => { cancelled = true }
  }, [])

  function selectForEdit(sch) {
    setSelectedSchedule(sch)
    setDrawerMode('edit')
    setFormData({
      type: sch.type,
      provider: sch.provider,
      contactPhone: sch.contactPhone || '',
      contactEmail: sch.contactEmail || '',
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
      contactPhone: '',
      contactEmail: '',
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

  const pages = pagination.totalPages
  const view = rows
  const coverageView = coverage ? getCoveragePresentation(coverage) : null

  async function handleSave(e) {
    e.preventDefault()
    const validationError = validateTransportForm(formData)
    if (validationError) {
      setNotice(validationError)
      return
    }
    setBusy(true)
    setNotice('')
    try {
      // datetime-local is intentionally sent without a timezone suffix. The
      // backend stores TransportOption timestamps as timestamp-without-time-zone.
      const payload = buildTransportPayload(formData)
      if (drawerMode === 'create') {
        await createTransport(payload)
        setNotice(`Schedule "${formData.provider.trim()}" created successfully.`)
      } else if (drawerMode === 'edit' && selectedSchedule) {
        await updateTransport(selectedSchedule.id, payload)
        setNotice(`Schedule #${selectedSchedule.id} updated successfully.`)
      }
      await loadFleet(page)
    } catch (err) {
      setNotice(transportErrorMessage(err, 'Unable to save transport schedule. Please retry.'))
    } finally {
      setBusy(false)
    }
  }

  async function deleteSchedule(sch) {
    if (!window.confirm(`Permanently delete schedule ${sch.code}? This cannot be undone.`)) return
    try {
      await deleteTransport(sch.id)
      setNotice(`Schedule ${sch.code} permanently deleted.`)
      await loadFleet(page)
    } catch (err) {
      setNotice(transportErrorMessage(err, 'Unable to delete this transport schedule.'))
    }
  }

  async function checkCoverage(event) {
    event.preventDefault()
    setCoverageError('')
    setCoverage(null)
    const from = coverageForm.from.trim()
    const to = coverageForm.to.trim()
    if (!from || !to || !coverageForm.startDate || !coverageForm.endDate) {
      setCoverageError('Route endpoints and date range are required.')
      return
    }
    if (normalizeRoute(from) === normalizeRoute(to)) {
      setCoverageError('Route origin and destination must be different.')
      return
    }
    if (coverageForm.endDate < coverageForm.startDate) {
      setCoverageError('Coverage end date cannot be before the start date.')
      return
    }
    if (!Number.isInteger(Number(coverageForm.travellers)) || Number(coverageForm.travellers) < 1) {
      setCoverageError('Travellers must be a whole number greater than zero.')
      return
    }

    setCoverageLoading(true)
    try {
      const result = await fetchTransportCoverage({
        routeFrom: from,
        routeTo: to,
        startDate: coverageForm.startDate,
        endDate: coverageForm.endDate,
        travellers: Number(coverageForm.travellers)
      })
      setCoverage(result)
    } catch (err) {
      setCoverageError(transportErrorMessage(err, 'Unable to check route coverage. Please retry.'))
    } finally {
      setCoverageLoading(false)
    }
  }

  function normalizeRoute(value) {
    return String(value || '').trim().replace(/\s+/g, ' ').toLowerCase()
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
            onClick={() => loadFleet(page)}
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
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: '0.75rem', flexWrap: 'wrap' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', flexWrap: 'wrap' }}>
          <div className="staff-search-box" style={{ maxWidth: '220px' }}>
            <SearchIcon size={16} />
            <input
              type="text"
              list="transport-destination-options"
              placeholder="Route from"
              value={routeFromFilter}
              onChange={(e) => {
                setRouteFromFilter(e.target.value)
                setPage(1)
              }}
            />
          </div>
          <div className="staff-search-box" style={{ maxWidth: '220px' }}>
            <SearchIcon size={16} />
            <input
              type="text"
              list="transport-destination-options"
              placeholder="Route to"
              value={routeToFilter}
              onChange={(e) => {
                setRouteToFilter(e.target.value)
                setPage(1)
              }}
            />
          </div>
          <select
            className="staff-search-box"
            style={{ width: 'auto', minWidth: '130px' }}
            value={statusFilter}
            onChange={(e) => {
              setStatusFilter(e.target.value)
              setPage(1)
            }}
            aria-label="Transport status filter"
          >
            <option value="All">All statuses</option>
            <option value="Active">Active</option>
            <option value="Inactive">Inactive</option>
          </select>
          <datalist id="transport-destination-options">
            {destinations.map((destination) => (
              <option key={destination.id} value={destination.name} />
            ))}
          </datalist>
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
      <p style={{ margin: '0.6rem 0 0', color: '#66747b', fontSize: '0.75rem' }}>
        Filters are applied by the server across the full staff catalogue. Choose canonical destination names when possible.
      </p>

      {error && (
        <AlertBanner
          type="error"
          message={error}
          onRetry={() => loadFleet(page)}
          onDismiss={() => setError(null)}
        />
      )}

      {notice && (
        <AlertBanner
          type={notice.includes('Unable') || notice.includes('cannot') || notice.includes('required') || notice.includes('must') ? 'error' : 'success'}
          message={notice}
          onDismiss={() => setNotice('')}
        />
      )}

      {/* ── Split Workspace matching Figma 2:28401 ── */}
      <section className="staff-card" style={{ marginTop: '1rem' }}>
        <div className="staff-card__head">
          <div>
            <h3 className="staff-card__title">Catalogue coverage</h3>
            <p className="staff-card__sub">Aggregate counts for the current server filters</p>
          </div>
        </div>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(150px, 1fr))', gap: '0.75rem' }}>
          {[
            ['Active transport', pagination.activeCount],
            ['Matching rows', pagination.totalCount],
            ['Routes on page', new Set(rows.map((row) => `${row.from} -> ${row.to}`)).size],
            ['Upcoming on page', rows.filter((row) => row.departureRaw && new Date(row.departureRaw) >= new Date()).length]
          ].map(([label, value]) => (
            <div key={label} style={{ padding: '0.85rem', border: '1px solid #e2e8e4', borderRadius: '10px', background: '#f8fbf9' }}>
              <div style={{ color: '#66747b', fontSize: '0.7rem', textTransform: 'uppercase', fontWeight: 800 }}>{label}</div>
              <strong style={{ display: 'block', marginTop: '0.25rem', color: '#123f32', fontSize: '1.25rem' }}>{value}</strong>
            </div>
          ))}
        </div>
      </section>

      <section className="staff-card" style={{ marginTop: '1rem' }}>
        <div className="staff-card__head">
          <div>
            <h3 className="staff-card__title">Check route coverage</h3>
            <p className="staff-card__sub">Read-only check for active dated departures and traveller capacity.</p>
          </div>
        </div>
        <form onSubmit={checkCoverage} style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(150px, 1fr))', gap: '0.65rem', alignItems: 'end' }}>
          <label style={{ color: '#475569', fontSize: '0.72rem', fontWeight: 800 }}>
            From
            <input className="staff-search-box" style={{ width: '100%', marginTop: '0.25rem' }} list="transport-destination-options" value={coverageForm.from} onChange={(e) => setCoverageForm({ ...coverageForm, from: e.target.value })} />
          </label>
          <label style={{ color: '#475569', fontSize: '0.72rem', fontWeight: 800 }}>
            To
            <input className="staff-search-box" style={{ width: '100%', marginTop: '0.25rem' }} list="transport-destination-options" value={coverageForm.to} onChange={(e) => setCoverageForm({ ...coverageForm, to: e.target.value })} />
          </label>
          <label style={{ color: '#475569', fontSize: '0.72rem', fontWeight: 800 }}>
            Start date
            <input type="date" className="staff-search-box" style={{ width: '100%', marginTop: '0.25rem' }} value={coverageForm.startDate} onChange={(e) => setCoverageForm({ ...coverageForm, startDate: e.target.value })} />
          </label>
          <label style={{ color: '#475569', fontSize: '0.72rem', fontWeight: 800 }}>
            End date
            <input type="date" className="staff-search-box" style={{ width: '100%', marginTop: '0.25rem' }} value={coverageForm.endDate} onChange={(e) => setCoverageForm({ ...coverageForm, endDate: e.target.value })} />
          </label>
          <label style={{ color: '#475569', fontSize: '0.72rem', fontWeight: 800 }}>
            Travellers
            <input type="number" min="1" max="100" className="staff-search-box" style={{ width: '100%', marginTop: '0.25rem' }} value={coverageForm.travellers} onChange={(e) => setCoverageForm({ ...coverageForm, travellers: e.target.value })} />
          </label>
          <button type="submit" className="btn-outline" disabled={coverageLoading}>{coverageLoading ? 'Checking…' : 'Check coverage'}</button>
        </form>
        {coverageError && <p style={{ color: '#b91c1c', fontSize: '0.78rem', marginBottom: 0 }}>{coverageError}</p>}
        {coverageView && (
          <div style={{ marginTop: '0.8rem', padding: '0.8rem', borderRadius: '10px', background: coverageView.status === 'Available' ? '#f0fdf4' : '#fff7ed', border: `1px solid ${coverageView.status === 'Available' ? '#bbf7d0' : '#fed7aa'}` }}>
            <strong style={{ color: coverageView.status === 'Available' ? '#166534' : '#9a3412' }}>{coverageView.reasonCode}</strong>
            <span style={{ marginLeft: '0.5rem', color: '#475569', fontSize: '0.8rem' }}>{coverageView.message}</span>
            <div style={{ marginTop: '0.4rem', color: '#475569', fontSize: '0.76rem' }}>
              Active: {coverageView.totalActive} · Route: {coverageView.routeMatches} · Dates: {coverageView.dateMatches} · Capacity: {coverageView.capacityMatches} · Available: {coverageView.availableMatches}
            </div>
          </div>
        )}
      </section>

      <div className="split-workspace" style={{ gridTemplateColumns: drawerMode ? 'minmax(0, 1fr) 420px' : '1fr' }}>
        {/* Left Table Card */}
        <div className="staff-card">
          <div className="staff-card__head">
            <div>
              <h3 className="staff-card__title">Upcoming schedules</h3>
              <p className="staff-card__sub">{pagination.totalCount} matching server results · page {page} of {pages}</p>
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
                      {statusFilter === 'Active' ? 'No active transport for these filters.' : 'No transport options found.'}
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>

          {/* Pagination */}
          <div className="staff-pagination">
            <span>
              Showing {pagination.totalCount > 0 ? (page - 1) * pagination.pageSize + 1 : 0}–{pagination.totalCount > 0 ? (page - 1) * pagination.pageSize + rows.length : 0} of {pagination.totalCount} services
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
              <span style={{ padding: '0 0.5rem', alignSelf: 'center', color: '#475569', fontSize: '0.8rem' }}>
                Page {page} of {pages}
              </span>
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
                    ? 'One dated departure; not a reusable vehicle'
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

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '0.75rem' }}>
                <label>
                  Contact phone
                  <input type="tel" maxLength={30} className="staff-search-box"
                    style={{ width: '100%' }} value={formData.contactPhone}
                    onChange={(e) => setFormData({ ...formData, contactPhone: e.target.value })} />
                </label>
                <label>
                  Contact email
                  <input type="email" maxLength={254} className="staff-search-box"
                    style={{ width: '100%' }} value={formData.contactEmail}
                    onChange={(e) => setFormData({ ...formData, contactEmail: e.target.value })} />
                </label>
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
                    Route from *
                  </label>
                  <input
                    type="text"
                    required
                    list="transport-destination-options"
                    placeholder="e.g. Colombo"
                    className="staff-search-box"
                    style={{ maxWidth: '100%', width: '100%' }}
                    value={formData.from}
                    onChange={(e) => setFormData({ ...formData, from: e.target.value })}
                  />
                  <small style={{ display: 'block', marginTop: '0.25rem', color: '#66747b', fontSize: '0.7rem' }}>
                    Use a destination catalogue name when available.
                  </small>
                </div>

                <div>
                  <label style={{ display: 'block', fontSize: '0.6875rem', fontWeight: 800, color: '#475569', textTransform: 'uppercase', marginBottom: '0.35rem' }}>
                    Route to *
                  </label>
                  <input
                    type="text"
                    required
                    list="transport-destination-options"
                    placeholder="e.g. Sigiriya"
                    className="staff-search-box"
                    style={{ maxWidth: '100%', width: '100%' }}
                    value={formData.to}
                    onChange={(e) => setFormData({ ...formData, to: e.target.value })}
                  />
                  <small style={{ display: 'block', marginTop: '0.25rem', color: '#66747b', fontSize: '0.7rem' }}>
                    Use a destination catalogue name when available.
                  </small>
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
                <small style={{ display: 'block', marginTop: '0.25rem', color: '#66747b', fontSize: '0.7rem' }}>
                  This record represents one dated departure.
                </small>
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
                    max="1000"
                    required
                    className="staff-search-box"
                    style={{ maxWidth: '100%', width: '100%' }}
                    value={formData.capacity}
                    onChange={(e) => setFormData({ ...formData, capacity: e.target.value })}
                  />
                  <small style={{ display: 'block', marginTop: '0.25rem', color: '#66747b', fontSize: '0.7rem' }}>
                    Total passenger seats for this departure.
                  </small>
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
                  <small style={{ display: 'block', marginTop: '0.25rem', color: '#66747b', fontSize: '0.7rem' }}>
                    Price per passenger; zero is accepted.
                  </small>
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
