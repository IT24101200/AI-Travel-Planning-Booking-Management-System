import { useEffect, useMemo, useState } from 'react'
import {
  addItineraryItem,
  fetchAgentLogs,
  fetchItinerariesForReview,
  fetchTours,
  removeItineraryItem,
  updateItineraryStatus,
} from '../../services/apiClient.js'
import { usePageTitle } from '../../lib/hooks.js'
import { formatPrice } from '../../lib/formatPrice.js'
import { AlertBanner } from '../../components/ui/AlertBanner.jsx'
import { LoadingState } from '../../components/ui/LoadingState.jsx'
import {
  SlidersIcon,
  SparklesIcon,
  RotateCcwIcon,
  RefreshIcon,
  CloseIcon,
  CheckIcon,
  TrashIcon,
  PlusIcon,
  SearchIcon
} from '../../components/ui/Icons.jsx'

const TABS = ['Draft', 'Proposed', 'Accepted', 'Discarded']
const PAGE_SIZE = 5

function calendarDate(value) {
  if (!value) return null
  const date = new Date(`${String(value).slice(0, 10)}T00:00:00Z`)
  return Number.isNaN(date.getTime()) ? null : date
}

function formatDate(value) {
  const date = value instanceof Date ? value : calendarDate(value)
  return date
    ? date.toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric', timeZone: 'UTC' })
    : 'Date unavailable'
}

function tourSchedule(tour) {
  const [hours, minutes, seconds = 0] = (tour.defaultStartTime ?? '').split(':').map(Number)
  const start = hours * 3600 + minutes * 60 + seconds
  const duration = Math.round(Number(tour.durationHours) * 3600)
  const end = start + duration
  if (!Number.isFinite(start) || !Number.isFinite(duration) || duration <= 0 || start < 0 || end >= 86400) {
    throw new Error('This tour needs a valid start time and duration within one day.')
  }
  return {
    startTime: new Date(start * 1000).toISOString().slice(11, 19),
    endTime: new Date(end * 1000).toISOString().slice(11, 19),
  }
}

/**
 * Serendib Trails — AI Itinerary Review
 * Designed based on Figma Dev Mode Specifications (node-id: 2:27928)
 * Enhanced with role validation, filtering, sorting, and pagination.
 */
