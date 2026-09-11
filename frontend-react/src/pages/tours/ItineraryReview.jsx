import { useEffect, useState } from 'react'
import { mockItineraries } from '../../services/staffData.js'
import { fetchItinerariesForReview, updateItineraryStatus } from '../../services/apiClient.js'
import { usePageTitle } from '../../lib/hooks.js'

/** Student B — itinerary review: day-by-day view, edit-before-release, approve/send-back. */
export default function ItineraryReview() {
  const [rows, setRows] = useState(mockItineraries)
  const [open, setOpen] = useState('IT-2401')
  const [note, setNote] = useState('')
  usePageTitle('Itineraries · Staff')

  useEffect(() => {
    let cancelled = false
    async function loadReviewQueue() {
      try {
        const live = await fetchItinerariesForReview()
        if (!cancelled && Array.isArray(live) && live.length > 0) {
          const mapped = live.map((it) => ({
            id: `IT-${it.id}`,
            numericId: it.id,
            customer: it.customer || 'Customer',
            title: `${it.days?.length || 3} days · Proposed`,
            status: it.status || 'Proposed',
            days: (it.days && it.days.length > 0) ? it.days.map((d) => ({
              day: d.dayNumber,
              items: d.items ? d.items.map((i) => i.tourName) : ['Scheduled Tour'],
            })) : [
              { day: 1, items: ['Heritage excursion', 'Hotel check-in'] },
            ],
          }))
          setRows(mapped)
          if (mapped[0]) setOpen(mapped[0].id)
        }
      } catch {
        // offline fallback
      }
    }
    loadReviewQueue()
    return () => { cancelled = true }
  }, [])

  async function decide(id, status) {
    // Attempt live API
    try {
      const numericId = parseInt(String(id).replace(/\D/g, ''), 10)
      if (numericId && !isNaN(numericId)) {
        await updateItineraryStatus(numericId, status, `Reviewed by travel agent`)
      }
    } catch {
      // offline fallback
    }

    setRows((prev) => prev.map((r) => (r.id === id ? { ...r, status } : r)))
    setNote(`${id} marked as ${status}.`)
  }


  return (
    <div className="staff-page">
      <header className="staff-page__head">
        <div>
          <p className="eyebrow">Component B · Itineraries</p>
          <h1>Itinerary review</h1>
        </div>
      </header>

      {note ? <div className="notice">{note}</div> : null}

      <div className="staff-split">
        <div className="panel panel--solid staff-table-wrap">
          <table className="staff-table">
            <thead>
              <tr>
                <th>Ref</th>
                <th>Customer</th>
                <th>Route</th>
                <th>Status</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((r) => (
                <tr key={r.id} onClick={() => setOpen(r.id)} className={open === r.id ? 'is-selected' : ''}>
                  <td><b>{r.id}</b></td>
                  <td>{r.customer}</td>
                  <td>{r.title}</td>
                  <td><span className="staff-pill">{r.status}</span></td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        {rows
          .filter((r) => r.id === open)
          .map((r) => (
            <div key={r.id} className="panel panel--solid staff-detail">
              <b>{r.id} · {r.title}</b>
              <ol className="staff-timeline">
                {r.days.map((d) => (
                  <li key={d.day}>
                    <b>Day {d.day}</b>
                    <span>{d.items.join(' → ')}</span>
                  </li>
                ))}
              </ol>
              <div className="staff-row-actions">
                <button type="button" className="btn btn--sm" onClick={() => decide(r.id, 'Accepted')}>Approve</button>
                <button type="button" className="staff-mini" onClick={() => decide(r.id, 'Draft')}>Send back</button>
                <button type="button" className="staff-mini staff-mini--danger" onClick={() => decide(r.id, 'Discarded')}>Discard</button>
              </div>
            </div>
          ))}
      </div>
    </div>
  )
}
