import { useEffect, useState } from 'react'
import { fetchItinerariesForReview, updateItineraryStatus } from '../../services/apiClient.js'
import { usePageTitle } from '../../lib/hooks.js'

const STATUS_NAMES = ['Draft', 'Proposed', 'Accepted', 'Discarded']

/** Student B — itinerary review with real database data, day-by-day view, approve / send back. */
export default function ItineraryReview() {
  const [rows, setRows] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [open, setOpen] = useState(null)
  const [note, setNote] = useState('')
  usePageTitle('Itineraries · Staff')

  async function loadReviewQueue(cancelled = false) {
    setLoading(true)
    setError(null)
    try {
      const res = await fetchItinerariesForReview()
      const live = Array.isArray(res) ? res : (res?.data || [])
      if (!cancelled) {
        const mapped = live.map((it) => {
          const statusStr = typeof it.status === 'number' ? (STATUS_NAMES[it.status] || 'Proposed') : (it.status || 'Proposed')
          return {
            id: `IT-${it.id}`,
            numericId: it.id,
            customer: it.customerId ? `Customer ${it.customerId.substring(0, 8)}…` : 'Customer',
            title: `${it.items?.length || 0} tour(s) · $${it.totalEstimatedCost || 0} ${it.currency || 'USD'}`,
            status: statusStr,
            cost: it.totalEstimatedCost,
            currency: it.currency || 'USD',
            startDate: it.startDate ? it.startDate.split('T')[0] : 'N/A',
            endDate: it.endDate ? it.endDate.split('T')[0] : 'N/A',
            items: it.items || [],
          }
        })
        setRows(mapped)
        if (mapped.length > 0) {
          setOpen((prev) => (mapped.some((m) => m.id === prev) ? prev : mapped[0].id))
        }
      }
    } catch (err) {
      if (!cancelled) {
        setError(err.response?.data?.message || err.message || 'Failed to load itineraries from database.')
      }
    } finally {
      if (!cancelled) setLoading(false)
    }
  }

  useEffect(() => {
    let cancelled = false
    loadReviewQueue(cancelled)
    return () => { cancelled = true }
  }, [])

  async function decide(id, status) {
    try {
      const numericId = parseInt(String(id).replace(/\D/g, ''), 10)
      if (numericId && !isNaN(numericId)) {
        await updateItineraryStatus(numericId, status, 'Reviewed by travel agent')
        setNote(`${id} updated to ${status} in database.`)
        await loadReviewQueue()
      }
    } catch (err) {
      setNote(`Failed to update status: ${err.response?.data?.message || err.message}`)
    }
  }

  const selected = rows.find((r) => r.id === open) ?? rows[0]

  return (
    <div className="staff-page">
      <header className="staff-page__head">
        <div>
          <p className="eyebrow">Component B · Itineraries</p>
          <h1>Itinerary review</h1>
        </div>
        <div className="staff-toolbar">
          <button type="button" className="btn btn--sm" onClick={() => loadReviewQueue(false)} disabled={loading}>
            {loading ? 'Refreshing…' : 'Refresh'}
          </button>
        </div>
      </header>

      {error && (
        <div className="notice notice--error" style={{ color: '#ff6b6b' }}>
          {error}
        </div>
      )}

      {note ? <div className="notice">{note}</div> : null}

      <div className="staff-split">
        <div className="panel panel--solid staff-table-wrap">
          <table className="staff-table">
            <thead>
              <tr>
                <th>Ref</th>
                <th>Customer</th>
                <th>Summary</th>
                <th>Status</th>
              </tr>
            </thead>
            <tbody>
              {loading ? (
                <tr><td colSpan={4} className="staff-empty">Loading itineraries from database…</td></tr>
              ) : rows.length > 0 ? (
                rows.map((r) => (
                  <tr key={r.id} onClick={() => setOpen(r.id)} className={open === r.id ? 'is-selected' : ''} style={{ cursor: 'pointer' }}>
                    <td><b>{r.id}</b></td>
                    <td>{r.customer}</td>
                    <td>{r.title}</td>
                    <td><span className={`staff-pill staff-pill--${r.status.toLowerCase()}`}>{r.status}</span></td>
                  </tr>
                ))
              ) : (
                <tr><td colSpan={4} className="staff-empty">No itineraries in review queue.</td></tr>
              )}
            </tbody>
          </table>
        </div>

        {selected && (
          <div className="panel panel--solid staff-detail">
            <b>{selected.id} · {selected.status}</b>
            <p className="staff-sub">
              {selected.startDate} → {selected.endDate} · Total: ${selected.cost} {selected.currency}
            </p>

            <h4 style={{ margin: '1rem 0 0.5rem' }}>Scheduled Excursions</h4>
            {selected.items && selected.items.length > 0 ? (
              <ol className="staff-timeline">
                {selected.items.map((it, idx) => (
                  <li key={it.id || idx}>
                    <span>Day {it.dayNumber} · {it.startTime?.substring(0, 5) || '08:00'} - {it.endTime?.substring(0, 5) || '11:00'}</span>
                    <p><b>{it.tourName || `Tour #${it.tourId}`}</b> · ${it.priceAtSelection}</p>
                  </li>
                ))}
              </ol>
            ) : (
              <p className="staff-sub">No excursions scheduled yet for this itinerary.</p>
            )}

            <div className="staff-actions" style={{ marginTop: '1.5rem', display: 'flex', gap: '0.5rem' }}>
              <button
                type="button"
                className="btn btn--sm"
                onClick={() => decide(selected.id, 'Accepted')}
                disabled={selected.status === 'Accepted'}
              >
                Approve (Accept)
              </button>
              <button
                type="button"
                className="staff-mini"
                onClick={() => decide(selected.id, 'Draft')}
              >
                Return to Draft
              </button>
              <button
                type="button"
                className="staff-mini staff-mini--danger"
                onClick={() => decide(selected.id, 'Discarded')}
              >
                Discard
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  )
}
