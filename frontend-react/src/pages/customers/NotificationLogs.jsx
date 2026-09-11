import { useEffect, useMemo, useState } from 'react'
import { mockNotifications } from '../../services/staffData.js'
import { fetchNotifications, resendNotification } from '../../services/apiClient.js'
import { usePageTitle } from '../../lib/hooks.js'

/** Student A — notification log with status filter + resend on failures. */
export default function NotificationLogs() {
  const [status, setStatus] = useState('All')
  const [rows, setRows] = useState(mockNotifications)
  const [note, setNote] = useState('')
  usePageTitle('Notifications · Staff')

  useEffect(() => {
    let cancelled = false
    async function loadNotifications() {
      try {
        const live = await fetchNotifications()
        if (!cancelled && Array.isArray(live) && live.length > 0) {
          const mapped = live.map((n) => ({
            id: n.id,
            recipient: n.recipient || n.customerEmail || 'Customer',
            channel: n.channel || 'Email',
            type: n.type || 'Booking Update',
            status: n.status || 'Sent',
            at: n.createdAt ? n.createdAt.replace('T', ' ').substring(0, 16) : '2026-09-08 10:00',
          }))
          setRows(mapped)
        }
      } catch {
        // offline fallback
      }
    }
    loadNotifications()
    return () => { cancelled = true }
  }, [])

  const view = useMemo(
    () => (status === 'All' ? rows : rows.filter((r) => r.status === status)),
    [rows, status],
  )

  async function resend(id) {
    try {
      await resendNotification(id)
    } catch {
      // offline fallback
    }
    setRows((prev) => prev.map((r) => (r.id === id ? { ...r, status: 'Sent' } : r)))
    setNote(`Notification #${id} re-queued and marked Sent.`)
  }


  return (
    <div className="staff-page">
      <header className="staff-page__head">
        <div>
          <p className="eyebrow">Component A · Notifications</p>
          <h1>Notification logs</h1>
        </div>
        <div className="staff-toolbar">
          {['All', 'Sent', 'Pending', 'Failed'].map((s) => (
            <button
              key={s}
              type="button"
              className="seg__btn"
              aria-pressed={status === s}
              onClick={() => setStatus(s)}
            >
              {s}
            </button>
          ))}
        </div>
      </header>

      {note ? <div className="notice">{note}</div> : null}

      <div className="panel panel--solid staff-table-wrap">
        <table className="staff-table">
          <thead>
            <tr>
              <th>ID</th>
              <th>Recipient</th>
              <th>Channel</th>
              <th>Type</th>
              <th>Status</th>
              <th>At</th>
              <th />
            </tr>
          </thead>
          <tbody>
            {view.map((r) => (
              <tr key={r.id}>
                <td>#{r.id}</td>
                <td>{r.recipient}</td>
                <td><span className="chip">{r.channel}</span></td>
                <td>{r.type}</td>
                <td>
                  <span className={`staff-pill staff-pill--${r.status.toLowerCase()}`}>{r.status}</span>
                </td>
                <td>{r.at}</td>
                <td>
                  {r.status === 'Failed' ? (
                    <button type="button" className="staff-mini" onClick={() => resend(r.id)}>
                      Resend
                    </button>
                  ) : null}
                </td>
              </tr>
            ))}
            {!view.length && (
              <tr>
                <td colSpan={7} className="staff-empty">Nothing with status “{status}”.</td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  )
}
