import { useEffect, useMemo, useState } from 'react'
import { decideApproval, fetchAgentLogs, fetchBookings } from '../../services/apiClient.js'
import { usePageTitle } from '../../lib/hooks.js'

const STATUS_NAMES = ['AwaitingApproval', 'Confirmed', 'Rejected', 'Cancelled']
const DECISION_NAMES = ['Pending', 'Approved', 'Rejected', 'RevisionRequested']
const PAGE_SIZE = 6

/**
 * Student D — booking approval dashboard with real database data, AI agent reasoning trail & human approval audit trail.
 */
export default function BookingApprovalDashboard() {
  const [rows, setRows] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [filter, setFilter] = useState('All')
  const [page, setPage] = useState(1)
  const [open, setOpen] = useState(null)
  const [comment, setComment] = useState('')
  const [note, setNote] = useState('')
  const [agentLogs, setAgentLogs] = useState([])
  const [logsLoading, setLogsLoading] = useState(false)
  usePageTitle('Approvals · Staff')

  async function loadBookings(cancelled = false) {
    setLoading(true)
    setError(null)
    try {
      const res = await fetchBookings()
      const live = Array.isArray(res) ? res : (res?.data || [])
      if (!cancelled) {
        const mapped = live.map((b) => {
          const statusStr = typeof b.status === 'number' ? (STATUS_NAMES[b.status] || 'AwaitingApproval') : (b.status || 'AwaitingApproval')
          return {
            id: b.id,
            reference: b.bookingReference || `BK-${b.id}`,
            tripRequestId: b.tripRequestId,
            customer: b.customerName || (b.customerId ? `Customer ${b.customerId.substring(0, 8)}…` : 'Customer'),
            total: b.totalCost || 0,
            currency: b.currency || 'USD',
            requested: b.createdAt ? b.createdAt.split('T')[0] : 'N/A',
            status: statusStr,
            trail: (b.bookingApprovals && b.bookingApprovals.length > 0)
              ? b.bookingApprovals.map((a) => {
                  const dec = typeof a.decision === 'number' ? (DECISION_NAMES[a.decision] || 'Reviewed') : (a.decision || 'Reviewed')
                  return {
                    agent: a.travelAgentName || 'Agent',
                    text: `${dec}: ${a.comment || 'No comment'} (${a.decidedAt ? a.decidedAt.replace('T', ' ').substring(0, 16) : ''})`,
                  }
                })
              : [{ agent: 'System', text: 'Booking submitted and awaiting travel agent approval.' }],
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
    loadBookings(cancelled)
    return () => { cancelled = true }
  }, [])

  const view = useMemo(
    () => (filter === 'All' ? rows : rows.filter((r) => r.status.toLowerCase() === filter.toLowerCase())),
    [rows, filter],
  )

  const pages = Math.max(1, Math.ceil(view.length / PAGE_SIZE))
  const pageRows = view.slice((page - 1) * PAGE_SIZE, page * PAGE_SIZE)
  const active = rows.find((r) => r.id === open) ?? rows[0]

  // Load autonomous AI agent execution logs for the selected booking's trip request
  useEffect(() => {
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
  }, [active?.tripRequestId])

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

  return (
    <div className="staff-page">
      <header className="staff-page__head">
        <div>
          <p className="eyebrow">Component D · Approval gate</p>
          <h1>Booking approvals</h1>
        </div>
        <div className="staff-toolbar">
          {['All', 'AwaitingApproval', 'Confirmed', 'Rejected'].map((s) => (
            <button key={s} type="button" className="seg__btn" aria-pressed={filter === s} onClick={() => onFilterChange(s)}>
              {s === 'AwaitingApproval' ? 'Pending' : s}
            </button>
          ))}
          <button type="button" className="btn btn--sm" onClick={() => loadBookings(false)} disabled={loading}>
            {loading ? 'Refreshing…' : 'Refresh'}
          </button>
        </div>
      </header>

      {error && (
        <div className="notice notice--error" style={{ color: '#ff6b6b' }}>
          {error}
        </div>
      )}

      {note && <div className="notice">{note}</div>}

      <div className="staff-split">
        <div>
          <div className="panel panel--solid staff-table-wrap">
            <table className="staff-table">
              <thead>
                <tr>
                  <th>Reference</th>
                  <th>Customer</th>
                  <th>Total</th>
                  <th>Status</th>
                </tr>
              </thead>
              <tbody>
                {loading ? (
                  <tr><td colSpan={4} className="staff-empty">Loading bookings from database…</td></tr>
                ) : pageRows.length > 0 ? (
                  pageRows.map((r) => (
                    <tr key={r.id} onClick={() => setOpen(r.id)} className={open === r.id ? 'is-selected' : ''} style={{ cursor: 'pointer' }}>
                      <td><b>{r.reference}</b><br /><span className="staff-sub">{r.requested}</span></td>
                      <td>{r.customer}</td>
                      <td>${r.total} {r.currency}</td>
                      <td><span className={`staff-pill staff-pill--${r.status.toLowerCase()}`}>{r.status}</span></td>
                    </tr>
                  ))
                ) : (
                  <tr><td colSpan={4} className="staff-empty">No bookings match the selected filter.</td></tr>
                )}
              </tbody>
            </table>
          </div>

          <div className="staff-pager">
            <button type="button" disabled={page <= 1} onClick={() => setPage((p) => p - 1)}>← Prev</button>
            <span>Page {page} of {pages} · {view.length} bookings</span>
            <button type="button" disabled={page >= pages} onClick={() => setPage((p) => p + 1)}>Next →</button>
          </div>
        </div>

        {active && (
          <div className="panel panel--solid staff-detail">
            <b>{active.reference} · {active.customer}</b>
            <p className="staff-sub">Total: ${active.total} {active.currency} · Status: <b>{active.status}</b></p>

            <h4 style={{ margin: '1rem 0 0.5rem' }}>AI Agent Reasoning Trail</h4>
            {logsLoading ? (
              <p className="staff-sub">Loading agent execution logs…</p>
            ) : agentLogs.length > 0 ? (
              <ol className="staff-timeline" style={{ marginBottom: '1rem' }}>
                {agentLogs.map((log) => (
                  <li key={log.id}>
                    <span>{log.agentName} · {log.stepName} ({log.status})</span>
                    <p>{log.output || log.input || 'Step executed successfully.'}</p>
                    <small className="staff-sub" style={{ fontSize: '0.75rem', opacity: 0.7 }}>
                      {log.timestamp ? log.timestamp.replace('T', ' ').substring(0, 19) : ''}
                    </small>
                  </li>
                ))}
              </ol>
            ) : (
              <p className="staff-sub" style={{ marginBottom: '1rem' }}>
                No automated agent steps logged for Trip Request #{active.tripRequestId || 'N/A'}.
              </p>
            )}

            <h4 style={{ margin: '1rem 0 0.5rem' }}>Human Decisions & Audit Trail</h4>
            <ol className="staff-timeline">
              {active.trail.map((t, idx) => (
                <li key={idx}>
                  <span>{t.agent}</span>
                  <p>{t.text}</p>
                </li>
              ))}
            </ol>

            <div className="staff-actions" style={{ marginTop: '1.5rem' }}>
              <input
                className="input"
                placeholder="Agent notes / reason for decision…"
                value={comment}
                onChange={(e) => setComment(e.target.value)}
                style={{ marginBottom: '0.75rem' }}
              />
              <div style={{ display: 'flex', gap: '0.5rem' }}>
                <button
                  type="button"
                  className="btn btn--sm"
                  onClick={() => decide('Approved')}
                  disabled={loading}
                >
                  Approve (Confirm)
                </button>
                <button
                  type="button"
                  className="staff-mini"
                  onClick={() => decide('RevisionRequested')}
                  disabled={loading}
                >
                  Request Revision
                </button>
                <button
                  type="button"
                  className="staff-mini staff-mini--danger"
                  onClick={() => decide('Rejected')}
                  disabled={loading}
                >
                  Reject
                </button>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  )
}
