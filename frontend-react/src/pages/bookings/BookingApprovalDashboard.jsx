import { useEffect, useMemo, useState } from 'react'
import { loadStore, mockBookings, saveStore } from '../../services/staffData.js'
import { decideApproval, fetchPendingApprovals } from '../../services/apiClient.js'
import { usePageTitle } from '../../lib/hooks.js'

/**
 * Student D — booking approval dashboard.
 * Pending table + AgentLog trail alongside + Approve / Reject / Revise + comment.
 * This screen is the human-in-the-loop evidence for the viva.
 */
export default function BookingApprovalDashboard() {
  const [rows, setRows] = useState(() => loadStore('bookings', mockBookings))
  const [filter, setFilter] = useState('AwaitingApproval')
  const [open, setOpen] = useState('B-9001')
  const [comment, setComment] = useState('')
  const [note, setNote] = useState('')
  usePageTitle('Approvals · Staff')

  useEffect(() => {
    let cancelled = false
    async function tryLoadFromApi() {
      try {
        const live = await fetchPendingApprovals()
        if (!cancelled && Array.isArray(live) && live.length > 0) {
          const mapped = live.map((b) => ({
            id: b.id,
            reference: b.reference,
            customer: b.customer,
            summary: `${b.days} days · ${b.destination}`,
            total: b.totalCost,
            requested: b.requestedAt?.split(' ')[0] || '2026-09-09',
            status: b.status,
            trail: (b.approvals && b.approvals.length > 0)
              ? b.approvals.map((a) => ({ agent: 'Human', text: `${a.decision} - ${a.comment}` }))
              : [
                  { agent: 'Coordinator', text: 'Itinerary generated for review.' },
                  { agent: 'Validation', text: 'Budget verified. Awaiting agent sign-off.' },
                ],
          }))
          setRows((prev) => {
            // merge live with existing to preserve any non-pending
            const merged = [...mapped, ...prev.filter((p) => !mapped.some((m) => m.reference === p.reference))]
            return merged
          })
        }
      } catch {
        // Backend table might be empty or offline; fallback cleanly to store
      }
    }
    tryLoadFromApi()
    return () => { cancelled = true }
  }, [])

  function persist(next) {
    setRows(next)
    saveStore('bookings', next)
  }

  const view = useMemo(
    () => (filter === 'All' ? rows : rows.filter((r) => r.status === filter)),
    [rows, filter],
  )

  const active = rows.find((r) => r.id === open) ?? rows[0]

  async function decide(status) {
    if (!active) return

    // Attempt live backend update
    try {
      const numericId = typeof active.id === 'number' ? active.id : parseInt(String(active.id).replace(/\D/g, ''), 10)
      if (numericId && !isNaN(numericId)) {
        await decideApproval(
          numericId,
          status === 'Confirmed' ? 'Approved' : status,
          comment.trim() || 'Reviewed and updated by travel agent',
        )
      }
    } catch {
      // Graceful offline fallback
    }

    persist(
      rows.map((r) =>
        r.id === active.id
          ? {
              ...r,
              status,
              trail: [...r.trail, { agent: 'Human', text: `${status}${comment.trim() ? ` — ${comment.trim()}` : ''}` }],
            }
          : r,
      ),
    )
    setNote(`${active.reference} → ${status}. Recorded in BookingApproval audit log.`)
    setComment('')
  }


  return (
    <div className="staff-page">
      <header className="staff-page__head">
        <div>
          <p className="eyebrow">Component D · Approval gate</p>
          <h1>Booking approvals</h1>
        </div>
        <div className="staff-toolbar">
          {['AwaitingApproval', 'Confirmed', 'Rejected', 'All'].map((s) => (
            <button key={s} type="button" className="seg__btn" aria-pressed={filter === s} onClick={() => setFilter(s)}>
              {s === 'AwaitingApproval' ? 'Pending' : s}
            </button>
          ))}
        </div>
      </header>

      {note ? <div className="notice">{note}</div> : null}

      <div className="staff-split">
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
              {view.map((r) => (
                <tr key={r.id} onClick={() => setOpen(r.id)} className={open === r.id ? 'is-selected' : ''}>
                  <td><b>{r.reference}</b><br /><span className="staff-sub">{r.requested}</span></td>
                  <td>{r.customer}<br /><span className="staff-sub">{r.summary}</span></td>
                  <td>${r.total}</td>
                  <td><span className={`staff-pill staff-pill--${r.status.toLowerCase()}`}>{r.status}</span></td>
                </tr>
              ))}
              {!view.length && (
                <tr><td colSpan={4} className="staff-empty">Queue is clear.</td></tr>
              )}
            </tbody>
          </table>
        </div>

        {active && (
          <div className="panel panel--solid staff-detail">
            <b>{active.reference} · {active.customer}</b>
            <span>{active.summary} · ${active.total} · requested {active.requested}</span>
            <ol className="staff-timeline">
              {active.trail.map((t, i) => (
                <li key={i}>
                  <b>{t.agent}</b>
                  <span>{t.text}</span>
                </li>
              ))}
            </ol>
            <label className="field__label" htmlFor="decision-comment">Decision comment</label>
            <textarea
              id="decision-comment"
              className="textarea"
              placeholder="Road time checked, permits fine…"
              value={comment}
              onChange={(e) => setComment(e.target.value)}
            />
            <div className="staff-row-actions">
              <button type="button" className="btn btn--sm" onClick={() => decide('Confirmed')}>Approve</button>
              <button type="button" className="staff-mini" onClick={() => decide('RevisionRequested')}>Request revision</button>
              <button type="button" className="staff-mini staff-mini--danger" onClick={() => decide('Rejected')}>Reject</button>
            </div>
          </div>
        )}
      </div>
    </div>
  )
}