export default function ItineraryReview() {
  usePageTitle('AI Itinerary Review · Serendib Trails')

  const [itineraries, setItineraries] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [notice, setNotice] = useState(null)
  const [activeTab, setActiveTab] = useState('Proposed')
  const [selectedItinerary, setSelectedItinerary] = useState(null)
  const [reviewNote, setReviewNote] = useState('')
  const [busyAction, setBusyAction] = useState(false)
  const [removingItemId, setRemovingItemId] = useState(null)
  const [agentLogs, setAgentLogs] = useState([])
  const [loadingAgentLogs, setLoadingAgentLogs] = useState(false)
  const [showSettingsModal, setShowSettingsModal] = useState(false)
  const [activityDay, setActivityDay] = useState(null)
  const [activityTourId, setActivityTourId] = useState('')
  const [activeTours, setActiveTours] = useState([])
  const [loadingTours, setLoadingTours] = useState(false)
  const [addingActivity, setAddingActivity] = useState(false)

  // Filters, sorting, and pagination
  const [query, setQuery] = useState('')
  const [sort, setSort] = useState('newest')
  const [page, setPage] = useState(1)

  async function loadItineraries(showLoading = true) {
    if (showLoading) setLoading(true)
    setError('')
    try {
      const res = await fetchItinerariesForReview()
      const list = Array.isArray(res) ? res : (res?.data || [])

      const mapped = list.map((it) => {
        let statusStr = 'Proposed'
        if (typeof it.status === 'number') {
          statusStr = TABS[it.status] || 'Proposed'
        } else if (typeof it.status === 'string') {
          statusStr = it.status
        }

        const startDate = calendarDate(it.startDate)
        const endDate = calendarDate(it.endDate)
        const durationDays = startDate && endDate && endDate >= startDate
          ? Math.round((endDate - startDate) / 86400000) + 1
          : null

        return {
          ...it,
          code: `ITN-${it.id}`,
          title: `Itinerary #${it.id}`,
          totalCost: it.totalEstimatedCost ?? 0,
          status: statusStr,
          durationDays,
          items: it.items ?? [],
        }
      })

      setItineraries(mapped)
      setSelectedItinerary(current => mapped.find(it => it.id === current?.id) ?? mapped[0] ?? null)
    } catch (requestError) {
      setError(requestError.message || 'Unable to load itineraries for review.')
    } finally {
      if (showLoading) setLoading(false)
    }
  }

  useEffect(() => {
    loadItineraries()
  }, [])

  // Filter queue by status tab, search query, and sorting
  const filteredQueue = useMemo(() => {
    const q = query.trim().toLowerCase()
    const filtered = itineraries.filter((it) => {
      const matchesTab = activeTab === 'All' || it.status.toLowerCase() === activeTab.toLowerCase()
      const matchesQuery =
        !q ||
        [it.id, it.code, it.title, it.customerName, it.tripRequestId, it.customerId].some(
          (val) => String(val ?? '').toLowerCase().includes(q)
        )

      return matchesTab && matchesQuery
    })

    return [...filtered].sort((first, second) => {
      if (sort === 'cost-high') {
        return Number(second.totalCost) - Number(first.totalCost)
      }
      if (sort === 'cost-low') {
        return Number(first.totalCost) - Number(second.totalCost)
      }

      const firstTime = new Date(first.createdAt || 0).getTime() || 0
      const secondTime = new Date(second.createdAt || 0).getTime() || 0
      return sort === 'oldest' ? firstTime - secondTime : secondTime - firstTime
    })
  }, [itineraries, activeTab, query, sort])

  const totalPages = Math.max(1, Math.ceil(filteredQueue.length / PAGE_SIZE))
  const pagedQueue = filteredQueue.slice((page - 1) * PAGE_SIZE, page * PAGE_SIZE)

  // Keep selection synced
  useEffect(() => {
    if (filteredQueue.length > 0 && (!selectedItinerary || !filteredQueue.find(q => q.id === selectedItinerary.id))) {
      setSelectedItinerary(filteredQueue[0])
    }
  }, [filteredQueue, selectedItinerary])

  // Fetch AI agent logs when an itinerary is selected
  useEffect(() => {
    let cancelled = false
    async function loadLogs() {
      setAgentLogs([])
      if (!selectedItinerary?.tripRequestId) {
        setLoadingAgentLogs(false)
        return
      }
      setLoadingAgentLogs(true)
      try {
        const logs = await fetchAgentLogs(selectedItinerary.tripRequestId)
        if (!cancelled) {
          setAgentLogs(Array.isArray(logs) ? logs : (logs?.data || []))
        }
      } catch {
        if (!cancelled) setAgentLogs([])
      } finally {
        if (!cancelled) setLoadingAgentLogs(false)
      }
    }

    loadLogs()
    return () => { cancelled = true }
  }, [selectedItinerary])

  // Group items by day
  const dayGroups = useMemo(() => {
    if (!selectedItinerary?.items) return []
    const groups = {}
    selectedItinerary.items.forEach(item => {
      const d = item.dayNumber || 1
      if (!groups[d]) groups[d] = []
      groups[d].push(item)
    })
    return Object.entries(groups).map(([dayNum, items]) => {
      const subtotal = items.reduce((sum, it) => sum + Number(it.priceAtSelection ?? 0), 0)
      const date = calendarDate(selectedItinerary.startDate)
      if (date) date.setUTCDate(date.getUTCDate() + Number(dayNum) - 1)
      return {
        dayNumber: Number(dayNum),
        dateStr: formatDate(date),
        subtotal,
        items: items.sort((a, b) => (a.sequenceOrder || 0) - (b.sequenceOrder || 0))
      }
    })
  }, [selectedItinerary])

  async function handleStatusChange(newStatus) {
    if (!selectedItinerary) return
    setBusyAction(true)
    setNotice(null)
    try {
      await updateItineraryStatus(selectedItinerary.id, newStatus, reviewNote)
      setItineraries(prev => prev.map(it => it.id === selectedItinerary.id ? { ...it, status: newStatus } : it))
      if (selectedItinerary) {
        setSelectedItinerary({ ...selectedItinerary, status: newStatus })
      }
      setNotice({ type: 'success', message: `Itinerary #${selectedItinerary.code} marked as ${newStatus}.` })
    } catch (err) {
      setNotice({ type: 'error', message: err.response?.data?.message || err.message || `Failed to update status to ${newStatus}.` })
    } finally {
      setBusyAction(false)
    }
  }

  async function handleRemoveActivity(itemId) {
    if (!selectedItinerary) return
    setRemovingItemId(itemId)
    setError('')
    setNotice(null)
    try {
      await removeItineraryItem(selectedItinerary.id, itemId)
      setNotice({ type: 'success', message: 'Activity removed from day schedule.' })
      await loadItineraries(false)
    } catch (err) {
      setError(err.response?.data?.message || err.message || 'Failed to remove activity.')
    } finally {
      setRemovingItemId(null)
    }
  }

  async function openAddActivity(dayNumber) {
    setActivityDay(dayNumber)
    setActivityTourId('')
    setActiveTours([])
    setError('')
    setNotice(null)
    setLoadingTours(true)
    try {
      const response = await fetchTours({ status: 'Active', pageSize: 1000 })
      const tours = Array.isArray(response) ? response : (response?.data ?? [])
      setActiveTours(tours.filter(tour => tour.status === 'Active'))
    } catch (err) {
      setError(err.response?.data?.message || err.message || 'Failed to load active tours.')
    } finally {
      setLoadingTours(false)
    }
  }

  async function handleAddActivity(event) {
    event.preventDefault()
    if (!selectedItinerary || addingActivity) return
    setError('')
    setAddingActivity(true)
    try {
      const tour = activeTours.find(item => String(item.id) === activityTourId)
      if (!tour) throw new Error('Select an active tour.')
      const dayNumber = Number(activityDay)
      if (!Number.isInteger(dayNumber) || dayNumber < 1 || (selectedItinerary.durationDays != null && dayNumber > selectedItinerary.durationDays)) {
        throw new Error('Select a day within this itinerary.')
      }
      const sequenceOrder = Math.max(0, ...selectedItinerary.items
        .filter(item => Number(item.dayNumber) === dayNumber)
        .map(item => Number(item.sequenceOrder) || 0)) + 1
      await addItineraryItem(selectedItinerary.id, {
        tourId: tour.id,
        dayNumber,
        sequenceOrder,
        ...tourSchedule(tour),
      })
      setActivityDay(null)
      setNotice({ type: 'success', message: 'Activity added to itinerary.' })
      await loadItineraries(false)
    } catch (err) {
      setError(err.response?.data?.message || err.message || 'Failed to add activity.')
    } finally {
      setAddingActivity(false)
    }
  }

  return (
    <div className="staff-page">
      {/* ── Page Header matching Figma 2:27928 ── */}
      <header className="staff-page__head">
        <div className="staff-page__title-block">
          <p className="staff-page__eyebrow">AI OPERATIONS / REVIEW QUEUE</p>
          <h1 className="staff-page__title">AI itinerary review</h1>
          <p className="staff-page__subtitle">
            Inspect generated proposals, adjust activities, and approve traveller-ready plans.
          </p>
        </div>
        <div className="staff-page__actions">
          <button
            type="button"
            className="btn-outline"
            onClick={() => loadItineraries(false)}
            disabled={loading}
          >
            <RefreshIcon size={15} />
            <span>{loading ? 'Refreshing…' : 'Refresh'}</span>
          </button>
          <button
            type="button"
            className="btn-outline"
            onClick={() => setShowSettingsModal(true)}
          >
            <SlidersIcon size={15} />
            <span>Generation settings</span>
          </button>
        </div>
      </header>

      {/* ── Status Tabs matching Figma ── */}
      <div className="staff-tabs">
        {['All', ...TABS].map((t) => {
          const count = t === 'All'
            ? itineraries.length
            : itineraries.filter(i => i.status.toLowerCase() === t.toLowerCase()).length
          return (
            <button
              key={t}
              type="button"
              className={`staff-tab ${activeTab === t ? 'is-active' : ''}`}
              onClick={() => {
                setActiveTab(t)
                setPage(1)
              }}
            >
              <span>{t}</span>
              <span className="staff-tab__count">{count}</span>
            </button>
          )
        })}
      </div>

      {error && (
        <AlertBanner
          type="error"
          message={error}
          onRetry={() => loadItineraries(false)}
          onDismiss={() => setError('')}
        />
      )}

      {notice && (
        <AlertBanner
          type={notice.type}
          message={notice.message}
          onDismiss={() => setNotice(null)}
        />
      )}

      {/* ── Split Workspace matching Figma 2:27928 ── */}
      <div className="split-workspace" style={{ gridTemplateColumns: '360px minmax(0, 1fr)' }}>
        {/* Left Column: Proposal Queue + Search + Sort + Pagination + AI Log Context */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
          <div className="staff-card" style={{ padding: '1rem' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '0.75rem', paddingBottom: '0.5rem', borderBottom: '1px solid #eef2f3' }}>
              <strong style={{ fontSize: '0.9375rem', color: '#182126' }}>Proposal queue</strong>
              <span style={{ fontSize: '0.6875rem', color: '#66747b' }}>{filteredQueue.length} {activeTab === 'All' ? 'total' : `in ${activeTab}`}</span>
            </div>

            {/* Search & Sort Filters */}
            <div style={{ display: 'flex', flexDirection: 'column', gap: '0.5rem', marginBottom: '0.75rem' }}>
              <div className="staff-search-box" style={{ maxWidth: '100%', height: '34px' }}>
                <SearchIcon size={14} />
                <input
                  type="text"
                  placeholder="Search code, title, or guest…"
                  value={query}
                  onChange={(e) => {
                    setQuery(e.target.value)
                    setPage(1)
                  }}
                  style={{ fontSize: '0.75rem' }}
                />
              </div>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: '0.5rem' }}>
                <span style={{ fontSize: '0.6875rem', color: '#64748b' }}>Sort:</span>
                <select
                  className="btn-outline"
                  style={{ height: '30px', fontSize: '0.75rem', padding: '0 0.5rem', flex: 1 }}
                  value={sort}
                  onChange={(e) => {
                    setSort(e.target.value)
                    setPage(1)
                  }}
                >
                  <option value="newest">Newest first</option>
                  <option value="oldest">Oldest first</option>
                  <option value="cost-high">Cost: High to Low</option>
                  <option value="cost-low">Cost: Low to High</option>
                </select>
              </div>
            </div>

            {/* Proposal Cards List */}
            {loading ? (
              <LoadingState label="Loading queue…" />
            ) : pagedQueue.length > 0 ? (
              <div style={{ display: 'flex', flexDirection: 'column', gap: '0.5rem' }}>
                {pagedQueue.map((item) => {
                  const isSelected = selectedItinerary?.id === item.id
                  return (
                    <div
                      key={item.id}
                      onClick={() => setSelectedItinerary(item)}
                      style={{
                        padding: '0.75rem',
                        borderRadius: '8px',
                        border: isSelected ? '1.5px solid #267a55' : '1px solid #eef2f3',
                        background: isSelected ? '#f5fbf7' : '#ffffff',
                        cursor: 'pointer',
                        transition: 'all 0.15s ease'
                      }}
                    >
                      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '4px' }}>
                        <span style={{ fontSize: '0.6875rem', fontWeight: 700, color: '#66747b', letterSpacing: '0.5px' }}>
                          #{item.code}
                        </span>
                        <span className={`badge-pill ${item.status === 'Accepted' ? 'badge-green' : item.status === 'Proposed' ? 'badge-gold' : 'badge-gray'}`} style={{ fontSize: '0.625rem', padding: '1px 6px' }}>
                          <span className="badge-dot" /> {item.status}
                        </span>
                      </div>
                      <h4 style={{ margin: '0 0 2px 0', fontSize: '0.875rem', fontWeight: 600, color: '#182126' }}>
                        {item.title}
                      </h4>
                      <p style={{ margin: '0 0 6px 0', fontSize: '0.75rem', color: '#66747b' }}>
                        {item.customerName ?? 'Guest unavailable'} · {item.travellerCount != null ? `${item.travellerCount} travellers` : 'Traveller count unavailable'} · {item.durationDays != null ? `${item.durationDays} days` : 'Duration unavailable'}
                      </p>
                      <p style={{ margin: '0 0 6px 0', fontSize: '0.75rem', color: '#66747b' }}>
                        Created: {formatDate(item.createdAt)}
                      </p>
                      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', fontSize: '0.75rem' }}>
                        <strong style={{ color: '#182126' }}>{formatPrice(item.totalCost)}</strong>
                        <span style={{ color: '#267a55', fontWeight: 600, fontSize: '0.6875rem' }}>
                          {item.items.length === 0 ? 'No activities yet' : `${item.items.length} activities`}
                        </span>
                      </div>
                    </div>
                  )
                })}
              </div>
            ) : (
              <p style={{ margin: '1rem 0', fontSize: '0.8125rem', color: '#66747b', textAlign: 'center' }}>
                No itineraries match your filters.
              </p>
            )}

            {/* Pagination Controls */}
            {totalPages > 1 && (
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginTop: '0.75rem', paddingTop: '0.5rem', borderTop: '1px solid #eef2f3', fontSize: '0.75rem' }}>
                <button
                  type="button"
                  className="btn-outline"
                  style={{ height: '26px', padding: '0 8px', fontSize: '0.6875rem' }}
                  disabled={page <= 1}
                  onClick={() => setPage(p => p - 1)}
                >
                  ‹ Prev
                </button>
                <span style={{ color: '#64748b' }}>
                  {page} / {totalPages}
                </span>
                <button
                  type="button"
                  className="btn-outline"
                  style={{ height: '26px', padding: '0 8px', fontSize: '0.6875rem' }}
                  disabled={page >= totalPages}
                  onClick={() => setPage(p => p + 1)}
                >
                  Next ›
                </button>
              </div>
            )}
          </div>

          {/* AI Reasoning Trace Card matching Figma */}
          {selectedItinerary && (
            <div className="staff-card" style={{ padding: '1rem', background: '#f8fafc' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', marginBottom: '0.5rem' }}>
                <SparklesIcon size={16} />
                <strong style={{ fontSize: '0.8125rem', color: '#0f172a' }}>AI Reasoning trail</strong>
              </div>
              {(!selectedItinerary.tripRequestId || loadingAgentLogs || agentLogs.length === 0) && (
                <p style={{ margin: 0, fontSize: '0.75rem', color: '#475569', lineHeight: 1.45 }}>
                  {selectedItinerary.tripRequestId && loadingAgentLogs ? 'Loading agent logs…' : 'No agent log'}
                </p>
              )}
              {!!selectedItinerary.tripRequestId && !loadingAgentLogs && agentLogs.length > 0 && (
                <div style={{ marginTop: '0.75rem', paddingTop: '0.5rem', borderTop: '1px solid #e2e8f0', display: 'flex', flexDirection: 'column', gap: '4px' }}>
                  {agentLogs.slice(0, 3).map((log, i) => (
                    <div key={log.id || i} style={{ fontSize: '0.6875rem', color: '#64748b' }}>
                      <strong style={{ color: '#334155' }}>{log.agentName}:</strong> {log.stepName}
                    </div>
                  ))}
                </div>
              )}
            </div>
          )}
        </div>

        {/* Right Column: Detailed Day-by-Day Workspace matching Figma 2:27928 */}
        {selectedItinerary ? (
          <div className="staff-card" style={{ padding: '1.25rem', display: 'flex', flexDirection: 'column', gap: '1.25rem' }}>
            {/* Header info */}
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', flexWrap: 'wrap', gap: '0.75rem', paddingBottom: '1rem', borderBottom: '1px solid #eef2f3' }}>
              <div>
                <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', marginBottom: '4px' }}>
                  <span style={{ fontSize: '0.75rem', fontWeight: 800, color: '#66747b' }}>#{selectedItinerary.code}</span>
                  <span className={`badge-pill ${selectedItinerary.status === 'Accepted' ? 'badge-green' : selectedItinerary.status === 'Proposed' ? 'badge-gold' : 'badge-gray'}`}>
                    <span className="badge-dot" /> {selectedItinerary.status}
                  </span>
                </div>
                <h2 style={{ margin: 0, fontSize: '1.25rem', fontWeight: 700, color: '#182126' }}>
                  {selectedItinerary.title}
                </h2>
                <p style={{ margin: '4px 0 0 0', fontSize: '0.8125rem', color: '#66747b' }}>
                  <strong>{selectedItinerary.customerName ?? 'Guest unavailable'}</strong> · {selectedItinerary.travellerCount != null ? `${selectedItinerary.travellerCount} travellers` : 'Traveller count unavailable'} · {selectedItinerary.durationDays != null ? `${selectedItinerary.durationDays} days` : 'Duration unavailable'}
                </p>
                <p style={{ margin: '4px 0 0 0', fontSize: '0.8125rem', color: '#66747b' }}>
                  Created: {formatDate(selectedItinerary.createdAt)}
                </p>
              </div>

              <div style={{ textAlign: 'right' }}>
                <span style={{ fontSize: '0.6875rem', color: '#66747b', display: 'block' }}>TOTAL ESTIMATE</span>
                <strong style={{ fontSize: '1.375rem', color: '#182126' }}>{formatPrice(selectedItinerary.totalCost)}</strong>
              </div>
            </div>

            {/* Day columns horizontal container */}
            <div className="day-grid">
              {dayGroups.length === 0 && (
                <div>
                  <p>No activities yet</p>
                  <button type="button" className="btn-outline" onClick={() => openAddActivity(1)}>
                    <PlusIcon size={12} /> Add activity
                  </button>
                </div>
              )}
              {dayGroups.map((day) => (
                <div key={day.dayNumber} className="day-column">
                  <div className="day-column__head">
                    <div>
                      <h4 className="day-column__title">Day {day.dayNumber}</h4>
                      <span className="day-column__sub">{day.dateStr}</span>
                    </div>
                    <span className="badge-pill badge-blue">
                      <span className="badge-dot" /> {formatPrice(day.subtotal)}
                    </span>
                  </div>

                  {/* Activity cards inside day */}
                  <div style={{ display: 'flex', flexDirection: 'column', gap: '0.5rem' }}>
                    {day.items.map((act, actIdx) => (
                      <div key={act.id || actIdx} className="activity-card">
                        <div className="activity-num">{actIdx + 1}</div>
                        <div className="activity-info">
                          <span className="activity-time">
                            {act.startTime?.slice(0, 5) || 'Time unavailable'}
                          </span>
                          <p className="activity-name" style={{ margin: '2px 0' }}>
                            {act.tourName}
                          </p>
                        </div>
                        <span className="activity-cost">{formatPrice(act.priceAtSelection ?? 0)}</span>
                        <button
                          type="button"
                          style={{
                            background: 'none',
                            border: 'none',
                            color: '#94a3b8',
                            cursor: 'pointer',
                            padding: '0 2px',
                            fontSize: '0.8125rem'
                          }}
                          title="Remove activity"
                          disabled={removingItemId === act.id}
                          onClick={() => handleRemoveActivity(act.id)}
                        >
                          ✕
                        </button>
                      </div>
                    ))}
                  </div>

                  <button
                    type="button"
                    className="btn-outline"
                    style={{
                      height: '30px',
                      fontSize: '0.6875rem',
                      justifyContent: 'center',
                      borderStyle: 'dashed'
                    }}
                    onClick={() => openAddActivity(day.dayNumber)}
                  >
                    <PlusIcon size={12} />
                    <span>Add activity</span>
                  </button>
                </div>
              ))}
            </div>

            {/* Review Notes Textarea */}
            <div>
              <label style={{ display: 'block', fontSize: '0.6875rem', fontWeight: 800, color: '#475569', textTransform: 'uppercase', marginBottom: '0.35rem' }}>
                Review notes
              </label>
              <textarea
                rows={2}
                style={{
                  width: '100%',
                  padding: '0.5rem 0.75rem',
                  borderRadius: '6px',
                  border: '1px solid #c8d1d4',
                  fontSize: '0.8125rem',
                  boxSizing: 'border-box'
                }}
                value={reviewNote}
                onChange={(e) => setReviewNote(e.target.value)}
              />
            </div>

            {/* Decision Gate Actions matching Figma 2:27928 */}
            {!['Discarded', 'Accepted'].includes(selectedItinerary.status) && (
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: '0.75rem', flexWrap: 'wrap', paddingTop: '0.5rem', borderTop: '1px solid #eef2f3' }}>
              <button
                type="button"
                className="btn-danger-soft"
                disabled={busyAction}
                onClick={() => handleStatusChange('Discarded')}
              >
                <TrashIcon size={14} />
                <span>Discard</span>
              </button>

              <div style={{ display: 'flex', gap: '0.5rem' }}>
                {selectedItinerary.status === 'Proposed' && (
                  <button
                    type="button"
                    className="btn-outline"
                    disabled={busyAction}
                    onClick={() => handleStatusChange('Draft')}
                  >
                    <RotateCcwIcon size={14} />
                    <span>Send for replanning</span>
                  </button>
                )}
                <button
                  type="button"
                  className="btn-gold"
                  disabled={busyAction}
                  onClick={() => handleStatusChange('Accepted')}
                >
                  <CheckIcon size={14} />
                  <span>Accept itinerary</span>
                </button>
              </div>
            </div>
            )}
          </div>
        ) : (
          <div className="staff-card" style={{ padding: '3rem', textAlign: 'center', color: '#66747b' }}>
            <p>Select a proposal from the queue to review and edit activities.</p>
          </div>
        )}
      </div>

      {activityDay !== null && (
        <div role="dialog" aria-modal="true" aria-labelledby="add-activity-title"
          style={{ position: 'fixed', inset: 0, backgroundColor: 'rgba(15, 23, 27, 0.6)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 100, padding: '1rem' }}>
          <form className="staff-card" onSubmit={handleAddActivity}
            style={{ width: '100%', maxWidth: '440px', padding: '1.5rem', display: 'grid', gap: '1rem', maxHeight: '90vh', overflowY: 'auto' }}>
            <h3 id="add-activity-title" style={{ margin: 0 }}>Add activity</h3>
            {error && <AlertBanner type="error" message={error} onDismiss={() => setError('')} />}
            <label>
              Active tour
              <select required className="btn-outline" style={{ width: '100%' }} value={activityTourId}
                disabled={loadingTours || addingActivity} onChange={event => setActivityTourId(event.target.value)}>
                <option value="">{loadingTours ? 'Loading tours…' : 'Select a tour'}</option>
                {activeTours.map(tour => <option key={tour.id} value={tour.id}>{tour.name} · {tour.durationHours} hrs · {tour.defaultStartTime?.slice(0, 5)}</option>)}
              </select>
            </label>
            {!loadingTours && activeTours.length === 0 && <p>No active tours available.</p>}
            <label>
              Day number
              <input required type="number" min="1" max={selectedItinerary?.durationDays ?? undefined} step="1"
                className="staff-search-box" style={{ width: '100%' }} value={activityDay} disabled={addingActivity}
                onChange={event => setActivityDay(event.target.value)} />
            </label>
            <p style={{ margin: 0, fontSize: '0.8125rem' }}>Uses the tour's default start time and duration.</p>
            <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '0.5rem' }}>
              <button type="button" className="btn-outline" disabled={addingActivity} onClick={() => setActivityDay(null)}>Cancel</button>
              <button type="submit" className="btn-gold" disabled={loadingTours || addingActivity || !activityTourId}>
                {addingActivity ? 'Adding…' : 'Add activity'}
              </button>
            </div>
          </form>
        </div>
      )}

      {/* ── Generation Settings Modal ── */}
      {showSettingsModal && (
        <div
          style={{
            position: 'fixed',
            inset: 0,
            backgroundColor: 'rgba(15, 23, 27, 0.6)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            zIndex: 100,
            padding: '1rem'
          }}
        >
          <div className="staff-card" style={{ width: '100%', maxWidth: '440px', padding: '1.75rem' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '1.25rem' }}>
              <h3 style={{ margin: 0, fontSize: '1.125rem', fontWeight: 700, color: '#182126' }}>
                AI Generation Settings
              </h3>
              <button
                type="button"
                className="btn-outline"
                style={{ height: '30px', padding: '0 0.5rem' }}
                onClick={() => setShowSettingsModal(false)}
              >
                ✕
              </button>
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem', fontSize: '0.8125rem' }}>
              <div>
                <label style={{ display: 'block', fontWeight: 700, marginBottom: '0.35rem' }}>Coordinator Model</label>
                <select className="btn-outline" style={{ width: '100%', height: '38px', padding: '0 0.75rem' }} defaultValue="gemini-2.0-flash">
                  <option value="gemini-2.0-flash">Gemini 2.0 Flash (Fast & Balanced)</option>
                  <option value="gemini-1.5-pro">Gemini 1.5 Pro (Deep Reasoning)</option>
                </select>
              </div>

              <div>
                <label style={{ display: 'block', fontWeight: 700, marginBottom: '0.35rem' }}>Route Variant Breadth</label>
                <input type="range" min="1" max="5" defaultValue="3" style={{ width: '100%' }} />
                <span style={{ fontSize: '0.75rem', color: '#66747b' }}>Generates 3 candidates per traveller request</span>
              </div>

              <div>
                <label style={{ display: 'block', fontWeight: 700, marginBottom: '0.35rem' }}>Maximum Travel Time per Day</label>
                <select className="btn-outline" style={{ width: '100%', height: '38px', padding: '0 0.75rem' }} defaultValue="4">
                  <option value="3">3 hours max</option>
                  <option value="4">4 hours max (recommended for Sri Lanka)</option>
                  <option value="6">6 hours max</option>
                </select>
              </div>

              <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '0.5rem', marginTop: '0.5rem' }}>
                <button type="button" className="btn-outline" onClick={() => setShowSettingsModal(false)}>Close</button>
                <button type="button" className="btn-gold" onClick={() => setShowSettingsModal(false)}>Save parameters</button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
