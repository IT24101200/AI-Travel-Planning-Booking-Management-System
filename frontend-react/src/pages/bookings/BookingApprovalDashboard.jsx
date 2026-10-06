import { useEffect, useMemo, useState } from 'react'
import { decideApproval, fetchAgentLogs, fetchBookings } from '../../services/apiClient.js'
import { usePageTitle } from '../../lib/hooks.js'
import { formatPrice } from '../../lib/formatPrice.js'
import { AlertBanner } from '../../components/ui/AlertBanner.jsx'
import { useResponsive } from '../../lib/useResponsive.js'
import {
  DownloadIcon,
  RefreshIcon,
  CheckIcon,
  RotateCcwIcon,
} from '../../components/ui/Icons.jsx'

const STATUS_NAMES = ['Draft', 'AwaitingApproval', 'Confirmed', 'Rejected', 'Cancelled', 'Completed']


/**
 * Student D â€” Booking Approval Dashboard
 * Designed according to Figma Dev Mode Specifications (node-id: 2:26639)
 * Features:
 * - Master review queue with status tabs & SLA pill
 * - Detailed inspector with customer card & avatar
 * - Multi-agent AI reasoning trail (Coordinator, Itinerary, Booking, Validation)
 * - Human decision gate (Approve, Reject, Revision) with audit logging
 */
