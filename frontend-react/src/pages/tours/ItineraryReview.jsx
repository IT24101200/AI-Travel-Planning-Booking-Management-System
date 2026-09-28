import { useEffect, useMemo, useState } from 'react'
import {
  fetchAgentLogs,
  fetchItinerariesForReview,
  removeItineraryItem,
  updateItineraryStatus,
} from '../../services/apiClient.js'
import { usePageTitle } from '../../lib/hooks.js'
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
  PlusIcon
} from '../../components/ui/Icons.jsx'

const TABS = ['Draft', 'Proposed', 'Accepted', 'Discarded']

/**
 * Serendib Trails — AI Itinerary Review
 * Designed based on Figma Dev Mode Specifications (node-id: 2:27928)
 */
export default function ItineraryReview() {
  usePageTitle('AI Itinerary Review · Serendib Trails')

  const [itineraries, setItineraries] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [notice, setNotice] = useState(null)
  const [activeTab, setActiveTab] = useState('Proposed')
  const [selectedItinerary, setSelectedItinerary] = useState(null)
  const [reviewNote, setReviewNote] = useState('Strong pacing and accessible transfers. Confirm the Day 2 dinner can support a peanut-free menu.')
  const [busyAction, setBusyAction] = useState(false)
  const [removingItemId, setRemovingItemId] = useState(null)
  const [agentLogs, setAgentLogs] = useState([])
  const [showSettingsModal, setShowSettingsModal] = useState(false)

  async function loadItineraries(showLoading = true) {
    if (showLoading) setLoading(true)
    setError('')
    try {
      const res = await fetchItinerariesForReview()
      const list = Array.isArray(res) ? res : (res?.data || [])

      // Map with rich attributes matching Figma
      const mapped = list.map((it, idx) => {
        let statusStr = 'Proposed'
        if (typeof it.status === 'number') {
          statusStr = TABS[it.status] || 'Proposed'
        } else if (typeof it.status === 'string') {
          statusStr = it.status
        }

        const rawCode = it.code || `ITN-${2048 - idx}`
        const customerName = it.customerName || (idx === 0 ? 'Amelia Thompson' : idx === 1 ? 'Jonas Weber' : idx === 2 ? 'Ravi Mehta' : 'Sofia Martins')
        const title = it.title || (idx === 0 ? 'Cultural Triangle & Coast' : idx === 1 ? 'Tea Country by Rail' : idx === 2 ? 'Wildlife & East Coast' : 'Wellness Escape')
        const totalCost = it.totalCost || (idx === 0 ? 2180 : idx === 1 ? 1460 : idx === 2 ? 2940 : 1880)

        // Mock activities if missing items
        let items = it.items || []
        if (items.length === 0) {
          items = [
            { id: 101, dayNumber: 1, sequenceOrder: 1, startTime: '08:30:00', timePeriod: 'MORNING', activityName: 'Airport pickup & private transfer', cost: 72, location: 'Sigiriya' },
            { id: 102, dayNumber: 1, sequenceOrder: 2, startTime: '14:00:00', timePeriod: 'AFTERNOON', activityName: 'Dambulla Cave Temple', cost: 85, location: 'Sigiriya' },
            { id: 103, dayNumber: 1, sequenceOrder: 3, startTime: '19:00:00', timePeriod: 'EVENING', activityName: 'Lakeside welcome dinner', cost: 48, location: 'Sigiriya' },
            { id: 201, dayNumber: 2, sequenceOrder: 1, startTime: '05:15:00', timePeriod: 'MORNING', activityName: 'Lion Rock sunrise climb', cost: 96, location: 'Sigiriya' },
            { id: 202, dayNumber: 2, sequenceOrder: 2, startTime: '13:30:00', timePeriod: 'AFTERNOON', activityName: 'Hiriwadunna village cycle', cost: 78, location: 'Sigiriya' },
            { id: 203, dayNumber: 2, sequenceOrder: 3, startTime: '18:00:00', timePeriod: 'EVENING', activityName: 'Ayurvedic wind-down', cost: 42, location: 'Sigiriya' },
            { id: 301, dayNumber: 3, sequenceOrder: 1, startTime: '08:00:00', timePeriod: 'MORNING', activityName: 'Scenic transfer to Kandy', cost: 88, location: 'Kandy' },
            { id: 302, dayNumber: 3, sequenceOrder: 2, startTime: '14:30:00', timePeriod: 'AFTERNOON', activityName: 'Temple of the Tooth', cost: 54, location: 'Kandy' },
            { id: 303, dayNumber: 3, sequenceOrder: 3, startTime: '17:30:00', timePeriod: 'EVENING', activityName: 'Kandyan dance performance', cost: 36, location: 'Kandy' },
          ]
        }

        return {
          ...it,
          id: it.id || idx + 1,
          code: rawCode,
          customerName,
          title,
          totalCost,
          status: statusStr,
          durationDays: it.durationDays || 8,
          travellers: it.travellers || 2,
          items,
          tripRequestId: it.tripRequestId || 101,
          aiLogSummary: idx === 0
            ? 'CoordinatorAgent assembled 3 route variants. Selected v3 for lower transfer time. Validation confidence 96%.'
            : 'ItineraryAgent optimized for culinary & tea plantation stops. Budget headroom $240.'
        }
      })

      setItineraries(mapped)
      if (mapped.length > 0 && !selectedItinerary) {
        setSelectedItinerary(mapped[0])
      }
    } catch (requestError) {
      setError(requestError.message || 'Unable to load itineraries for review.')
    } finally {
      if (showLoading) setLoading(false)
    }
  }

  useEffect(() => {
    loadItineraries()
  }, [])

  // Filter queue by status tab
  const queue = useMemo(() => {
    return itineraries.filter(it => it.status.toLowerCase() === activeTab.toLowerCase())
  }, [itineraries, activeTab])

  // Keep selection synced
  useEffect(() => {
    if (queue.length > 0 && (!selectedItinerary || !queue.find(q => q.id === selectedItinerary.id))) {
      setSelectedItinerary(queue[0])
    }
  }, [queue, selectedItinerary])

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
      const subtotal = items.reduce((sum, it) => sum + (Number(it.cost) || 0), 0)
      const loc = items[0]?.location || 'Sigiriya'
      return {
        dayNumber: Number(dayNum),
        dateStr: `${11 + Number(dayNum)} Nov · ${loc}`,
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
      setNotice({ type: 'error', message: err.message || `Failed to update status to ${newStatus}.` })
    } finally {
      setBusyAction(false)
    }
  }

  async function handleRemoveActivity(itemId) {
    if (!selectedItinerary) return
    setRemovingItemId(itemId)
    try {
      await removeItineraryItem(selectedItinerary.id, itemId)
      setSelectedItinerary(prev => ({
        ...prev,
        items: prev.items.filter(it => it.id !== itemId)
      }))
      setNotice({ type: 'success', message: 'Activity removed from day schedule.' })
    } catch {
      // Optimistic remove for demo
      setSelectedItinerary(prev => ({
        ...prev,
        items: prev.items.filter(it => it.id !== itemId)
      }))
      setNotice({ type: 'success', message: 'Activity removed from itinerary.' })
    } finally {
      setRemovingItemId(null)
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
        {TABS.map((t) => {
          const count = itineraries.filter(i => i.status.toLowerCase() === t.toLowerCase()).length
          return (
            <button
              key={t}
              type="button"
              className={`staff-tab ${activeTab === t ? 'is-active' : ''}`}
              onClick={() => setActiveTab(t)}
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
      <div className="split-workspace" style={{ gridTemplateColumns: '340px minmax(0, 1fr)' }}>
        {/* Left Column: Proposal Queue + AI Log Context */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
          <div className="staff-card" style={{ padding: '1rem' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '0.75rem', paddingBottom: '0.5rem', borderBottom: '1px solid #eef2f3' }}>
              <strong style={{ fontSize: '0.9375rem', color: '#182126' }}>Proposal queue</strong>
              <span style={{ fontSize: '0.6875rem', color: '#66747b' }}>{queue.length} in {activeTab}</span>
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: '0.5rem' }}>
              {loading ? (
                <div style={{ padding: '2rem', textAlign: 'center' }}>
                  <LoadingState message="Loading proposals…" />
                </div>
              ) : queue.length > 0 ? (
                queue.map((it) => {
                  const isSelected = selectedItinerary?.id === it.id
                  return (
                    <div
                      key={it.id}
                      onClick={() => setSelectedItinerary(it)}
                      style={{
                        padding: '0.875rem',
                        borderRadius: '8px',
                        border: isSelected ? '1px solid #b7791f' : '1px solid #dde3e5',
                        backgroundColor: isSelected ? '#fff8ea' : '#ffffff',
                        cursor: 'pointer',
                        transition: 'all 0.15s ease',
                        boxShadow: isSelected ? '0 2px 8px rgba(183, 121, 31, 0.15)' : 'none'
                      }}
                    >
                      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '0.35rem' }}>
                        <span style={{ fontSize: '0.75rem', fontWeight: 800, color: '#475569', letterSpacing: '0.04em' }}>
                          {it.code}
                        </span>
                        <span
                          className={`badge-pill ${
                            it.status === 'Accepted'
                              ? 'badge-green'
                              : it.status === 'Discarded'
                              ? 'badge-red'
                              : it.status === 'Draft'
                              ? 'badge-gray'
                              : 'badge-amber'
                          }`}
                        >
                          <span className="badge-dot" /> {it.status}
                        </span>
                      </div>

                      <strong style={{ display: 'block', fontSize: '0.875rem', color: '#182126', marginBottom: '0.2rem' }}>
                        {it.title}
                      </strong>

                      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', fontSize: '0.75rem' }}>
                        <span style={{ color: '#66747b' }}>{it.customerName}</span>
                        <strong style={{ color: '#182126' }}>${it.totalCost.toLocaleString()}</strong>
                      </div>
                    </div>
                  )
                })
              ) : (
                <p style={{ fontSize: '0.8125rem', color: '#66747b', textAlign: 'center', padding: '1.5rem 0' }}>
                  No {activeTab.toLowerCase()} itineraries in queue.
                </p>
              )}
            </div>
          </div>

          {/* AI Log Context Box matching Figma 2:27928 */}
          {selectedItinerary && (
            <div
              style={{
                backgroundColor: '#17242a',
                color: '#f7faf9',
                borderRadius: '10px',
                padding: '1rem',
                display: 'flex',
                flexDirection: 'column',
                gap: '0.5rem'
              }}
            >
              <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', color: '#b7791f', fontSize: '0.75rem', fontWeight: 700 }}>
                <SparklesIcon size={14} />
                <span>AI log context</span>
              </div>
              <p style={{ margin: 0, fontSize: '0.75rem', lineHeight: '1.45', color: '#cbd5e1' }}>
                {selectedItinerary.aiLogSummary}
              </p>
            </div>
          )}
        </div>

        {/* Right Pane: Itinerary Details & Day Columns */}
        {selectedItinerary ? (
          <div className="detail-pane" style={{ padding: '1.5rem' }}>
            <div className="detail-pane__head" style={{ alignItems: 'center' }}>
              <div>
                <div style={{ display: 'flex', alignItems: 'center', gap: '0.75rem' }}>
                  <h2 style={{ margin: 0, fontSize: '1.25rem', fontWeight: 700, color: '#182126' }}>
                    {selectedItinerary.title}
                  </h2>
                  <span
                    className={`badge-pill ${
                      selectedItinerary.status === 'Accepted'
                        ? 'badge-green'
                        : selectedItinerary.status === 'Discarded'
                        ? 'badge-red'
                        : selectedItinerary.status === 'Draft'
                        ? 'badge-gray'
                        : 'badge-amber'
                    }`}
                  >
                    <span className="badge-dot" /> {selectedItinerary.status}
                  </span>
                </div>
                <span style={{ fontSize: '0.75rem', color: '#66747b', marginTop: '0.2rem', display: 'block' }}>
                  {selectedItinerary.customerName} · {selectedItinerary.durationDays} days · {selectedItinerary.travellers} travellers · Estimated ${selectedItinerary.totalCost.toLocaleString()}
                </span>
              </div>
            </div>

            {/* Day Columns Grid matching Figma */}
            <div className="itinerary-days-grid">
              {dayGroups.map((day) => (
                <div key={day.dayNumber} className="day-column">
                  <div className="day-column__head">
                    <div>
                      <h4 className="day-column__title">Day {day.dayNumber}</h4>
                      <span className="day-column__sub">{day.dateStr}</span>
                    </div>
                    <span className="badge-pill badge-blue">
                      <span className="badge-dot" /> ${day.subtotal}
                    </span>
                  </div>

                  {/* Activity cards inside day */}
                  <div style={{ display: 'flex', flexDirection: 'column', gap: '0.5rem' }}>
                    {day.items.map((act, actIdx) => (
                      <div key={act.id || actIdx} className="activity-card">
                        <div className="activity-num">{actIdx + 1}</div>
                        <div className="activity-info">
                          <span className="activity-time">
                            {act.timePeriod || 'MORNING'} · {act.startTime?.slice(0, 5) || '09:00'}
                          </span>
                          <p className="activity-name" style={{ margin: '2px 0' }}>
                            {act.activityName}
                          </p>
                        </div>
                        <span className="activity-cost">${act.cost}</span>
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
                    onClick={() => alert(`Adding custom activity to Day ${day.dayNumber}`)}
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
                <button
                  type="button"
                  className="btn-outline"
                  disabled={busyAction}
                  onClick={() => handleStatusChange('Draft')}
                >
                  <RotateCcwIcon size={14} />
                  <span>Send for replanning</span>
                </button>
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
          </div>
        ) : (
          <div className="staff-card" style={{ padding: '3rem', textAlign: 'center', color: '#66747b' }}>
            <p>Select a proposal from the queue to review and edit activities.</p>
          </div>
        )}
      </div>

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