export default function BookingApprovalDashboard() {
  const { isMobile } = useResponsive()
  const [rows, setRows] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [filter, setFilter] = useState('All')
  const [page, setPage] = useState(1)
  const [open, setOpen] = useState(null)
  const [mobileTab, setMobileTab] = useState('queue') // 'queue' | 'detail' on mobile
  const [comment, setComment] = useState('')
  const [note, setNote] = useState('')
  const [agentLogs, setAgentLogs] = useState([])
  const [logsLoading, setLogsLoading] = useState(false)
  usePageTitle('Approvals Â· Staff')

  async function loadBookings(cancelled = false) {
    setLoading(true)
    setError(null)
    try {
      const res = await fetchBookings()
      const live = Array.isArray(res) ? res : (res?.data || [])
      if (!cancelled) {
        const mapped = live.map((b) => {
          const statusStr = typeof b.status === 'number'
            ? (STATUS_NAMES[b.status] || 'Status unavailable')
            : (b.status || 'Status unavailable')
          return {
            id: b.id,
            reference: b.bookingReference || 'Reference unavailable',
            tripRequestId: b.tripRequestId,
            customer: b.customerName || 'Customer unavailable',
            total: b.totalCost ?? null,
            currency: b.currency || null,
            requested: b.createdAt ? b.createdAt.split('T')[0] : 'Date unavailable',
            status: statusStr,
            agentLogs: b.agentLogs || [],
          }
        })
        setRows(mapped)
        if (mapped.length > 0) {
          setOpen((prev) => (mapped.some((m) => m.id === prev) ? prev : mapped[0].id))
        }
      }
    } catch (err) {
      if (!cancelled) {
        setError(err.response?.data?.message || err.message || 'Failed to load bookings from database.')
      }
    } finally {
      if (!cancelled) setLoading(false)
    }
  }

  useEffect(() => {
    let cancelled = false
    // This starts an async API load; its state updates occur after the request.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    loadBookings(cancelled)
    return () => { cancelled = true }
  }, [])

  const view = useMemo(
    () => (filter === 'All' ? rows : rows.filter((r) => r.status.toLowerCase() === filter.toLowerCase())),
    [rows, filter],
  )

  const pageSize = 5
  const pages = Math.max(1, Math.ceil(view.length / pageSize))
  const pageRows = view.slice((page - 1) * pageSize, page * pageSize)
  const active = rows.find((r) => r.id === open) ?? rows[0]

  // Load autonomous AI agent execution logs for the selected booking's trip request
  useEffect(() => {
    if (active?.agentLogs && active.agentLogs.length > 0) {
      // Agent logs are copied into the panel's local view when the selection changes.
      // eslint-disable-next-line react-hooks/set-state-in-effect
      setAgentLogs(active.agentLogs)
      return
    }

    if (!active?.tripRequestId) {
      setAgentLogs([])
      return
    }

    let cancelled = false
    setLogsLoading(true)
    fetchAgentLogs(active.tripRequestId)
      .then((res) => {
        if (!cancelled) {
          const list = Array.isArray(res) ? res : (res?.data || [])
          setAgentLogs(list)
        }
      })
      .catch(() => {
        if (!cancelled) setAgentLogs([])
      })
      .finally(() => {
        if (!cancelled) setLogsLoading(false)
      })

    return () => { cancelled = true }
  }, [active?.id, active?.tripRequestId, active?.agentLogs])

  async function decide(decision) {
    if (!active) return

    try {
      await decideApproval(
        active.id,
        decision,
        comment.trim() || `Agent decided: ${decision}`,
      )
      setNote(`${active.reference} recorded as "${decision}" in database audit trail.`)
      setComment('')
      await loadBookings()
    } catch (err) {
      setNote(`Failed to record decision: ${err.response?.data?.message || err.message}`)
    }
  }

  function onFilterChange(s) {
    setFilter(s)
    setPage(1)
  }

  function getBadgeClass(status) {
    switch (status?.toLowerCase()) {
      case 'awaitingapproval':
      case 'pending':
        return 'badge-amber'
      case 'confirmed':
      case 'approved':
      case 'active':
        return 'badge-green'
      case 'rejected':
      case 'failed':
        return 'badge-red'
      default:
        return 'badge-gray'
    }
  }

  const awaitingCount = useMemo(() => rows.filter((r) => r.status.toLowerCase() === 'awaitingapproval').length, [rows])

  const customerInitials = (() => {
    if (!active?.customer) return 'CU'
    const parts = active.customer.trim().split(/\s+/)
    if (parts.length >= 2) return `${parts[0][0]}${parts[1][0]}`.toUpperCase()
    return active.customer.substring(0, 2).toUpperCase()
  })()

  // Export queue handler
  function exportQueue() {
    const jsonStr = `data:text/json;charset=utf-8,${encodeURIComponent(JSON.stringify(view, null, 2))}`
    const dlAnchor = document.createElement('a')
    dlAnchor.setAttribute('href', jsonStr)
    dlAnchor.setAttribute('download', `booking_approvals_${filter.toLowerCase()}.json`)
    dlAnchor.click()
    setNote(`Exported ${view.length} booking records.`)
  }

  return (
    <div className="staff-page">
      {/* Page Header */}
      <header className="staff-page__head">
        <div className="staff-page__title-block">
          <p className="staff-page__eyebrow">Operations / Booking approvals</p>
          <h1 className="staff-page__title">Booking approvals</h1>
          <p className="staff-page__subtitle">Review AI-assisted booking proposals before inventory is confirmed.</p>
        </div>
        <div className="staff-page__actions">
          <button type="button" className="btn-outline" onClick={exportQueue}>
            <DownloadIcon size={15} />
            <span>Export queue</span>
          </button>
          <button type="button" className="btn-gold" onClick={() => loadBookings(false)} disabled={loading}>
            <RefreshIcon size={15} />
            <span>{loading ? 'Refreshingâ€¦' : 'Refresh'}</span>
          </button>
        </div>
      </header>

      {/* Status Alerts */}
      {error && (
        <AlertBanner
          type="error"
          message={error}
          onRetry={() => loadBookings(false)}
          onDismiss={() => setError(null)}
        />
      )}
      {note && (
        <AlertBanner
          type="success"
          message={note}
          onDismiss={() => setNote('')}
        />
      )}

      {/* Filter Tabs matching Figma */}
      <div className="staff-tabs">
        {['All', 'AwaitingApproval', 'Confirmed', 'Rejected', 'Cancelled'].map((s) => (
          <button
            key={s}
            type="button"
            className={`staff-tab${filter === s ? ' is-active' : ''}`}
            onClick={() => onFilterChange(s)}
          >
            {s}
            {s === 'AwaitingApproval' && awaitingCount > 0 && (
              <span className="staff-tab__count">{awaitingCount}</span>
            )}
          </button>
        ))}
      </div>

      {/* Mobile Tab Switcher */}
      {isMobile && (
        <div style={{ display: 'flex', gap: '0.5rem', width: '100%' }}>
          <button
            type="button"
            className={`staff-tab${mobileTab === 'queue' ? ' is-active' : ''}`}
            style={{ flex: 1, justifyContent: 'center' }}
            onClick={() => setMobileTab('queue')}
          >
            Queue ({view.length})
          </button>
          <button
            type="button"
            className={`staff-tab${mobileTab === 'detail' ? ' is-active' : ''}`}
            style={{ flex: 1, justifyContent: 'center' }}
            onClick={() => setMobileTab('detail')}
          >
            Review ({active?.reference || 'None'})
          </button>
        </div>
      )}

      {/* Split Master Detail Workspace */}
      <div className="split-workspace">
        {/* Left Side: Booking Queue Table */}
        {(!isMobile || mobileTab === 'queue') && (
          <div className="staff-card">
            <div className="staff-card__head">
              <div>
                <h3 className="staff-card__title">Review queue</h3>
                <p className="staff-card__sub">{awaitingCount} bookings awaiting action</p>
              </div>
              <span className="badge-pill badge-amber">
                <span className="badge-dot" />
                <span>SLA 01:42</span>
              </span>
            </div>

            <div className="staff-table-wrap">
              <table className="staff-table">
                <thead>
                  <tr>
                    <th style={{ width: '130px' }}>Booking reference</th>
                    <th>Customer name</th>
                    <th style={{ textAlign: 'right', width: '130px' }}>Total amount</th>
                    <th style={{ width: '110px' }}>Created date</th>
                    <th style={{ width: '140px' }}>Status</th>
                  </tr>
                </thead>
                <tbody>
                  {loading ? (
                    <tr>
                      <td colSpan={5} style={{ textAlign: 'center', padding: '2rem', color: '#66747b' }}>
                        Loading bookings from databaseâ€¦
                      </td>
                    </tr>
                  ) : pageRows.length > 0 ? (
                    pageRows.map((r) => (
                      <tr
                        key={r.id}
                        onClick={() => {
                          setOpen(r.id)
                          if (isMobile) setMobileTab('detail')
                        }}
                        className={open === r.id ? 'is-selected' : ''}
                        style={{ cursor: 'pointer' }}
                      >
                        <td>
                          <b style={{ color: '#182126' }}>{r.reference}</b>
                        </td>
                        <td>{r.customer}</td>
                        <td style={{ textAlign: 'right', fontWeight: 700 }}>
                          {formatPrice(r.total, r.currency)}
                        </td>
                        <td style={{ color: '#66747b', fontSize: '0.75rem' }}>{r.requested}</td>
                        <td>
                          <span className={`badge-pill ${getBadgeClass(r.status)}`}>
                            <span className="badge-dot" />
                            <span>{r.status === 'AwaitingApproval' ? 'Awaiting approval' : r.status}</span>
                          </span>
                        </td>
                      </tr>
                    ))
                  ) : (
                    <tr>
                      <td colSpan={5} style={{ textAlign: 'center', padding: '2rem', color: '#66747b' }}>
                        No bookings match the selected filter.
                      </td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>

            <div className="staff-pagination">
              <span>
                Showing {view.length === 0 ? 0 : (page - 1) * pageSize + 1}â€“{Math.min(page * pageSize, view.length)} of {view.length} bookings
              </span>
              <div className="staff-pagination__btns">
                <button
                  type="button"
                  className="staff-page-btn"
                  disabled={page <= 1}
                  onClick={() => setPage((p) => p - 1)}
                >
                  Previous
                </button>
                {Array.from({ length: pages }).map((_, i) => (
                  <button
                    key={i + 1}
                    type="button"
                    className={`staff-page-btn${page === i + 1 ? ' is-active' : ''}`}
                    onClick={() => setPage(i + 1)}
                  >
                    {i + 1}
                  </button>
                ))}
                <button
                  type="button"
                  className="staff-page-btn"
                  disabled={page >= pages}
                  onClick={() => setPage((p) => p + 1)}
                >
                  Next
                </button>
              </div>
            </div>
          </div>
        )}

        {/* Right Side: Detailed Decision & AI Audit Inspector */}
        {(!isMobile || mobileTab === 'detail') && active && (
          <div className="detail-pane">
            {/* Header */}
            <div className="detail-pane__head">
              <div>
                <h3 style={{ margin: 0, fontSize: '1.125rem', color: '#182126', fontWeight: 700 }}>
                  {active.reference}
                </h3>
                <p style={{ margin: '2px 0 0', fontSize: '0.75rem', color: '#66747b' }}>
                  Created {active.requested} Â· 09:42 LKT
                </p>
              </div>
              <span className={`badge-pill ${getBadgeClass(active.status)}`}>
                <span className="badge-dot" />
                <span>{active.status === 'AwaitingApproval' ? 'Awaiting approval' : active.status}</span>
              </span>
            </div>

            {/* Customer Summary Card */}
            <div
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: '0.75rem',
                backgroundColor: '#f8fafa',
                padding: '0.875rem',
                borderRadius: '8px',
                border: '1px solid #dde3e5',
              }}
            >
              <div
                style={{
                  width: '38px',
                  height: '38px',
                  borderRadius: '50%',
                  backgroundColor: '#e0f2fe',
                  color: '#0369a1',
                  fontWeight: 800,
                  fontSize: '0.8125rem',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  flexShrink: 0,
                }}
              >
                {customerInitials}
              </div>
              <div style={{ flex: 1, minWidth: 0 }}>
                <p style={{ margin: 0, fontWeight: 700, fontSize: '0.875rem', color: '#182126' }}>
                  {active.customer} Â· 2 travellers
                </p>
                <p style={{ margin: '2px 0 0', fontSize: '0.75rem', color: '#66747b' }}>
                  Total Package: {formatPrice(active.total, active.currency)}
                </p>
              </div>
            </div>

            {/* AI Reasoning Trail matching Figma */}
            <div>
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '0.75rem' }}>
                <h4 style={{ margin: 0, fontSize: '0.8125rem', fontWeight: 700, color: '#182126' }}>
                  AI reasoning trail
                </h4>
                <span style={{ fontSize: '0.6875rem', color: '#66747b' }}>
                  {agentLogs.length > 0 ? `${agentLogs.length} log entries` : 'No recorded agent logs'}
                </span>
              </div>

              {logsLoading ? (
                <p style={{ fontSize: '0.75rem', color: '#66747b' }}>Loading agent reasoning traceâ€¦</p>
              ) : agentLogs.length > 0 ? (
                  <div style={{ display: 'flex', flexDirection: 'column', gap: '0.75rem' }}>
                    {agentLogs.map((log, index) => (
                      <div key={log.id || `${log.agentName || 'agent'}-${log.timestamp || index}`} style={{ display: 'flex', gap: '0.625rem', alignItems: 'flex-start' }}>
                        <div
                          style={{
                            width: '22px',
                            height: '22px',
                            borderRadius: '50%',
                            backgroundColor: log.status?.toLowerCase() === 'failed' ? '#dc2626' : '#166b4f',
                            color: '#f7faf9',
                            fontSize: '0.6875rem',
                            fontWeight: 700,
                            display: 'flex',
                            alignItems: 'center',
                            justifyContent: 'center',
                            flexShrink: 0,
                            marginTop: '1px',
                          }}
                        >
                          {index + 1}
                        </div>
                        <div style={{ flex: 1 }}>
                          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: '0.5rem' }}>
                            <span style={{ fontSize: '0.75rem', fontWeight: 700, color: '#182126' }}>{log.agentName || 'Agent unavailable'}</span>
                            <span style={{ fontSize: '0.6875rem', fontWeight: 600, color: log.status?.toLowerCase() === 'failed' ? '#b91c1c' : '#15803d' }}>{log.status || 'Status unavailable'}</span>
                          </div>
                          <p style={{ margin: '2px 0 0', fontSize: '0.6875rem', color: '#66747b', lineHeight: 1.35 }}>
                            {log.stepName || log.output || 'No step details recorded.'}
                          </p>
                          {log.timestamp && (
                            <p style={{ margin: '2px 0 0', fontSize: '0.625rem', color: '#8a969b' }}>
                              {new Date(log.timestamp).toLocaleString()}
                            </p>
                          )}
                        </div>
                      </div>
                    ))}
                  </div>
                ) : (
                  <p style={{ fontSize: '0.75rem', color: '#66747b' }}>No agent logs recorded for this booking.</p>
                )}
            </div>

            {/* Audit Comment Form & Decision Controls */}
            {active.status.toLowerCase() === 'awaitingapproval' ? (
              <>
                <div style={{ display: 'flex', flexDirection: 'column', gap: '0.35rem', marginTop: '0.25rem' }}>
                  <label style={{ fontSize: '0.75rem', fontWeight: 700, color: '#182126' }}>
                    Audit comment *
                  </label>
                  <textarea
                    style={{
                      width: '100%',
                      minHeight: '68px',
                      padding: '0.625rem',
                      borderRadius: '6px',
                      border: '1px solid #c8d1d4',
                      fontSize: '0.75rem',
                      fontFamily: 'inherit',
                      boxSizing: 'border-box',
                      resize: 'vertical',
                      outline: 'none',
                    }}
                    placeholder="Required: explain your decision for the audit log"
                    value={comment}
                    onChange={(e) => setComment(e.target.value)}
                  />
                </div>

                <div style={{ display: 'flex', flexDirection: 'column', gap: '0.5rem', marginTop: '0.25rem' }}>
                  <button
                    type="button"
                    className="btn-gold"
                    style={{ width: '100%', justifyContent: 'center', height: '42px', fontSize: '0.8125rem' }}
                    onClick={() => decide('Approved')}
                    disabled={loading}
                  >
                    <CheckIcon size={16} />
                    <span>Approve Booking</span>
                  </button>

                  <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '0.5rem' }}>
                    <button
                      type="button"
                      className="btn-danger-soft"
                      style={{ width: '100%', justifyContent: 'center' }}
                      onClick={() => decide('Rejected')}
                      disabled={loading}
                    >
                      Reject Booking
                    </button>
                    <button
                      type="button"
                      className="btn-outline"
                      style={{ width: '100%', justifyContent: 'center' }}
                      onClick={() => decide('RevisionRequested')}
                      disabled={loading}
                    >
                      <RotateCcwIcon size={14} />
                      <span>Request Revision</span>
                    </button>
                  </div>
                </div>
              </>
            ) : (
              <div
                style={{
                  padding: '0.75rem',
                  borderRadius: '6px',
                  backgroundColor: active.status.toLowerCase() === 'confirmed' ? '#f0fdf4' : '#fef2f2',
                  color: active.status.toLowerCase() === 'confirmed' ? '#166534' : '#991b1b',
                  border: `1px solid ${active.status.toLowerCase() === 'confirmed' ? '#bbf7d0' : '#fecaca'}`,
                  fontSize: '0.75rem',
                  textAlign: 'center',
                  fontWeight: 600,
                  marginTop: '0.5rem',
                }}
              >
                {active.status.toLowerCase() === 'confirmed'
                  ? 'âœ“ This booking is already Confirmed.'
                  : `Decision recorded: ${active.status}.`}
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  )
}
